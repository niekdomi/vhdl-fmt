pub mod concurrent;
pub mod declaration;
pub mod design;
pub mod expression;
pub mod interface;
pub mod name;
pub mod sequential;
pub mod subprogram;

use std::cell::RefCell;
use std::collections::BTreeSet;

use crate::config::FormatConfig;
use pretty::{Arena, DocAllocator, DocBuilder};
use vhdl_lang::HasTokenSpan;
use vhdl_lang::ast::{Designator, Mode, ObjectClass, Operator, SubprogramDesignator};
use vhdl_lang::{Token, TokenAccess, TokenId};

/// Convenience type alias — we annotate with `()` (no colour/semantic annotations).
pub type Doc<'a> = DocBuilder<'a, Arena<'a>>;

pub struct Formatter<'a> {
    pub arena: &'a Arena<'a>,
    pub config: &'a FormatConfig,
    /// Token list for the current design unit (from `DesignFile::design_units`).
    /// Empty slice when no token context is available.
    pub tokens: &'a [Token],
    /// Tracks which tokens have already had their trailing comments emitted,
    /// preventing duplication when parent and child nodes overlap in token spans.
    /// Stored as pointer offsets into the tokens slice.
    pub emitted_trailing: RefCell<BTreeSet<usize>>,
    /// Tracks which tokens have already had their leading comments emitted.
    pub emitted_leading: RefCell<BTreeSet<usize>>,
}

impl<'a> Formatter<'a> {
    /// Create a formatter with a token slice for a specific design unit.
    pub fn with_tokens(
        arena: &'a Arena<'a>,
        config: &'a FormatConfig,
        tokens: &'a [Token],
    ) -> Self {
        Self {
            arena,
            config,
            tokens,
            emitted_trailing: RefCell::new(BTreeSet::new()),
            emitted_leading: RefCell::new(BTreeSet::new()),
        }
    }

    /// Convert a token reference to its index in the tokens slice.
    fn token_index(&self, token: &Token) -> usize {
        let base = self.tokens.as_ptr() as usize;
        let ptr = std::ptr::from_ref::<Token>(token) as usize;
        (ptr - base) / std::mem::size_of::<Token>()
    }

    // -------------------------------------------------------------------------
    // Low-level token helpers
    // -------------------------------------------------------------------------

