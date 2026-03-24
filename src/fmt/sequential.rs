use pretty::DocAllocator;
use vhdl_lang::ast::token_range::WithTokenSpan;
use vhdl_lang::ast::{
    AssignmentRightHand, CaseStatement, Choice, DelayMechanism, ExitStatement, Expression,
    IfStatement, IterationScheme, LabeledSequentialStatement, LoopStatement, NextStatement,
    ReportStatement, SequentialStatement, SignalAssignment, SignalForceAssignment,
    SignalReleaseAssignment, Target, VariableAssignment, WaitStatement, Waveform, WaveformElement,
};
use vhdl_lang::{HasTokenSpan, TokenAccess};

use crate::fmt::{Doc, Formatter};

#[derive(Clone, Copy, PartialEq, Eq)]
enum SeqAssignKind {
    None,
    Signal,
    Variable,
}

impl<'a> Formatter<'a> {
    // -----------------------------------------------------------------------
    // Statement list
    // -----------------------------------------------------------------------

    pub fn format_sequential_statements(
        &self,
        statements: &[LabeledSequentialStatement],
    ) -> Doc<'a> {
        let body = self.format_item_list(
            statements,
            |s| {
                let start = s
                    .label
                    .tree
                    .as_ref()
                    .map_or_else(|| s.statement.get_start_token(), |l| l.token);
                (start, s.statement.get_end_token())
            },
            Self::try_group_sequential,
            Self::format_sequential_group,
            Self::format_labeled_sequential_statement,
        );
        self.nest(self.hardline().append(body))
    }

    fn try_group_sequential(&self, stmts: &[LabeledSequentialStatement], i: usize) -> usize {
        let assign_kind = self.seq_assignment_kind(&stmts[i]);
        if assign_kind == SeqAssignKind::None {
            return 0;
        }
        let mut j = i + 1;
        while j < stmts.len() {
            if self.seq_assignment_kind(&stmts[j]) == assign_kind {
                let prev_end = stmts[j - 1].statement.get_end_token();
                let next_start = stmts[j].statement.get_start_token();
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

    fn format_sequential_group(
        &self,
        stmts: &[LabeledSequentialStatement],
        start: usize,
        len: usize,
    ) -> Vec<Doc<'a>> {
        let assign_kind = self.seq_assignment_kind(&stmts[start]);
        let group: Vec<&LabeledSequentialStatement> = stmts[start..start + len].iter().collect();
        self.format_aligned_seq_assignments(&group, assign_kind)
    }

    /// Classify a sequential statement for alignment grouping.
    const fn seq_assignment_kind(&self, stmt: &LabeledSequentialStatement) -> SeqAssignKind {
        // Only align unlabeled simple assignments.
        if stmt.label.tree.is_some() {
            return SeqAssignKind::None;
        }
        match &stmt.statement.item {
            SequentialStatement::SignalAssignment(a)
                if matches!(a.rhs, AssignmentRightHand::Simple(_)) =>
            {
                SeqAssignKind::Signal
            }
            SequentialStatement::VariableAssignment(a)
                if matches!(a.rhs, AssignmentRightHand::Simple(_)) =>
            {
                SeqAssignKind::Variable
            }
            _ => SeqAssignKind::None,
        }
    }

    fn format_aligned_seq_assignments(
        &self,
        stmts: &[&LabeledSequentialStatement],
        kind: SeqAssignKind,
    ) -> Vec<Doc<'a>> {
        let parts: Vec<_> = stmts
            .iter()
            .map(|stmt| {
                let target = match &stmt.statement.item {
                    SequentialStatement::SignalAssignment(a) => self.format_target(&a.target),
                    SequentialStatement::VariableAssignment(a) => self.format_target(&a.target),
                    _ => self.nil(),
                };
                let target_width = self.doc_width(&target);
                (target, target_width, *stmt)
            })
            .collect();

        let max_target = parts.iter().map(|p| p.1).max().unwrap_or(0);
        let op = if kind == SeqAssignKind::Signal { "<=" } else { ":=" };

        parts
            .into_iter()
            .map(|(target, tw, stmt)| {
                let pad = " ".repeat(max_target - tw);
                let rhs = match &stmt.statement.item {
                    SequentialStatement::SignalAssignment(a) => {
                        let delay_doc = if let Some(delay) = &a.delay_mechanism {
                            self.format_delay_mechanism(delay).append(self.space())
                        } else {
                            self.nil()
                        };
                        delay_doc.append(self.format_assignment_rhs(&a.rhs, Self::format_waveform))
                    }
                    SequentialStatement::VariableAssignment(a) => {
                        self.format_assignment_rhs(&a.rhs, |f, e| f.format_expression(e.as_ref()))
                    }
                    _ => self.nil(),
                };
                target
                    .append(self.arena.text(pad))
                    .append(self.space())
                    .append(self.punct(op))
                    .append(self.space())
                    .append(rhs)
                    .append(self.punct(";"))
            })
            .collect()
    }

    fn format_labeled_sequential_statement(&self, stmt: &LabeledSequentialStatement) -> Doc<'a> {
        let label = stmt.label.tree.as_ref().map(|l| l.item.name_utf8());
        let label_doc = if let Some(name) = &label {
            self.ident(name).append(self.punct(":")).append(self.space())
        } else {
            self.nil()
        };
        label_doc.append(self.format_sequential_statement(&stmt.statement, label.as_deref()))
    }

    pub fn format_sequential_statement(
        &self,
        stmt: &WithTokenSpan<SequentialStatement>,
        label: Option<&str>,
    ) -> Doc<'a> {
        match &stmt.item {
            SequentialStatement::Wait(w) => self.format_wait_statement(w),
            SequentialStatement::Assert(a) => self
                .kw("assert")
                .append(self.space())
                .append(self.format_assert_inner(a))
                .append(self.punct(";")),
            SequentialStatement::Report(r) => self.format_report_statement(r),
            SequentialStatement::VariableAssignment(a) => self.format_variable_assignment(a),
            SequentialStatement::SignalAssignment(a) => self.format_signal_assignment(a),
            SequentialStatement::SignalForceAssignment(a) => self.format_signal_force_assignment(a),
            SequentialStatement::SignalReleaseAssignment(a) => {
                self.format_signal_release_assignment(a)
            }
            SequentialStatement::ProcedureCall(call) => {
                self.format_call_or_indexed(&call.item).append(self.punct(";"))
            }
            SequentialStatement::If(s) => self.format_if_statement(s, label),
            SequentialStatement::Case(s) => self.format_case_statement(s, label),
            SequentialStatement::Loop(s) => self.format_loop_statement(s, label),
            SequentialStatement::Next(s) => self.format_next_statement(s),
            SequentialStatement::Exit(s) => self.format_exit_statement(s),
            SequentialStatement::Return(r) => {
                let expr_doc = if let Some(expr) = &r.expression {
                    self.space().append(self.format_expression(expr.as_ref()))
                } else {
                    self.nil()
                };
                self.kw("return").append(expr_doc).append(self.punct(";"))
            }
            SequentialStatement::Null => self.kw("null").append(self.punct(";")),
        }
    }

    // -----------------------------------------------------------------------
    // Wait statement
    // -----------------------------------------------------------------------

    fn format_wait_statement(&self, stmt: &WaitStatement) -> Doc<'a> {
        let sensitivity_doc = if let Some(names) = &stmt.sensitivity_clause {
            self.space()
                .append(self.kw("on"))
                .append(self.space())
                .append(self.format_name_list(names))
        } else {
            self.nil()
        };

        let condition_doc = if let Some(cond) = &stmt.condition_clause {
            self.space()
                .append(self.kw("until"))
                .append(self.space())
                .append(self.format_expression(cond.as_ref()))
        } else {
            self.nil()
        };

        let timeout_doc = if let Some(timeout) = &stmt.timeout_clause {
            self.space()
                .append(self.kw("for"))
                .append(self.space())
                .append(self.format_expression(timeout.as_ref()))
        } else {
            self.nil()
        };

        self.kw("wait")
            .append(sensitivity_doc)
            .append(condition_doc)
            .append(timeout_doc)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Assert / report
    // -----------------------------------------------------------------------

    /// Formats the inner part of an assert: `condition [report expr] [severity expr]`
    pub fn format_assert_inner(&self, stmt: &vhdl_lang::ast::AssertStatement) -> Doc<'a> {
        let cond_doc = self.format_expression(stmt.condition.as_ref());

        let report_doc = if let Some(report) = &stmt.report {
            self.space()
                .append(self.kw("report"))
                .append(self.space())
                .append(self.format_expression(report.as_ref()))
        } else {
            self.nil()
        };

        let severity_doc = self.format_opt_severity(stmt.severity.as_ref());

        cond_doc.append(report_doc).append(severity_doc)
    }

    pub fn format_opt_severity(&self, severity: Option<&WithTokenSpan<Expression>>) -> Doc<'a> {
        if let Some(sev) = severity {
            self.space()
                .append(self.kw("severity"))
                .append(self.space())
                .append(self.format_expression(sev.as_ref()))
        } else {
            self.nil()
        }
    }

    fn format_report_statement(&self, stmt: &ReportStatement) -> Doc<'a> {
        let sev = self.format_opt_severity(stmt.severity.as_ref());
        self.kw("report")
            .append(self.space())
            .append(self.format_expression(stmt.report.as_ref()))
            .append(sev)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Assignment statements
    // -----------------------------------------------------------------------

    fn format_variable_assignment(&self, stmt: &VariableAssignment) -> Doc<'a> {
        // Handle `with expr select? target := rhs` (selected assignment)
        if let AssignmentRightHand::Selected(sel) = &stmt.rhs {
            let with_expr = self.format_expression(sel.expression.as_ref());
            let target = self.format_target(&stmt.target);
            let alternatives: Vec<Doc<'a>> = sel
                .alternatives
                .iter()
                .map(|alt| {
                    let val = self.format_expression(alt.item.as_ref());
                    let choices = self.format_choices(&alt.choices);
                    val.append(self.space())
                        .append(self.kw("when"))
                        .append(self.space())
                        .append(choices)
                })
                .collect();
            let alts_doc = self.intersperse(alternatives, self.punct(",").append(self.line()));
            return self
                .kw("with")
                .append(self.space())
                .append(with_expr)
                .append(self.space())
                .append(self.kw("select"))
                .append(self.space())
                .append(target)
                .append(self.space())
                .append(self.punct(":="))
                .append(self.space())
                .append(alts_doc)
                .append(self.punct(";"));
        }

        let target = self.format_target(&stmt.target);
        let rhs = self.format_assignment_rhs(&stmt.rhs, |f, e| f.format_expression(e.as_ref()));
        target
            .append(self.space())
            .append(self.punct(":="))
            .append(self.space())
            .append(rhs)
            .append(self.punct(";"))
    }

    fn format_signal_assignment(&self, stmt: &SignalAssignment) -> Doc<'a> {
        let target = self.format_target(&stmt.target);

        let delay_doc = if let Some(delay) = &stmt.delay_mechanism {
            self.format_delay_mechanism(delay).append(self.space())
        } else {
            self.nil()
        };

        let rhs = self.format_assignment_rhs(&stmt.rhs, Self::format_waveform);

        target
            .append(self.space())
            .append(self.punct("<="))
            .append(self.space())
            .append(delay_doc)
            .append(rhs)
            .append(self.punct(";"))
    }

    fn format_signal_force_assignment(&self, stmt: &SignalForceAssignment) -> Doc<'a> {
        use vhdl_lang::ast::ForceMode;
        let target = self.format_target(&stmt.target);
        let force_mode_doc = match &stmt.force_mode {
            Some(ForceMode::In) => self.space().append(self.kw("in")),
            Some(ForceMode::Out) => self.space().append(self.kw("out")),
            None => self.nil(),
        };
        let rhs = self.format_assignment_rhs(&stmt.rhs, |f, e| f.format_expression(e.as_ref()));
        target
            .append(self.space())
            .append(self.punct("<="))
            .append(self.space())
            .append(self.kw("force"))
            .append(force_mode_doc)
            .append(self.space())
            .append(rhs)
            .append(self.punct(";"))
    }

    fn format_signal_release_assignment(&self, stmt: &SignalReleaseAssignment) -> Doc<'a> {
        use vhdl_lang::ast::ForceMode;
        let target = self.format_target(&stmt.target);
        let release_mode_doc = match &stmt.force_mode {
            Some(ForceMode::In) => self.space().append(self.kw("in")),
            Some(ForceMode::Out) => self.space().append(self.kw("out")),
            None => self.nil(),
        };
        target
            .append(self.space())
            .append(self.punct("<="))
            .append(self.space())
            .append(self.kw("release"))
            .append(release_mode_doc)
            .append(self.punct(";"))
    }

    pub fn format_target(&self, target: &WithTokenSpan<Target>) -> Doc<'a> {
        match &target.item {
            Target::Name(name) => self.format_name(name),
            Target::Aggregate(associations) => {
                let items: Vec<Doc<'a>> =
                    associations.iter().map(|a| self.format_element_association(a)).collect();
                self.punct("(")
                    .append(self.intersperse(items, self.arena.text(", ")))
                    .append(self.punct(")"))
            }
        }
    }

    // -----------------------------------------------------------------------
    // Delay mechanism
    // -----------------------------------------------------------------------

    pub fn format_delay_mechanism(&self, delay: &WithTokenSpan<DelayMechanism>) -> Doc<'a> {
        match &delay.item {
            DelayMechanism::Transport => self.kw("transport"),
            DelayMechanism::Inertial { reject } => {
                if let Some(reject_expr) = reject {
                    self.kw("reject")
                        .append(self.space())
                        .append(self.format_expression(reject_expr.as_ref()))
                        .append(self.space())
                        .append(self.kw("inertial"))
                } else {
                    self.kw("inertial")
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // Waveforms
    // -----------------------------------------------------------------------

    pub fn format_waveform(&self, waveform: &Waveform) -> Doc<'a> {
        match waveform {
            Waveform::Elements(elements) => {
                // Check whether any comma between elements carries a trailing comment.
                // If so, we must break lines to preserve them.
                let has_trailing = elements.windows(2).any(|pair| {
                    let end_id = pair[0].get_end_token();
                    let start_id = pair[1].get_start_token();
                    let slice = self.tokens.get_token_slice(end_id, start_id);
                    slice.iter().any(|t| matches!(&t.comments, Some(c) if c.trailing.is_some()))
                });

                if has_trailing {
                    // Build with trailing comments and hard line breaks.
                    let mut doc = self.nil();
                    for (i, elem) in elements.iter().enumerate() {
                        let elem_doc = self.format_waveform_element(elem);
                        if i > 0 {
                            doc = doc.append(elem_doc);
                        } else {
                            doc = elem_doc;
                        }
                        if i < elements.len() - 1 {
                            // Emit comma + trailing comment between this and next element
                            let end_id = elem.get_end_token();
                            let start_id = elements[i + 1].get_start_token();
                            let comment = self.trailing_comments_in_span(end_id, start_id);
                            doc =
                                doc.append(self.punct(",")).append(comment).append(self.hardline());
                        }
                    }
                    doc.align()
                } else {
                    let items: Vec<Doc<'a>> =
                        elements.iter().map(|e| self.format_waveform_element(e)).collect();
                    self.intersperse(items, self.punct(",").append(self.line())).align().group()
                }
            }
            Waveform::Unaffected(_) => self.kw("unaffected"),
        }
    }

    fn format_waveform_element(&self, elem: &WaveformElement) -> Doc<'a> {
        let value_doc = self.format_expression(elem.value.as_ref());
        if let Some(after) = &elem.after {
            value_doc
                .append(self.space())
                .append(self.kw("after"))
                .append(self.space())
                .append(self.format_expression(after.as_ref()))
        } else {
            value_doc
        }
    }

    // -----------------------------------------------------------------------
    // Assignment RHS helpers
    // -----------------------------------------------------------------------

    fn format_assignment_rhs<T>(
        &self,
        rhs: &AssignmentRightHand<T>,
        fmt: impl Fn(&Self, &T) -> Doc<'a>,
    ) -> Doc<'a> {
        match rhs {
            AssignmentRightHand::Simple(v) => fmt(self, v),
            AssignmentRightHand::Conditional(conds) => {
                let mut parts: Vec<Doc<'a>> = Vec::new();
                for cond in &conds.conditionals {
                    let val = fmt(self, &cond.item);
                    let cond_doc = self.format_expression(cond.condition.as_ref());
                    parts.push(
                        val.append(self.space())
                            .append(self.kw("when"))
                            .append(self.space())
                            .append(cond_doc),
                    );
                }
                if let Some((else_val, _)) = &conds.else_item {
                    let last = self.intersperse(
                        parts,
                        self.space().append(self.kw("else")).append(self.space()),
                    );
                    last.append(self.space())
                        .append(self.kw("else"))
                        .append(self.space())
                        .append(fmt(self, else_val))
                } else {
                    self.intersperse(
                        parts,
                        self.space().append(self.kw("else")).append(self.space()),
                    )
                }
            }
            AssignmentRightHand::Selected(sel) => {
                // selected signal assignment: `with expr select target <= ... when ...`
                // (handled at the call site for variable assignments; here for signal)
                let alternatives: Vec<Doc<'a>> = sel
                    .alternatives
                    .iter()
                    .map(|alt| {
                        let val = fmt(self, &alt.item);
                        let choices = self.format_choices(&alt.choices);
                        val.append(self.space())
                            .append(self.kw("when"))
                            .append(self.space())
                            .append(choices)
                    })
                    .collect();
                self.intersperse(alternatives, self.punct(",").append(self.line()))
            }
        }
    }

    fn format_choices(&self, choices: &[WithTokenSpan<Choice>]) -> Doc<'a> {
        self.intersperse(
            choices.iter().map(|c| self.format_choice(c)),
            self.space().append(self.punct("|")).append(self.space()),
        )
    }

    // -----------------------------------------------------------------------
    // If statement
    // -----------------------------------------------------------------------

    fn format_if_statement(&self, stmt: &IfStatement, label: Option<&str>) -> Doc<'a> {
        let mut parts: Vec<Doc<'a>> = Vec::new();

        for (i, cond) in stmt.conds.conditionals.iter().enumerate() {
            let kw = if i == 0 { "if" } else { "elsif" };
            let cond_doc = self.format_expression(cond.condition.as_ref());
            let body = self.format_sequential_statements(&cond.item);

            // Layout for the condition + "then":
            //
            //   Fits on one line:
            //     if <cond> then
            //       ...
            //
            //   Wraps (condition is a long binary chain):
            //     if (a = '1') and
            //        (b = '1') and     <- align() pins to col of first operand
            //        (c = '1')
            //     then                 <- back at the if/elsif column
            //       ...
            //
            // Strategy:
            //   - Wrap the condition in align().group() so binary sub-expressions
            //     use operator-trailing with continuations aligned to the first operand.
            //   - Append a separator before "then" that is:
            //       * a plain space  when the whole group fits on one line
            //       * a plain newline (no extra indent) when it breaks
            //     This is expressed as  hardline().flat_alt(space())  which is
            //     exactly what arena.line() does — but we need it OUTSIDE the
            //     align group so "then" sits at the surrounding (if-statement)
            //     indentation level rather than the condition's align column.
            //
            // We therefore build two separate groups:
            //   1. align(cond).group()   — breaks internally at operator sites
            //   2. line() ++ "then"      — space when outer group fits, newline otherwise
            //
            // Wrapping both inside one outer group gives the desired flat/broken behaviour.
            let cond_aligned = cond_doc.align().group();

            // " then" when flat, "\nthen" (at current indent = if column) when broken.
            // arena.line() = hardline().flat_alt(space()), which is a space in flat
            // context and a newline+current-indent in break context.
            let then_sep = self.arena.line().append(self.kw("then"));

            let cond_then = cond_aligned.append(then_sep).group();

            parts.push(self.kw(kw).append(self.space()).append(cond_then).append(body));
        }

        let else_doc = if let Some((else_stmts, _)) = &stmt.conds.else_item {
            let body = self.format_sequential_statements(else_stmts);
            self.hardline().append(self.kw("else")).append(body)
        } else {
            self.nil()
        };

        let end_label_doc = if let Some(name) = label {
            self.space().append(self.ident(name))
        } else {
            self.nil()
        };

        self.intersperse(parts, self.hardline())
            .append(else_doc)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("if"))
            .append(end_label_doc)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Case statement
    // -----------------------------------------------------------------------

    fn format_case_statement(&self, stmt: &CaseStatement, label: Option<&str>) -> Doc<'a> {
        let expr_doc = self.format_expression(stmt.expression.as_ref());

        let matching = if stmt.is_matching { self.punct("?") } else { self.nil() };

        // Build choices docs and measure widths for => alignment.
        let alt_parts: Vec<_> = stmt
            .alternatives
            .iter()
            .map(|alt| {
                let choices = self.format_choices(&alt.choices);
                let choices_width = self.doc_width(&choices);
                let is_one_liner = alt.item.len() == 1
                    && !self.has_leading_comments_on(alt.item[0].statement.get_start_token());
                (choices, choices_width, &alt.item, is_one_liner)
            })
            .collect();

        // Only align => when ALL alternatives are one-liners.
        let all_one_liners = alt_parts.iter().all(|p| p.3);
        let max_choices_width = if all_one_liners {
            alt_parts.iter().map(|p| p.1).max().unwrap_or(0)
        } else {
            0
        };

        let alternatives: Vec<Doc<'a>> = alt_parts
            .into_iter()
            .map(|(choices, cw, stmts, is_one_liner)| {
                let pad = if max_choices_width > 0 {
                    " ".repeat(max_choices_width - cw)
                } else {
                    String::new()
                };
                let prefix = self
                    .kw("when")
                    .append(self.space())
                    .append(choices)
                    .append(self.arena.text(pad))
                    .append(self.space())
                    .append(self.punct("=>"));

                // Single statement without leading comments: try inline.
                if is_one_liner {
                    let stmt_doc = self.format_labeled_sequential_statement(&stmts[0]);
                    prefix.append(self.nest(self.line().append(stmt_doc))).group()
                } else {
                    let body = self.format_sequential_statements(stmts);
                    prefix.append(body)
                }
            })
            .collect();

        let alts_doc = self.nest(self.hardline().append(self.join_hardline(alternatives)));

        let end_label_doc = if let Some(name) = label {
            self.space().append(self.ident(name))
        } else {
            self.nil()
        };

        let end_matching = if stmt.is_matching { self.punct("?") } else { self.nil() };

        self.kw("case")
            .append(matching)
            .append(self.space())
            .append(expr_doc)
            .append(self.space())
            .append(self.kw("is"))
            .append(alts_doc)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("case"))
            .append(end_matching)
            .append(end_label_doc)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Loop statement
    // -----------------------------------------------------------------------

    fn format_loop_statement(&self, stmt: &LoopStatement, label: Option<&str>) -> Doc<'a> {
        let scheme_doc = if let Some(scheme) = &stmt.iteration_scheme {
            match scheme {
                IterationScheme::While(cond) => self
                    .kw("while")
                    .append(self.space())
                    .append(self.format_expression(cond.as_ref()))
                    .append(self.space()),
                IterationScheme::For(ident, range) => self
                    .kw("for")
                    .append(self.space())
                    .append(self.ident(&ident.tree.item.name_utf8()))
                    .append(self.space())
                    .append(self.kw("in"))
                    .append(self.space())
                    .append(self.format_discrete_range(range))
                    .append(self.space()),
            }
        } else {
            self.nil()
        };

        let body = self.format_sequential_statements(&stmt.statements);

        let end_label_doc = if let Some(name) = label {
            self.space().append(self.ident(name))
        } else {
            self.nil()
        };

        scheme_doc
            .append(self.kw("loop"))
            .append(body)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("loop"))
            .append(end_label_doc)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Next / exit statements
    // -----------------------------------------------------------------------

    fn format_next_statement(&self, stmt: &NextStatement) -> Doc<'a> {
        let label_doc = if let Some(label) = &stmt.loop_label {
            self.space().append(self.ident(&label.item.item.name_utf8()))
        } else {
            self.nil()
        };
        let cond_doc = if let Some(cond) = &stmt.condition {
            self.space()
                .append(self.kw("when"))
                .append(self.space())
                .append(self.format_expression(cond.as_ref()))
        } else {
            self.nil()
        };
        self.kw("next").append(label_doc).append(cond_doc).append(self.punct(";"))
    }

    fn format_exit_statement(&self, stmt: &ExitStatement) -> Doc<'a> {
        let label_doc = if let Some(label) = &stmt.loop_label {
            self.space().append(self.ident(&label.item.item.name_utf8()))
        } else {
            self.nil()
        };
        let cond_doc = if let Some(cond) = &stmt.condition {
            self.space()
                .append(self.kw("when"))
                .append(self.space())
                .append(self.format_expression(cond.as_ref()))
        } else {
            self.nil()
        };
        self.kw("exit").append(label_doc).append(cond_doc).append(self.punct(";"))
    }
}
