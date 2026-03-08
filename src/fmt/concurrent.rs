use vhdl_lang::HasTokenSpan;
use vhdl_lang::ast::token_range::WithTokenSpan;
use vhdl_lang::ast::{
    AssignmentRightHand, BlockStatement, CaseGenerateStatement, ConcurrentAssertStatement,
    ConcurrentProcedureCall, ConcurrentSignalAssignment, ConcurrentStatement, ForGenerateStatement,
    GenerateBody, IfGenerateStatement, InstantiatedUnit, InstantiationStatement,
    LabeledConcurrentStatement, ProcessStatement, SensitivityList,
};

use crate::fmt::{Doc, Formatter};

impl<'a> Formatter<'a> {
    // -----------------------------------------------------------------------
    // Concurrent statement list
    // -----------------------------------------------------------------------

    pub fn format_concurrent_statements(
        &self,
        statements: &[LabeledConcurrentStatement],
    ) -> Doc<'a> {
        if statements.is_empty() {
            return self.nil();
        }
        let mut body = self.nil();
        for (i, stmt) in statements.iter().enumerate() {
            let stmt_doc = self.format_labeled_concurrent_statement(stmt);
            if i == 0 {
                let trivia = self.leading_comments(stmt.statement.get_start_token());
                body = body.append(trivia).append(stmt_doc);
            } else {
                let prev = &statements[i - 1];
                let trivia = self.node_trivia(
                    prev.statement.get_end_token(),
                    stmt.statement.get_start_token(),
                );
                body = body.append(self.hardline()).append(trivia).append(stmt_doc);
            }
        }
        self.nest(self.hardline().append(body))
    }

    fn format_labeled_concurrent_statement(&self, stmt: &LabeledConcurrentStatement) -> Doc<'a> {
        let label_doc = if let Some(label) = &stmt.label.tree {
            self.ident(&label.item.name_utf8())
                .append(self.punct(":"))
                .append(self.space())
        } else {
            self.nil()
        };
        label_doc.append(self.format_concurrent_statement(&stmt.statement))
    }

    fn format_concurrent_statement(&self, stmt: &WithTokenSpan<ConcurrentStatement>) -> Doc<'a> {
        match &stmt.item {
            ConcurrentStatement::ProcedureCall(call) => self.format_concurrent_procedure_call(call),
            ConcurrentStatement::Block(block) => self.format_block_statement(block),
            ConcurrentStatement::Process(process) => self.format_process_statement(process),
            ConcurrentStatement::Assert(assert) => self.format_concurrent_assert(assert),
            ConcurrentStatement::Assignment(assignment) => {
                self.format_concurrent_signal_assignment(assignment)
            }
            ConcurrentStatement::Instance(inst) => self.format_instantiation_statement(inst),
            ConcurrentStatement::ForGenerate(stmt) => self.format_for_generate(stmt),
            ConcurrentStatement::IfGenerate(stmt) => self.format_if_generate(stmt),
            ConcurrentStatement::CaseGenerate(stmt) => self.format_case_generate(stmt),
        }
    }

    // -----------------------------------------------------------------------
    // Concurrent procedure call
    // -----------------------------------------------------------------------

    fn format_concurrent_procedure_call(&self, call: &ConcurrentProcedureCall) -> Doc<'a> {
        let postponed_doc = if call.postponed {
            self.kw("postponed").append(self.space())
        } else {
            self.nil()
        };
        postponed_doc
            .append(self.format_call_or_indexed(&call.call.item))
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Block statement
    // -----------------------------------------------------------------------

    fn format_block_statement(&self, block: &BlockStatement) -> Doc<'a> {
        let guard_doc = if let Some(guard) = &block.guard_condition {
            self.punct("(")
                .append(self.format_expression(guard.as_ref()))
                .append(self.punct(")"))
        } else {
            self.nil()
        };

        let is_doc = if block.is_token.is_some() {
            self.space().append(self.kw("is"))
        } else {
            self.nil()
        };

        // Header: generics, generic map, ports, port map
        let generics_doc = if let Some(generics) = &block.header.generic_clause {
            self.nest(
                self.hardline()
                    .append(self.kw("generic"))
                    .append(self.space())
                    .append(self.format_interface_list_semi(generics)),
            )
        } else {
            self.nil()
        };

        let generic_map_doc = if let Some(gm) = &block.header.generic_map {
            self.nest(
                self.hardline()
                    .append(self.format_named_map_aspect("generic", gm))
                    .append(self.punct(";")),
            )
        } else {
            self.nil()
        };

        let ports_doc = if let Some(ports) = &block.header.port_clause {
            self.nest(
                self.hardline()
                    .append(self.kw("port"))
                    .append(self.space())
                    .append(self.format_interface_list_semi(ports)),
            )
        } else {
            self.nil()
        };

        let port_map_doc = if let Some(pm) = &block.header.port_map {
            self.nest(
                self.hardline()
                    .append(self.format_named_map_aspect("port", pm))
                    .append(self.punct(";")),
            )
        } else {
            self.nil()
        };

        let decls_doc = if block.decl.is_empty() {
            self.nil()
        } else {
            self.nest(
                self.hardline()
                    .append(self.format_declarations(&block.decl)),
            )
        };

        let stmts_doc = self.format_concurrent_statements(&block.statements);

        self.kw("block")
            .append(guard_doc)
            .append(is_doc)
            .append(generics_doc)
            .append(generic_map_doc)
            .append(ports_doc)
            .append(port_map_doc)
            .append(decls_doc)
            .append(self.hardline())
            .append(self.kw("begin"))
            .append(stmts_doc)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("block"))
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Process statement
    // -----------------------------------------------------------------------

    pub fn format_process_statement(&self, process: &ProcessStatement) -> Doc<'a> {
        let postponed_doc = if process.postponed {
            self.kw("postponed").append(self.space())
        } else {
            self.nil()
        };

        let sensitivity_doc = if let Some(sensitivity) = &process.sensitivity_list {
            let inner = match &sensitivity.item {
                SensitivityList::Names(names) => self.format_name_list(names),
                SensitivityList::All => self.kw("all"),
            };
            self.punct("(").append(inner).append(self.punct(")"))
        } else {
            self.nil()
        };

        let is_doc = if process.is_token.is_some() {
            self.space().append(self.kw("is"))
        } else {
            self.nil()
        };

        let decls_doc = if process.decl.is_empty() {
            self.nil()
        } else {
            self.nest(
                self.hardline()
                    .append(self.format_declarations(&process.decl)),
            )
        };

        let stmts_doc = self.format_sequential_statements(&process.statements);

        // end_label_pos is Option<SrcPos> — no identifier text available.
        let end_label_doc = self.nil();
        let _ = &process.end_label_pos;

        postponed_doc
            .append(self.kw("process"))
            .append(sensitivity_doc)
            .append(is_doc)
            .append(decls_doc)
            .append(self.hardline())
            .append(self.kw("begin"))
            .append(stmts_doc)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("process"))
            .append(end_label_doc)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Concurrent assert
    // -----------------------------------------------------------------------

    fn format_concurrent_assert(&self, assert: &ConcurrentAssertStatement) -> Doc<'a> {
        let postponed_doc = if assert.postponed {
            self.kw("postponed").append(self.space())
        } else {
            self.nil()
        };
        postponed_doc
            .append(self.kw("assert"))
            .append(self.space())
            .append(self.format_assert_inner(&assert.statement))
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Concurrent signal assignment
    // -----------------------------------------------------------------------

    fn format_concurrent_signal_assignment(&self, assign: &ConcurrentSignalAssignment) -> Doc<'a> {
        let postponed_doc = if assign.postponed {
            self.kw("postponed").append(self.space())
        } else {
            self.nil()
        };

        // `with expr select` prefix for selected assignments
        let with_prefix = if let AssignmentRightHand::Selected(sel) = &assign.assignment.rhs {
            self.kw("with")
                .append(self.space())
                .append(self.format_expression(sel.expression.as_ref()))
                .append(self.space())
                .append(self.kw("select"))
                .append(self.space())
        } else {
            self.nil()
        };

        let target = self.format_target(&assign.assignment.target);

        let delay_doc = if let Some(delay) = &assign.assignment.delay_mechanism {
            self.format_delay_mechanism(delay).append(self.space())
        } else {
            self.nil()
        };

        let rhs = self.format_concurrent_rhs(&assign.assignment.rhs);

        postponed_doc
            .append(with_prefix)
            .append(target)
            .append(self.space())
            .append(self.punct("<="))
            .append(self.space())
            .append(delay_doc)
            .append(rhs)
            .append(self.punct(";"))
    }

    fn format_concurrent_rhs(
        &self,
        rhs: &AssignmentRightHand<vhdl_lang::ast::Waveform>,
    ) -> Doc<'a> {
        match rhs {
            AssignmentRightHand::Simple(waveform) => self.format_waveform(waveform),
            AssignmentRightHand::Conditional(conds) => {
                let mut parts: Vec<Doc<'a>> = Vec::new();
                for cond in &conds.conditionals {
                    let val = self.format_waveform(&cond.item);
                    let cond_doc = self.format_expression(cond.condition.as_ref());
                    parts.push(
                        val.append(self.space())
                            .append(self.kw("when"))
                            .append(self.space())
                            .append(cond_doc),
                    );
                }
                if let Some((else_waveform, _)) = &conds.else_item {
                    let joined = self.intersperse(
                        parts,
                        self.space().append(self.kw("else")).append(self.space()),
                    );
                    joined
                        .append(self.space())
                        .append(self.kw("else"))
                        .append(self.space())
                        .append(self.format_waveform(else_waveform))
                } else {
                    self.intersperse(
                        parts,
                        self.space().append(self.kw("else")).append(self.space()),
                    )
                }
            }
            AssignmentRightHand::Selected(sel) => {
                let alternatives: Vec<Doc<'a>> = sel
                    .alternatives
                    .iter()
                    .map(|alt| {
                        let val = self.format_waveform(&alt.item);
                        let choices = self.intersperse(
                            alt.choices.iter().map(|c| self.format_choice(c)),
                            self.space().append(self.punct("|")).append(self.space()),
                        );
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

    // -----------------------------------------------------------------------
    // Instantiation statement
    // -----------------------------------------------------------------------

    fn format_instantiation_statement(&self, inst: &InstantiationStatement) -> Doc<'a> {
        let unit_doc = match &inst.unit {
            InstantiatedUnit::Component(name) => self
                .kw("component")
                .append(self.space())
                .append(self.format_name(&name.item)),
            InstantiatedUnit::Entity(name, arch) => {
                let name_doc = self.format_name(&name.item);
                // arch is Option<WithRef<Ident>> = Option<WithRef<WithToken<Symbol>>>
                // inner Symbol via .item.item
                let arch_doc = if let Some(a) = arch {
                    self.punct("(")
                        .append(self.ident(&a.item.item.name_utf8()))
                        .append(self.punct(")"))
                } else {
                    self.nil()
                };
                self.kw("entity")
                    .append(self.space())
                    .append(name_doc)
                    .append(arch_doc)
            }
            InstantiatedUnit::Configuration(name) => self
                .kw("configuration")
                .append(self.space())
                .append(self.format_name(&name.item)),
        };

        let generic_map_doc = if let Some(gm) = &inst.generic_map {
            self.nest(
                self.hardline()
                    .append(self.format_named_map_aspect("generic", gm)),
            )
        } else {
            self.nil()
        };

        let port_map_doc = if let Some(pm) = &inst.port_map {
            self.nest(
                self.hardline()
                    .append(self.format_named_map_aspect("port", pm)),
            )
        } else {
            self.nil()
        };

        unit_doc
            .append(generic_map_doc)
            .append(port_map_doc)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Generate statements
    // -----------------------------------------------------------------------

    fn format_for_generate(&self, stmt: &ForGenerateStatement) -> Doc<'a> {
        let idx = self.ident(&stmt.index_name.tree.item.name_utf8());
        let range_doc = self.format_discrete_range(&stmt.discrete_range);
        let body_doc = self.format_generate_body(&stmt.body);

        // end_label_pos is Option<SrcPos> — no identifier text available.
        let end_label_doc = self.nil();
        let _ = &stmt.end_label_pos;

        self.kw("for")
            .append(self.space())
            .append(idx)
            .append(self.space())
            .append(self.kw("in"))
            .append(self.space())
            .append(range_doc)
            .append(self.space())
            .append(self.kw("generate"))
            .append(body_doc)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("generate"))
            .append(end_label_doc)
            .append(self.punct(";"))
    }

    fn format_if_generate(&self, stmt: &IfGenerateStatement) -> Doc<'a> {
        let mut parts: Vec<Doc<'a>> = Vec::new();

        for (i, cond) in stmt.conds.conditionals.iter().enumerate() {
            let kw = if i == 0 { "if" } else { "elsif" };
            let cond_doc = self.format_expression(cond.condition.as_ref());

            let alt_label_doc = if let Some(label) = &cond.item.alternative_label {
                self.ident(&label.tree.item.name_utf8())
                    .append(self.punct(":"))
                    .append(self.space())
            } else {
                self.nil()
            };

            let body_doc = self.format_generate_body(&cond.item);

            parts.push(
                self.kw(kw)
                    .append(self.space())
                    .append(alt_label_doc)
                    .append(cond_doc)
                    .append(self.space())
                    .append(self.kw("generate"))
                    .append(body_doc),
            );
        }

        let else_doc = if let Some((else_body, _)) = &stmt.conds.else_item {
            let alt_label_doc = if let Some(label) = &else_body.alternative_label {
                self.space()
                    .append(self.ident(&label.tree.item.name_utf8()))
                    .append(self.punct(":"))
            } else {
                self.nil()
            };
            let body_doc = self.format_generate_body(else_body);
            self.hardline()
                .append(self.kw("else"))
                .append(alt_label_doc)
                .append(self.space())
                .append(self.kw("generate"))
                .append(body_doc)
        } else {
            self.nil()
        };

        // end_label_pos is Option<SrcPos> — no identifier text available.
        let end_label_doc = self.nil();
        let _ = &stmt.end_label_pos;

        self.intersperse(parts, self.hardline())
            .append(else_doc)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("generate"))
            .append(end_label_doc)
            .append(self.punct(";"))
    }

    fn format_case_generate(&self, stmt: &CaseGenerateStatement) -> Doc<'a> {
        let expr_doc = self.format_expression(stmt.sels.expression.as_ref());

        let alternatives: Vec<Doc<'a>> = stmt
            .sels
            .alternatives
            .iter()
            .map(|alt| {
                let choices = self.intersperse(
                    alt.choices.iter().map(|c| self.format_choice(c)),
                    self.space().append(self.punct("|")).append(self.space()),
                );
                let alt_label_doc = if let Some(label) = &alt.item.alternative_label {
                    self.ident(&label.tree.item.name_utf8())
                        .append(self.punct(":"))
                        .append(self.space())
                } else {
                    self.nil()
                };
                let body_doc = self.format_generate_body(&alt.item);
                self.kw("when")
                    .append(self.space())
                    .append(alt_label_doc)
                    .append(choices)
                    .append(self.space())
                    .append(self.punct("=>"))
                    .append(body_doc)
            })
            .collect();

        let alts_doc = self.nest(self.hardline().append(self.join_hardline(alternatives)));

        // end_label_pos is Option<SrcPos> — no identifier text available.
        let end_label_doc = self.nil();
        let _ = &stmt.end_label_pos;

        self.kw("case")
            .append(self.space())
            .append(expr_doc)
            .append(self.space())
            .append(self.kw("generate"))
            .append(alts_doc)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("generate"))
            .append(end_label_doc)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Generate body (shared by for/if/case generate)
    // -----------------------------------------------------------------------

    fn format_generate_body(&self, body: &GenerateBody) -> Doc<'a> {
        let decls_doc = if let Some((decls, _begin_token)) = &body.decl {
            let inner = if decls.is_empty() {
                self.nil()
            } else {
                self.nest(self.hardline().append(self.format_declarations(decls)))
            };
            inner.append(self.hardline()).append(self.kw("begin"))
        } else {
            self.nil()
        };

        let stmts_doc = self.format_concurrent_statements(&body.statements);

        // Optional inner `end [label] ;`
        // body.end_label is Option<TokenId> — no text available without token access.
        let inner_end_doc = if body.end_token.is_some() {
            self.hardline()
                .append(self.kw("end"))
                .append(self.punct(";"))
        } else {
            self.nil()
        };

        decls_doc.append(stmts_doc).append(inner_end_doc)
    }
}
