use pretty::DocAllocator;
use vhdl_lang::ast::token_range::WithTokenSpan;
use vhdl_lang::ast::{
    FunctionSpecification, ProcedureSpecification, Signature, SubprogramBody,
    SubprogramDeclaration, SubprogramHeader, SubprogramInstantiation, SubprogramKind,
    SubprogramSpecification,
};

use crate::fmt::{Doc, Formatter};

impl<'a> Formatter<'a> {
    // -----------------------------------------------------------------------
    // Subprogram declarations  (procedure foo; / function foo return bar;)
    // -----------------------------------------------------------------------

    pub fn format_subprogram_declaration(&self, decl: &SubprogramDeclaration) -> Doc<'a> {
        self.format_subprogram_specification(&decl.specification)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Subprogram specifications
    // -----------------------------------------------------------------------

    pub fn format_subprogram_specification(&self, spec: &SubprogramSpecification) -> Doc<'a> {
        match spec {
            SubprogramSpecification::Procedure(p) => self.format_procedure_specification(p),
            SubprogramSpecification::Function(f) => self.format_function_specification(f),
        }
    }

    fn format_procedure_specification(&self, spec: &ProcedureSpecification) -> Doc<'a> {
        let name = self.subprogram_designator(&spec.designator.tree.item);

        let header_doc = if let Some(header) = &spec.header {
            self.format_subprogram_header(header)
        } else {
            self.nil()
        };

        let params_doc = if let Some(params) = &spec.parameter_list {
            self.space().append(self.format_interface_list(params))
        } else {
            self.nil()
        };

        self.kw("procedure")
            .append(self.space())
            .append(name)
            .append(header_doc)
            .append(params_doc)
    }

    fn format_function_specification(&self, spec: &FunctionSpecification) -> Doc<'a> {
        // Optional purity keyword: `pure` / `impure`
        let purity_doc = if spec.pure { self.kw("pure").append(self.space()) } else { self.nil() };

        let name = self.subprogram_designator(&spec.designator.tree.item);

        let header_doc = if let Some(header) = &spec.header {
            self.format_subprogram_header(header)
        } else {
            self.nil()
        };

        let params_doc = if let Some(params) = &spec.parameter_list {
            self.space().append(self.format_interface_list(params))
        } else {
            self.nil()
        };

        let return_doc = self
            .space()
            .append(self.kw("return"))
            .append(self.space())
            .append(self.format_name(&spec.return_type.item));

        purity_doc
            .append(self.kw("function"))
            .append(self.space())
            .append(name)
            .append(header_doc)
            .append(params_doc)
            .append(return_doc)
    }

    // -----------------------------------------------------------------------
    // Subprogram header  (generic clause + optional generic map)
    // -----------------------------------------------------------------------

    fn format_subprogram_header(&self, header: &SubprogramHeader) -> Doc<'a> {
        let generic_list_doc = self.nest(
            self.hardline()
                .append(self.kw("generic"))
                .append(self.space())
                .append(self.format_interface_list(&header.generic_list)),
        );

        let map_doc = if let Some(map) = &header.map_aspect {
            self.space().append(self.format_named_map_aspect("generic", map))
        } else {
            self.nil()
        };

        generic_list_doc.append(map_doc)
    }

    // -----------------------------------------------------------------------
    // Subprogram body
    // -----------------------------------------------------------------------

    pub fn format_subprogram_body(&self, body: &SubprogramBody) -> Doc<'a> {
        let spec_doc = self.format_subprogram_specification(&body.specification);

        let decls_doc = if body.declarations.is_empty() {
            self.nil()
        } else {
            self.nest(self.hardline().append(self.format_declarations(&body.declarations)))
        };

        let stmts_doc = if body.statements.is_empty() {
            self.nil()
        } else {
            self.format_sequential_statements(&body.statements)
        };

        // end [procedure|function] [name];
        let end_keyword = match body.specification {
            SubprogramSpecification::Procedure(_) => "procedure",
            SubprogramSpecification::Function(_) => "function",
        };
        let end_name = match &body.specification {
            SubprogramSpecification::Procedure(p) => {
                self.subprogram_designator(&p.designator.tree.item)
            }
            SubprogramSpecification::Function(f) => {
                self.subprogram_designator(&f.designator.tree.item)
            }
        };

        spec_doc
            .append(self.space())
            .append(self.kw("is"))
            .append(decls_doc)
            .append(self.hardline())
            .append(self.kw("begin"))
            .append(stmts_doc)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw(end_keyword))
            .append(self.space())
            .append(end_name)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Signatures  [type_mark, ... return type_mark]
    // -----------------------------------------------------------------------

    pub fn format_signature(&self, sig: &WithTokenSpan<Signature>) -> Doc<'a> {
        match &sig.item {
            Signature::Function(params, return_type) => {
                let params_doc = self.intersperse(
                    params.iter().map(|p| self.format_name(&p.item)),
                    self.arena.text(", "),
                );
                self.punct("[")
                    .append(params_doc)
                    .append(self.space())
                    .append(self.kw("return"))
                    .append(self.space())
                    .append(self.format_name(&return_type.item))
                    .append(self.punct("]"))
            }
            Signature::Procedure(params) => {
                let params_doc = self.intersperse(
                    params.iter().map(|p| self.format_name(&p.item)),
                    self.arena.text(", "),
                );
                self.punct("[").append(params_doc).append(self.punct("]"))
            }
        }
    }

    // -----------------------------------------------------------------------
    // Subprogram instantiation
    // -----------------------------------------------------------------------

    pub fn format_subprogram_instantiation(&self, inst: &SubprogramInstantiation) -> Doc<'a> {
        let kind_kw = match inst.kind {
            SubprogramKind::Procedure => self.kw("procedure"),
            SubprogramKind::Function => self.kw("function"),
        };
        let name = self.ident(&inst.ident.tree.item.name_utf8());
        let target = self.format_name(&inst.subprogram_name.item);

        let sig_doc = if let Some(sig) = &inst.signature {
            self.format_signature(sig)
        } else {
            self.nil()
        };

        let generic_map_doc = if let Some(gm) = &inst.generic_map {
            self.space().append(self.format_named_map_aspect("generic", gm))
        } else {
            self.nil()
        };

        kind_kw
            .append(self.space())
            .append(name)
            .append(self.space())
            .append(self.kw("is"))
            .append(self.space())
            .append(self.kw("new"))
            .append(self.space())
            .append(target)
            .append(sig_doc)
            .append(generic_map_doc)
            .append(self.punct(";"))
    }
}