    /// Emit a keyword string, applying the configured keyword casing.
    pub fn kw(&self, s: &str) -> Doc<'a> {
        self.arena.text(self.config.casing.keywords.apply(s))
    }

    /// Emit an identifier string, applying the configured identifier casing.
    pub fn ident(&self, s: &str) -> Doc<'a> {
        self.arena.text(self.config.casing.identifiers.apply(s))
    }

    /// Emit a fixed punctuation string exactly as given (no casing transform).
    pub fn punct(&self, s: &'static str) -> Doc<'a> {
        self.arena.text(s)
    }

    /// Emit a keyword preceded by any leading comments and followed by any
    /// trailing comment attached to the given token. Use this instead of
    /// `self.kw(s)` for structural keywords (`begin`, `end`, `is`, etc.)
    /// so that adjacent comments are preserved automatically.
    pub fn kw_tok(&self, s: &str, token: TokenId) -> Doc<'a> {
        self.leading_comments(token)
            .append(self.kw(s))
            .append(self.trailing_comment(token))
    }

    // -------------------------------------------------------------------------
    // Structural helpers
    // -------------------------------------------------------------------------

    /// A soft line break: a space when the enclosing group fits on one line,
    /// a newline + indent when it does not.
    pub fn line(&self) -> Doc<'a> {
        self.arena.line()
    }

    /// A soft line break that produces *nothing* (not even a space) when the
    /// group fits inline.
    pub fn line_(&self) -> Doc<'a> {
        self.arena.line_()
    }

    /// An unconditional newline.
    pub fn hardline(&self) -> Doc<'a> {
        self.arena.hardline()
    }

    /// The empty document.
    pub fn nil(&self) -> Doc<'a> {
        self.arena.nil()
    }

    /// A single space.
    pub fn space(&self) -> Doc<'a> {
        self.arena.text(" ")
    }

    /// Wrap `doc` in `nest(indent_size)`.
    pub fn nest(&self, doc: Doc<'a>) -> Doc<'a> {
        doc.nest(self.config.indentation.size as isize)
    }

    /// Intersperse `items` with `sep`.
    pub fn intersperse<I>(&self, items: I, sep: Doc<'a>) -> Doc<'a>
    where
        I: IntoIterator<Item = Doc<'a>>,
    {
        self.arena.intersperse(items, sep)
    }

    /// Intersperse items with `hardline()`.
    pub fn join_hardline<I>(&self, items: I) -> Doc<'a>
    where
        I: IntoIterator<Item = Doc<'a>>,
    {
        self.intersperse(items, self.hardline())
    }

    // -------------------------------------------------------------------------
    // Designator helpers
    // -------------------------------------------------------------------------

    /// Format a `Designator` (identifier or operator symbol or character).
    pub fn designator(&self, d: &Designator) -> Doc<'a> {
        match d {
            Designator::Identifier(sym) => self.ident(&sym.name_utf8()),
            Designator::OperatorSymbol(op) => self.arena.text(format!("\"{}\"", operator_str(*op))),
            Designator::Character(c) => self.arena.text(format!("'{}'", *c as char)),
            Designator::Anonymous(_) => self.nil(),
        }
    }

    /// Format a `SubprogramDesignator` (identifier or operator symbol).
    pub fn subprogram_designator(&self, d: &SubprogramDesignator) -> Doc<'a> {
        match d {
            SubprogramDesignator::Identifier(sym) => self.ident(&sym.name_utf8()),
            SubprogramDesignator::OperatorSymbol(op) => {
                self.arena.text(format!("\"{}\"", operator_str(*op)))
            }
        }
    }

    // -------------------------------------------------------------------------
    // VHDL keyword helpers
    // -------------------------------------------------------------------------

    /// Format an `ObjectClass` as its keyword(s).
    pub fn object_class_kw(&self, class: ObjectClass) -> Doc<'a> {
        match class {
            ObjectClass::Signal => self.kw("signal"),
            ObjectClass::Variable => self.kw("variable"),
            ObjectClass::Constant => self.kw("constant"),
            ObjectClass::SharedVariable => {
                self.kw("shared").append(self.space()).append(self.kw("variable"))
            }
        }
    }

    /// Format a `Mode` as its keyword string.
    pub const fn mode_str(mode: Mode) -> &'static str {
        match mode {
            Mode::In => "in",
            Mode::Out => "out",
            Mode::InOut => "inout",
            Mode::Buffer => "buffer",
            Mode::Linkage => "linkage",
        }
    }

    // -------------------------------------------------------------------------
    // Comment + blank-line trivia helpers
    // -------------------------------------------------------------------------

    /// Given a `TokenId`, return a Doc that emits any leading comments
    /// attached to that token, preserving their exact text and the relative
    /// blank lines between consecutive comments.  Does NOT emit the token
    /// itself.  Returns `nil()` when there are no leading comments or when
    /// the tokens slice is empty.
    pub fn leading_comments(&self, id: TokenId) -> Doc<'a> {
        if self.tokens.is_empty() {
            return self.nil();
        }
        let Some(token) = self.tokens.get_token(id) else {
            return self.nil();
        };
        let idx = self.token_index(token);
        if !self.emitted_leading.borrow_mut().insert(idx) {
            return self.nil(); // already emitted
        }
        let Some(comments) = token.comments.as_ref().filter(|c| !c.leading.is_empty()) else {
            return self.nil();
        };

        let mut doc = self.nil();
        for (i, comment) in comments.leading.iter().enumerate() {
            let text = format_comment_text_parts(&comment.value, comment.multi_line);
            doc = doc.append(self.arena.text(text));

            // How many newlines between this comment and the next one (or the
            // token itself when this is the last leading comment).
            let next_line = if let Some(next_comment) = comments.leading.get(i + 1) {
                next_comment.range.start.line
            } else {
                token.pos.start().line
            };
            let gap = next_line.saturating_sub(comment.range.end.line);
            let breaks = gap.max(1);
            for _ in 0..breaks {
                doc = doc.append(self.hardline());
            }
        }
        doc
    }

    /// Returns `true` when there is a blank line (≥ 2 source-line gap) between
    /// the end of `prev_id` and the start of `next_id` (accounting for the
    /// first leading comment of `next_id` if any).
    pub fn has_blank_before(&self, prev_id: TokenId, next_id: TokenId) -> bool {
        if self.tokens.is_empty() {
            return false;
        }
        let Some(prev) = self.tokens.get_token(prev_id) else {
            return false;
        };
        let Some(next) = self.tokens.get_token(next_id) else {
            return false;
        };

        // The "visual start" of the next item includes its first leading comment.
        let next_start_line = match &next.comments {
            Some(c) if !c.leading.is_empty() => c.leading[0].range.start.line,
            _ => next.pos.start().line,
        };
        let prev_end_line = prev.pos.end().line;

        // gap ≥ 2 → at least one empty line between them
        next_start_line.saturating_sub(prev_end_line) >= 2
    }

    /// Build a trivia Doc to prepend before a node.
    ///
    /// * `prev_end` — `TokenId` of the last token of the *previous* node.
    /// * `this_start` — `TokenId` of the first token of *this* node.
    ///
    /// Emits an extra `hardline` when a blank line existed in the source,
    /// followed by any leading comments.  The caller still emits the single
    /// `hardline` that separates the previous item from this one.
    pub fn node_trivia(&self, prev_end: TokenId, this_start: TokenId) -> Doc<'a> {
        let blank = if self.has_blank_before(prev_end, this_start) {
            self.hardline()
        } else {
            self.nil()
        };
        blank.append(self.leading_comments(this_start))
    }

    /// Returns `true` when the token has leading comments.
    pub fn has_leading_comments_on(&self, id: TokenId) -> bool {
        if self.tokens.is_empty() {
            return false;
        }
        match self.tokens.get_token(id) {
            Some(t) => matches!(&t.comments, Some(c) if !c.leading.is_empty()),
            None => false,
        }
    }

    /// Emit the trailing comment of a token (if any).
    /// Returns a space + comment text, or nil if there is no trailing comment.
    pub fn trailing_comment(&self, id: TokenId) -> Doc<'a> {
        if self.tokens.is_empty() {
            return self.nil();
        }
        let Some(token) = self.tokens.get_token(id) else {
            return self.nil();
        };
        let idx = self.token_index(token);
        if !self.emitted_trailing.borrow_mut().insert(idx) {
            return self.nil(); // already emitted
        }
        match &token.comments {
            Some(c) => match &c.trailing {
                Some(comment) => {
                    let text = format_comment_text_parts(&comment.value, comment.multi_line);
                    self.space().append(self.arena.text(text))
                }
                None => self.nil(),
            },
            None => self.nil(),
        }
    }

    /// Scan all tokens in the range `[start_id, end_id]` (inclusive) and emit
    /// any trailing comments found.  This is useful when a construct spans
    /// multiple tokens (e.g. commas between list items) and we want to capture
    /// trailing comments on intermediate tokens that we don't format individually.
    pub fn trailing_comments_in_span(&self, start_id: TokenId, end_id: TokenId) -> Doc<'a> {
        if self.tokens.is_empty() {
            return self.nil();
        }
        let slice = self.tokens.get_token_slice(start_id, end_id);
        let mut doc = self.nil();
        let mut emitted = self.emitted_trailing.borrow_mut();
        for token in slice {
            let idx = self.token_index(token);
            if !emitted.insert(idx) {
                continue; // already emitted
            }
            if let Some(comments) = &token.comments
                && let Some(comment) = &comments.trailing
            {
                let text = format_comment_text_parts(&comment.value, comment.multi_line);
                doc = doc.append(self.space()).append(self.arena.text(text));
            }
        }
        doc
    }

    /// Wrap a formatted node's doc with trailing comments from its full token
    /// span. Scans all tokens in the span for trailing comments and appends them.
    /// Already-emitted comments (from sub-node formatting) are skipped.
    pub fn with_trailing_comments<T: HasTokenSpan>(&self, node: &T, doc: Doc<'a>) -> Doc<'a> {
        if self.tokens.is_empty() {
            return doc;
        }
        let start = node.get_start_token();
        let end = node.get_end_token();
        doc.append(self.trailing_comments_in_span(start, end))
    }

    /// Wrap a node's formatted doc with trailing comments from its full token
    /// span. Already-emitted comments are skipped automatically.
    /// Leading comments are handled by `kw_tok()` and `format_item_list()`.
    pub fn with_comments<T: HasTokenSpan>(&self, node: &T, doc: Doc<'a>) -> Doc<'a> {
        self.with_trailing_comments(node, doc)
    }

    /// Measure the flat (single-line) width of a document.
    pub fn doc_width(&self, doc: &Doc<'a>) -> usize {
        let mut buf = Vec::new();
        doc.clone().render(10000, &mut buf).unwrap();
        buf.len()
    }

    // -------------------------------------------------------------------------
    // Generic trivia-aware list formatting
    // -------------------------------------------------------------------------

    /// Scan forward from index `i` to find how many consecutive items are
    /// groupable (no blank lines or leading comments between them).
    ///
    /// * `is_groupable` — returns `true` when an item qualifies for the group.
    /// * `get_tokens` — extract `(start_token, end_token)` from an item.
    ///
    /// Returns 0 when `items[i]` is not groupable; otherwise returns the
    /// group length (≥ 1).
    #[allow(clippy::impl_trait_in_params, reason = "same style as format_item_list")]
    pub fn try_group<T>(
        &self,
        items: &[T],
        i: usize,
        is_groupable: impl Fn(&T) -> bool,
        get_tokens: impl Fn(&T) -> (TokenId, TokenId),
    ) -> usize {
        if !is_groupable(&items[i]) {
            return 0;
        }
        let mut j = i + 1;
        while j < items.len() {
            if is_groupable(&items[j]) {
                let (_, prev_end) = get_tokens(&items[j - 1]);
                let (next_start, _) = get_tokens(&items[j]);
                if !self.has_blank_before(prev_end, next_start)
                    && !self.has_leading_comments_on(next_start)
                {
                    j += 1;
                    continue;
                }
            }
            break;
        }
        j - i
    }

    /// Format a list of items with trivia (comments, blank lines) and optional
    /// alignment grouping.  This extracts the boilerplate shared by
    /// `format_concurrent_statements`, `format_sequential_statements`, and
    /// `format_declarations`.
    ///
    /// * `get_tokens` — extract `(start_token, end_token)` from an item.
    /// * `try_group` — given the slice starting at index `i`, return how many
    ///   consecutive items form an alignment group (0 = not groupable).
    /// * `format_group` — format a group of `count` items starting at `i`.
    /// * `format_single` — format a single item at index `i`.
    pub fn format_item_list<T>(
        &self,
        items: &[T],
        get_tokens: impl Fn(&T) -> (TokenId, TokenId),
        try_group: impl Fn(&Self, &[T], usize) -> usize,
        format_group: impl Fn(&Self, &[T], usize, usize) -> Vec<Doc<'a>>,
        format_single: impl Fn(&Self, &T) -> Doc<'a>,
    ) -> Doc<'a> {
        if items.is_empty() {
            return self.nil();
        }
        let mut body = self.nil();
        let mut i = 0;
        while i < items.len() {
            let group_start = i;
            let group_len = try_group(self, items, i);
            let formatted: Vec<Doc<'a>> = if group_len > 1 {
                format_group(self, items, i, group_len)
            } else {
                vec![format_single(self, &items[i])]
            };
            let count = formatted.len();
            for (k, item_doc) in formatted.into_iter().enumerate() {
                let idx = group_start + k;
                let (start, end) = get_tokens(&items[idx]);
                let tc = self.trailing_comment(end);
                if idx == 0 {
                    let trivia = self.leading_comments(start);
                    body = body.append(trivia).append(item_doc).append(tc);
                } else {
                    let (_, prev_end) = get_tokens(&items[idx - 1]);
                    let trivia = self.node_trivia(prev_end, start);
                    body = body.append(self.hardline()).append(trivia).append(item_doc).append(tc);
                }
            }
            i = group_start + count;
        }
        body
    }
}

