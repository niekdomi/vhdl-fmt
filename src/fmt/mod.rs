pub mod concurrent;
pub mod declaration;
pub mod design;
pub mod expression;
pub mod interface;
pub mod name;
pub mod sequential;
pub mod subprogram;

use crate::config::FormatConfig;
use pretty::{Arena, DocAllocator, DocBuilder};
use vhdl_lang::ast::{Designator, Operator, SubprogramDesignator};
use vhdl_lang::{Token, TokenAccess, TokenId};

/// Convenience type alias — we annotate with `()` (no colour/semantic annotations).
pub type Doc<'a> = DocBuilder<'a, Arena<'a>>;

pub struct Formatter<'a> {
    pub arena: &'a Arena<'a>,
    pub config: &'a FormatConfig,
    /// Token list for the current design unit (from DesignFile::design_units).
    /// Empty slice when no token context is available.
    pub tokens: &'a [Token],
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
        }
    }

    // -----------------------------------------------------------------------
    // Low-level token helpers
    // -----------------------------------------------------------------------

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

    // -----------------------------------------------------------------------
    // Structural helpers
    // -----------------------------------------------------------------------

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

    // -----------------------------------------------------------------------
    // Designator helpers
    // -----------------------------------------------------------------------

    /// Format a `Designator` (identifier or operator symbol or character).
    pub fn designator(&self, d: &Designator) -> Doc<'a> {
        match d {
            Designator::Identifier(sym) => self.ident(&sym.name_utf8()),
            Designator::OperatorSymbol(op) => self.arena.text(format!("\"{}\"", operator_str(op))),
            Designator::Character(c) => self.arena.text(format!("'{}'", *c as char)),
            Designator::Anonymous(_) => self.nil(),
        }
    }

    /// Format a `SubprogramDesignator` (identifier or operator symbol).
    pub fn subprogram_designator(&self, d: &SubprogramDesignator) -> Doc<'a> {
        match d {
            SubprogramDesignator::Identifier(sym) => self.ident(&sym.name_utf8()),
            SubprogramDesignator::OperatorSymbol(op) => {
                self.arena.text(format!("\"{}\"", operator_str(op)))
            }
        }
    }

    // -----------------------------------------------------------------------
    // Comment + blank-line trivia helpers
    // -----------------------------------------------------------------------

    /// Given a `TokenId`, return a Doc that emits any leading comments
    /// attached to that token, preserving their exact text and the relative
    /// blank lines between consecutive comments.  Does NOT emit the token
    /// itself.  Returns `nil()` when there are no leading comments or when
    /// the tokens slice is empty.
    pub fn leading_comments(&self, id: TokenId) -> Doc<'a> {
        if self.tokens.is_empty() {
            return self.nil();
        }
        let token = match self.tokens.get_token(id) {
            Some(t) => t,
            None => return self.nil(),
        };
        let comments = match &token.comments {
            Some(c) if !c.leading.is_empty() => c,
            _ => return self.nil(),
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
        let prev = match self.tokens.get_token(prev_id) {
            Some(t) => t,
            None => return false,
        };
        let next = match self.tokens.get_token(next_id) {
            Some(t) => t,
            None => return false,
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
        let token = match self.tokens.get_token(id) {
            Some(t) => t,
            None => return self.nil(),
        };
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
        for token in slice {
            if let Some(comments) = &token.comments
                && let Some(comment) = &comments.trailing
            {
                let text = format_comment_text_parts(&comment.value, comment.multi_line);
                doc = doc.append(self.space()).append(self.arena.text(text));
            }
        }
        doc
    }

    /// Measure the flat (single-line) width of a document.
    pub fn doc_width(&self, doc: &Doc<'a>) -> usize {
        let mut buf = Vec::new();
        doc.clone().render(10000, &mut buf).unwrap();
        buf.len()
    }

    // -----------------------------------------------------------------------
    // Generic trivia-aware list formatting
    // -----------------------------------------------------------------------

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
                    body = body
                        .append(self.hardline())
                        .append(trivia)
                        .append(item_doc)
                        .append(tc);
                }
            }
            i = group_start + count;
        }
        body
    }
}

// ---------------------------------------------------------------------------
// Operator → string
// ---------------------------------------------------------------------------

pub fn operator_str(op: &Operator) -> &'static str {
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

// ---------------------------------------------------------------------------
// Comment text formatting
// ---------------------------------------------------------------------------

/// Format a comment's text.  We accept the two fields directly so we never
/// have to name the private `vhdl_lang::syntax::Comment` type.
fn format_comment_text_parts(value: &str, multi_line: bool) -> String {
    if multi_line {
        format!("/*{}*/", value)
    } else {
        format!("--{}", value)
    }
}
