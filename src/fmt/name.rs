use pretty::DocAllocator;
use vhdl_lang::ast::token_range::WithTokenSpan;
use vhdl_lang::ast::{
    ActualPart, AssociationElement, AttributeDesignator, AttributeName, CallOrIndexed,
    ExternalName, ExternalPath, Name, RangeAttribute, SeparatedList, SignalAttribute,
    TypeAttribute,
};

use crate::fmt::{Doc, Formatter};

impl<'a> Formatter<'a> {
    pub fn format_name(&self, name: &Name) -> Doc<'a> {
        match name {
            // Designator(WithRef<Designator>) — inner Designator via .item
            Name::Designator(designator) => self.designator(&designator.item),
            // Selected: suffix is WithToken<WithRef<Designator>> — inner Designator via .item.item
            Name::Selected(prefix, suffix) => self
                .format_name(&prefix.item)
                .append(self.punct("."))
                .append(self.designator(&suffix.item.item)),
            Name::SelectedAll(prefix) => {
                self.format_name(&prefix.item).append(self.punct(".")).append(self.kw("all"))
            }
            Name::Slice(prefix, range) => self
                .format_name(&prefix.item)
                .append(self.punct("("))
                .append(self.format_discrete_range(range))
                .append(self.punct(")")),
            Name::Attribute(attr) => self.format_attribute_name(attr),
            Name::CallOrIndexed(call) => self.format_call_or_indexed(call),
            Name::External(ext) => self.format_external_name(ext),
        }
    }

    pub fn format_name_list(&self, names: &[WithTokenSpan<Name>]) -> Doc<'a> {
        self.intersperse(names.iter().map(|n| self.format_name(&n.item)), self.arena.text(", "))
    }

    pub fn format_call_or_indexed(&self, call: &CallOrIndexed) -> Doc<'a> {
        let prefix = self.format_name(&call.name.item);
        let assocs = self.format_association_list(&call.parameters);
        prefix.append(self.punct("(")).append(assocs).append(self.punct(")"))
    }

    pub fn format_attribute_name(&self, attr: &AttributeName) -> Doc<'a> {
        let prefix = self.format_name(&attr.name.item);
        // The signature (e.g. [return type]) is rare but possible.
        let sig = if let Some(sig) = &attr.signature {
            self.format_signature(sig)
        } else {
            self.nil()
        };
        // attr.attr is WithToken<AttributeDesignator>; inner via .item
        let attr_id = self.format_attribute_designator(&attr.attr.item);
        let expr_part = if let Some(expr) = &attr.expr {
            self.punct("(")
                // expr is Box<WithTokenSpan<Expression>>; use &** to get
                // &WithTokenSpan<Expression> then auto-deref calls WithTokenSpan::as_ref()
                .append(self.format_expression((**expr).as_ref()))
                .append(self.punct(")"))
        } else {
            self.nil()
        };
        prefix.append(sig).append(self.punct("'")).append(attr_id).append(expr_part)
    }

    fn format_attribute_designator(&self, attr: &AttributeDesignator) -> Doc<'a> {
        match attr {
            AttributeDesignator::Type(TypeAttribute::Subtype) => self.kw("subtype"),
            AttributeDesignator::Type(TypeAttribute::Element) => self.kw("element"),
            AttributeDesignator::Range(RangeAttribute::Range) => self.kw("range"),
            AttributeDesignator::Range(RangeAttribute::ReverseRange) => self.kw("reverse_range"),
            // WithRef<Symbol>: inner Symbol via .item
            AttributeDesignator::Ident(sym) => self.ident(&sym.item.name_utf8()),
            AttributeDesignator::Ascending => self.kw("ascending"),
            AttributeDesignator::Left => self.kw("left"),
            AttributeDesignator::Right => self.kw("right"),
            AttributeDesignator::High => self.kw("high"),
            AttributeDesignator::Low => self.kw("low"),
            AttributeDesignator::Length => self.kw("length"),
            AttributeDesignator::Image => self.kw("image"),
            AttributeDesignator::Value => self.kw("value"),
            AttributeDesignator::Pos => self.kw("pos"),
            AttributeDesignator::Val => self.kw("val"),
            AttributeDesignator::Succ => self.kw("succ"),
            AttributeDesignator::Pred => self.kw("pred"),
            AttributeDesignator::LeftOf => self.kw("leftof"),
            AttributeDesignator::RightOf => self.kw("rightof"),
            AttributeDesignator::Signal(sa) => {
                let s = match sa {
                    SignalAttribute::Delayed => "delayed",
                    SignalAttribute::Stable => "stable",
                    SignalAttribute::Quiet => "quiet",
                    SignalAttribute::Transaction => "transaction",
                    SignalAttribute::Event => "event",
                    SignalAttribute::Active => "active",
                    SignalAttribute::LastEvent => "last_event",
                    SignalAttribute::LastActive => "last_active",
                    SignalAttribute::LastValue => "last_value",
                    SignalAttribute::Driving => "driving",
                    SignalAttribute::DrivingValue => "driving_value",
                };
                self.kw(s)
            }
            AttributeDesignator::SimpleName => self.kw("simple_name"),
            AttributeDesignator::InstanceName => self.kw("instance_name"),
            AttributeDesignator::PathName => self.kw("path_name"),
            AttributeDesignator::Converse => self.kw("converse"),
        }
    }

    pub fn format_external_name(&self, ext: &ExternalName) -> Doc<'a> {
        // << class path : subtype >>
        let class = match ext.class {
            vhdl_lang::ast::ExternalObjectClass::Constant => self.kw("constant"),
            vhdl_lang::ast::ExternalObjectClass::Signal => self.kw("signal"),
            vhdl_lang::ast::ExternalObjectClass::Variable => self.kw("variable"),
        };
        // ext.path is WithTokenSpan<ExternalPath>; unwrap via .item
        let path = self.format_external_path(&ext.path.item);
        // ext.subtype is SubtypeIndication (not wrapped)
        let subtype = self.format_subtype_indication(&ext.subtype);
        self.punct("<<")
            .append(self.space())
            .append(class)
            .append(self.space())
            .append(path)
            .append(self.space())
            .append(self.punct(":"))
            .append(self.space())
            .append(subtype)
            .append(self.space())
            .append(self.punct(">>"))
    }

    fn format_external_path(&self, path: &ExternalPath) -> Doc<'a> {
        match path {
            // Each variant holds WithTokenSpan<Name>; inner Name via .item
            ExternalPath::Package(name) => self.punct("@").append(self.format_name(&name.item)),
            ExternalPath::Absolute(name) => self.punct(".").append(self.format_name(&name.item)),
            ExternalPath::Relative(name, up) => {
                let dots = self.arena.text("^.".repeat(*up));
                dots.append(self.format_name(&name.item))
            }
        }
    }

    // -----------------------------------------------------------------------
    // Association lists (port map / generic map / call arguments)
    // -----------------------------------------------------------------------

    pub fn format_association_list(&self, list: &SeparatedList<AssociationElement>) -> Doc<'a> {
        if list.items.is_empty() {
            return self.nil();
        }
        let items: Vec<Doc<'a>> =
            list.items.iter().map(|el| self.format_association_element(el)).collect();
        // Try to fit all on one line; if not, one per line with trailing indent.
        let inner = self.intersperse(items, self.punct(",").append(self.line()));
        self.nest(self.line_().append(inner)).append(self.line_()).group()
    }

    pub fn format_association_element(&self, element: &AssociationElement) -> Doc<'a> {
        let actual = match &element.actual.item {
            ActualPart::Expression(expr) => {
                self.format_expression(WithTokenSpan::new(expr, element.actual.span))
            }
            ActualPart::Open => self.kw("open"),
        };
        if let Some(formal) = &element.formal {
            self.format_name(&formal.item)
                .append(self.space())
                .append(self.punct("=>"))
                .append(self.space())
                .append(actual)
        } else {
            actual
        }
    }

    /// Format an association list already wrapped in `(…)` with one-per-line
    /// breaking when it doesn't fit inline.
    pub fn format_association_list_parens(
        &self,
        list: &SeparatedList<AssociationElement>,
    ) -> Doc<'a> {
        if list.items.is_empty() {
            return self.punct("(").append(self.punct(")"));
        }
        let items: Vec<Doc<'a>> =
            list.items.iter().map(|el| self.format_association_element(el)).collect();
        let inner = self.intersperse(items, self.punct(",").append(self.line()));
        self.punct("(")
            .append(self.nest(self.line_().append(inner)))
            .append(self.line_())
            .append(self.punct(")"))
            .group()
    }

    /// Format a map association list (generic map / port map) with aligned `=>`
    /// and always multiline when there are 2+ named items.
    pub fn format_map_association_list_parens(
        &self,
        list: &SeparatedList<AssociationElement>,
    ) -> Doc<'a> {
        if list.items.is_empty() {
            return self.punct("(").append(self.punct(")"));
        }

        // Check if all elements are named (have formal => actual).
        let all_named = list.items.iter().all(|el| el.formal.is_some());

        if all_named && list.items.len() > 1 {
            // Measure formal widths for => alignment.
            let parts: Vec<_> = list
                .items
                .iter()
                .map(|el| {
                    let formal = self.format_name(&el.formal.as_ref().unwrap().item);
                    let formal_width = self.doc_width(&formal);
                    let actual = match &el.actual.item {
                        ActualPart::Expression(expr) => {
                            self.format_expression(WithTokenSpan::new(expr, el.actual.span))
                        }
                        ActualPart::Open => self.kw("open"),
                    };
                    (formal, formal_width, actual)
                })
                .collect();

            let max_formal = parts.iter().map(|p| p.1).max().unwrap_or(0);

            let items: Vec<Doc<'a>> = parts
                .into_iter()
                .enumerate()
                .map(|(i, (formal, fw, actual))| {
                    let pad = " ".repeat(max_formal - fw);
                    let item = formal
                        .append(self.arena.text(pad))
                        .append(self.space())
                        .append(self.punct("=>"))
                        .append(self.space())
                        .append(actual);
                    if i < list.items.len() - 1 { item.append(self.punct(",")) } else { item }
                })
                .collect();

            let inner = self.join_hardline(items);
            self.punct("(")
                .append(self.nest(self.hardline().append(inner)))
                .append(self.hardline())
                .append(self.punct(")"))
        } else {
            // Single item or positional — use standard formatting.
            self.format_association_list_parens(list)
        }
    }
}