// -----------------------------------------------------------------------------
// Operator → string
// -----------------------------------------------------------------------------

pub const fn operator_str(op: Operator) -> &'static str {
    match op {
        Operator::And => "and",
        Operator::Or => "or",
        Operator::Nand => "nand",
        Operator::Nor => "nor",
        Operator::Xor => "xor",
        Operator::Xnor => "xnor",
        Operator::Abs => "abs",
        Operator::Not => "not",
        Operator::Minus => "-",
        Operator::Plus => "+",
        Operator::QueQue => "??",
        Operator::EQ => "=",
        Operator::NE => "/=",
        Operator::LT => "<",
        Operator::LTE => "<=",
        Operator::GT => ">",
        Operator::GTE => ">=",
        Operator::QueEQ => "?=",
        Operator::QueNE => "?/=",
        Operator::QueLT => "?<",
        Operator::QueLTE => "?<=",
        Operator::QueGT => "?>",
        Operator::QueGTE => "?>=",
        Operator::SLL => "sll",
        Operator::SRL => "srl",
        Operator::SLA => "sla",
        Operator::SRA => "sra",
        Operator::ROL => "rol",
        Operator::ROR => "ror",
        Operator::Concat => "&",
        Operator::Times => "*",
        Operator::Div => "/",
        Operator::Mod => "mod",
        Operator::Rem => "rem",
        Operator::Pow => "**",
    }
}

// -----------------------------------------------------------------------------
// Comment text formatting
// -----------------------------------------------------------------------------

/// Format a comment's text.  We accept the two fields directly so we never
/// have to name the private `vhdl_lang::syntax::Comment` type.
fn format_comment_text_parts(value: &str, multi_line: bool) -> String {
    if multi_line { format!("/*{value}*/") } else { format!("--{value}") }
}
