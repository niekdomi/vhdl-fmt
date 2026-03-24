use pretty::DocAllocator;
use vhdl_lang::ast::token_range::WithTokenSpan;
use vhdl_lang::ast::{
    AbstractLiteral, Allocator, AttributeName, Choice, DiscreteRange, ElementAssociation,
    Expression, Literal, QualifiedExpression, Range, ResolutionIndication, SubtypeConstraint,
    SubtypeIndication,
};

use crate::fmt::{Doc, Formatter};

impl<'a> Formatter<'a> {
    // -----------------------------------------------------------------------
    // Expressions
    // -----------------------------------------------------------------------

    pub fn format_expression(&self, expr: WithTokenSpan<&Expression>) -> Doc<'a> {
        match expr.item {
            Expression::Binary(op, _lhs, _rhs) => {
                // For chains of the same operator (e.g. a or b or c or d),
                // flatten into a single group so they break uniformly:
                // either all on one line, or one operand per line.
                let op_str = op.item.item.to_string().to_lowercase();
                let mut operands: Vec<Doc<'a>> = Vec::new();
                self.collect_binary_chain(&op_str, expr, &mut operands);

                let op_doc = self.arena.text(self.config.casing.keywords.apply(&op_str));
                let first = operands.remove(0);
                let mut doc = first;
                for operand in operands {
                    doc = doc
                        .append(self.space())
                        .append(op_doc.clone())
                        .append(self.line())
                        .append(operand);
                }
                doc.align().group()
            }
            Expression::Unary(op, rhs) => {
                use vhdl_lang::ast::Operator;
                let op_str = op.item.item.to_string().to_lowercase();
                let op_doc = self.ident(&op_str);
                let rhs_doc = self.format_expression((**rhs).as_ref());
                match op.item.item {
                    // These bind tightly — no space after the operator.
                    Operator::Minus | Operator::Plus | Operator::QueQue => op_doc.append(rhs_doc),
                    _ => op_doc.append(self.space()).append(rhs_doc),
                }
            }
            Expression::Aggregate(associations) => {
                if associations.is_empty() {
                    return self.punct("(").append(self.punct(")"));
                }
                let items: Vec<Doc<'a>> =
                    associations.iter().map(|a| self.format_element_association(a)).collect();
                let inner = self.intersperse(items, self.punct(",").append(self.line()));
                self.punct("(")
                    .append(self.nest(self.line_().append(inner)))
                    .append(self.line_())
                    .append(self.punct(")"))
                    .group()
            }
            Expression::Qualified(qualified) => self.format_qualified_expression(qualified),
            Expression::Name(name) => self.format_name(name),
            Expression::Literal(literal) => self.format_literal(literal),
            Expression::New(allocator) => self.format_allocator(allocator),
            Expression::Parenthesized(inner) => {
                let inner_doc = self.format_expression((**inner).as_ref());
                self.punct("(").append(inner_doc).append(self.punct(")"))
            }
        }
    }

    /// Flatten a left-associative chain of the same binary operator into a
    /// list of operands. For `((a or b) or c) or d` with `target_op="or"`,
    /// produces `[a, b, c, d]`. Operands that use a different operator are
    /// formatted as complete sub-expressions.
    fn collect_binary_chain(
        &self,
        target_op: &str,
        expr: WithTokenSpan<&Expression>,
        operands: &mut Vec<Doc<'a>>,
    ) {
        if let Expression::Binary(op, lhs, _rhs) = expr.item {
            let op_str = op.item.item.to_string().to_lowercase();
            if op_str == target_op {
                // Recurse into LHS (left-associative chain)
                self.collect_binary_chain(target_op, (**lhs).as_ref(), operands);
                // RHS is always a leaf of the chain
                operands.push(self.format_expression((**_rhs).as_ref()));
                return;
            }
        }
        // Not the same operator — format as a complete expression
        operands.push(self.format_expression(expr));
    }

    fn format_literal(&self, literal: &Literal) -> Doc<'a> {
        match literal {
            Literal::AbstractLiteral(al) => match al {
                AbstractLiteral::Integer(i) => self.arena.text(i.to_string()),
                AbstractLiteral::Real(r) => self.arena.text(r.to_string()),
            },
            Literal::Character(c) => self.arena.text(format!("'{}'", *c as char)),
            Literal::String(s) => {
                let mut out = String::from('"');
                for byte in &s.bytes {
                    if *byte == b'"' {
                        out.push('"');
                    }
                    out.push(*byte as char);
                }
                out.push('"');
                self.arena.text(out)
            }
            Literal::BitString(bs) => self.arena.text(bs.to_string()),
            // Physical(PhysicalLiteral) where unit is WithRef<Ident> = WithRef<WithToken<Symbol>>
            Literal::Physical(phys) => {
                let num = match &phys.value {
                    AbstractLiteral::Integer(i) => i.to_string(),
                    AbstractLiteral::Real(r) => r.to_string(),
                };
                // unit.item is WithToken<Symbol>; unit.item.item is Symbol
                self.arena
                    .text(num)
                    .append(self.space())
                    .append(self.ident(&phys.unit.item.item.name_utf8()))
            }
            Literal::Null => self.kw("null"),
        }
    }

    pub fn format_qualified_expression(&self, expr: &QualifiedExpression) -> Doc<'a> {
        // expr.expr is WithTokenSpan<Expression>; .as_ref() gives WithTokenSpan<&Expression>
        self.format_name(&expr.type_mark.item)
            .append(self.punct("'"))
            .append(self.format_expression(expr.expr.as_ref()))
    }

    fn format_allocator(&self, allocator: &WithTokenSpan<Allocator>) -> Doc<'a> {
        let inner = match &allocator.item {
            // Allocator::Qualified holds Box<QualifiedExpression>
            Allocator::Qualified(q) => self.format_qualified_expression(q),
            Allocator::Subtype(s) => self.format_subtype_indication(s),
        };
        self.kw("new").append(self.space()).append(inner)
    }

    pub fn format_element_association(&self, assoc: &WithTokenSpan<ElementAssociation>) -> Doc<'a> {
        match &assoc.item {
            ElementAssociation::Positional(expr) => {
                // expr is WithTokenSpan<Expression>; .as_ref() is correct
                self.format_expression(expr.as_ref())
            }
            ElementAssociation::Named(choices, expr) => {
                let choices_doc = self.intersperse(
                    choices.iter().map(|c| self.format_choice(c)),
                    self.space().append(self.punct("|")).append(self.space()),
                );
                choices_doc
                    .append(self.space())
                    .append(self.punct("=>"))
                    .append(self.space())
                    .append(self.format_expression(expr.as_ref()))
            }
        }
    }

    pub fn format_choice(&self, choice: &WithTokenSpan<Choice>) -> Doc<'a> {
        match &choice.item {
            Choice::Expression(expr) => {
                self.format_expression(WithTokenSpan::new(expr, choice.span))
            }
            Choice::DiscreteRange(range) => self.format_discrete_range(range),
            Choice::Others => self.kw("others"),
        }
    }

    // -----------------------------------------------------------------------
    // Subtype indication and constraints
    // -----------------------------------------------------------------------

    pub fn format_subtype_indication(&self, indication: &SubtypeIndication) -> Doc<'a> {
        let resolution = if let Some(res) = &indication.resolution {
            self.format_resolution_indication(res).append(self.space())
        } else {
            self.nil()
        };
        let type_mark = self.format_name(&indication.type_mark.item);
        let constraint = if let Some(c) = &indication.constraint {
            self.format_subtype_constraint(c)
        } else {
            self.nil()
        };
        resolution.append(type_mark).append(constraint)
    }

    fn format_resolution_indication(&self, res: &ResolutionIndication) -> Doc<'a> {
        match res {
            ResolutionIndication::FunctionName(name) => self.format_name(&name.item),
            ResolutionIndication::ArrayElement(name) => {
                self.punct("(").append(self.format_name(&name.item)).append(self.punct(")"))
            }
            ResolutionIndication::Record(record) => {
                let items: Vec<Doc<'a>> = record
                    .item
                    .iter()
                    .map(|elem| {
                        self.ident(&elem.ident.item.name_utf8())
                            .append(self.space())
                            .append(self.format_resolution_indication(&elem.resolution))
                    })
                    .collect();
                self.punct("(")
                    .append(self.intersperse(items, self.punct(",").append(self.space())))
                    .append(self.punct(")"))
            }
        }
    }

    pub fn format_subtype_constraint(
        &self,
        constraint: &WithTokenSpan<SubtypeConstraint>,
    ) -> Doc<'a> {
        match &constraint.item {
            SubtypeConstraint::Range(range) => self.space().append(self.format_range(range)),
            SubtypeConstraint::Array(ranges, element) => {
                let range_docs: Vec<Doc<'a>> =
                    ranges.iter().map(|r| self.format_discrete_range(&r.item)).collect();
                let ranges_doc = self.intersperse(range_docs, self.punct(",").append(self.space()));
                let elem_doc = if let Some(e) = element {
                    self.format_subtype_constraint(e)
                } else {
                    self.nil()
                };
                self.punct("(").append(ranges_doc).append(self.punct(")")).append(elem_doc)
            }
            SubtypeConstraint::Record(elements) => {
                let items: Vec<Doc<'a>> = elements
                    .iter()
                    .map(|e| {
                        self.ident(&e.ident.item.name_utf8())
                            .append(self.format_subtype_constraint(&e.constraint))
                    })
                    .collect();
                self.punct("(")
                    .append(self.intersperse(items, self.punct(",").append(self.space())))
                    .append(self.punct(")"))
            }
        }
    }

    // -----------------------------------------------------------------------
    // Ranges and discrete ranges
    // -----------------------------------------------------------------------

    pub fn format_range(&self, range: &Range) -> Doc<'a> {
        match range {
            Range::Range(constraint) => {
                // left_expr/right_expr are Box<WithTokenSpan<Expression>>; use &* to get
                // &WithTokenSpan<Expression> then auto-deref calls WithTokenSpan::as_ref()
                let left = self.format_expression((*constraint.left_expr).as_ref());
                let dir = match constraint.direction {
                    vhdl_lang::ast::Direction::Ascending => self.kw("to"),
                    vhdl_lang::ast::Direction::Descending => self.kw("downto"),
                };
                let right = self.format_expression((*constraint.right_expr).as_ref());
                left.append(self.space()).append(dir).append(self.space()).append(right)
            }
            // attr is Box<AttributeName>
            Range::Attribute(attr) => self.format_range_attribute(attr),
        }
    }

    fn format_range_attribute(&self, attr: &AttributeName) -> Doc<'a> {
        // Delegate to the name formatter which handles AttributeName fully
        self.format_attribute_name(attr)
    }

    pub fn format_discrete_range(&self, range: &DiscreteRange) -> Doc<'a> {
        match range {
            DiscreteRange::Discrete(type_mark, constraint) => {
                let tm = self.format_name(&type_mark.item);
                // constraint is Option<Range>, not Option<SubtypeConstraint>
                if let Some(r) = constraint {
                    tm.append(self.space()).append(self.format_range(r))
                } else {
                    tm
                }
            }
            DiscreteRange::Range(range) => self.format_range(range),
        }
    }
}
