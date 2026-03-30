use vhdl_lang::HasTokenSpan;
use vhdl_lang::ast::{
    AnyDesignUnit, AnyPrimaryUnit, AnySecondaryUnit, ArchitectureBody, ConfigurationDeclaration,
    ConfigurationItem, ContextDeclaration, ContextItem, EntityDeclaration, PackageBody,
    PackageDeclaration,
};

use crate::fmt::{Doc, Formatter};

impl<'a> Formatter<'a> {
    // -----------------------------------------------------------------------
    // Top-level entry point
    // -----------------------------------------------------------------------

    pub fn format_design_unit(&self, unit: &AnyDesignUnit) -> Doc<'a> {
        let start = unit.get_start_token();
        let leading = self.leading_comments(start);
        let doc = match unit {
            AnyDesignUnit::Primary(p) => self.format_primary_unit(p),
            AnyDesignUnit::Secondary(s) => self.format_secondary_unit(s),
        };
        let doc = self.with_trailing_comments(unit, doc);
        leading.append(doc)
    }

    fn format_primary_unit(&self, unit: &AnyPrimaryUnit) -> Doc<'a> {
        match unit {
            AnyPrimaryUnit::Entity(e) => self.format_entity(e),
            AnyPrimaryUnit::Configuration(c) => self.format_configuration(c),
            AnyPrimaryUnit::Package(p) => self.format_package(p),
            AnyPrimaryUnit::PackageInstance(p) => self.format_package_instantiation(p),
            AnyPrimaryUnit::Context(c) => self.format_context(c),
        }
    }

    fn format_secondary_unit(&self, unit: &AnySecondaryUnit) -> Doc<'a> {
        match unit {
            AnySecondaryUnit::Architecture(a) => self.format_architecture(a),
            AnySecondaryUnit::PackageBody(b) => self.format_package_body(b),
        }
    }

    // -----------------------------------------------------------------------
    // Context clause  (library / use / context items at the top of a unit)
    // -----------------------------------------------------------------------

    pub fn format_context_clause(&self, clause: &[ContextItem]) -> Doc<'a> {
        if clause.is_empty() {
            return self.nil();
        }
        let body = self.format_item_list(
            clause,
            |item| (item.get_start_token(), item.get_end_token()),
            |_, _, _| 0, // no alignment grouping
            |_, _, _, _| unreachable!(),
            Self::format_context_item,
        );
        body.append(self.hardline())
    }

    fn format_context_item(&self, item: &ContextItem) -> Doc<'a> {
        match item {
            ContextItem::Library(lib) => self.format_library_clause(lib),
            ContextItem::Use(use_clause) => self.format_use_clause(use_clause),
            ContextItem::Context(ctx_ref) => self.format_context_reference(ctx_ref),
        }
    }

    fn format_context_reference(&self, ctx: &vhdl_lang::ast::ContextReference) -> Doc<'a> {
        self.kw("context")
            .append(self.space())
            .append(self.format_name_list(&ctx.name_list))
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Entity declaration
    // -----------------------------------------------------------------------

    pub fn format_entity(&self, entity: &EntityDeclaration) -> Doc<'a> {
        let context_doc = self.format_context_clause(&entity.context_clause);
        let name = self.ident(&entity.ident.tree.item.name_utf8());

        let generics_doc = if let Some(generics) = &entity.generic_clause {
            self.nest(
                self.hardline()
                    .append(self.kw("generic"))
                    .append(self.space())
                    .append(self.format_interface_list_semi(generics)),
            )
        } else {
            self.nil()
        };

        let ports_doc = if let Some(ports) = &entity.port_clause {
            self.nest(
                self.hardline()
                    .append(self.kw("port"))
                    .append(self.space())
                    .append(self.format_interface_list_semi(ports)),
            )
        } else {
            self.nil()
        };

        let decls_doc = if entity.decl.is_empty() {
            self.nil()
        } else {
            self.nest(self.hardline().append(self.format_declarations(&entity.decl)))
        };

        let begin_stmts_doc = if entity.statements.is_empty() {
            self.nil()
        } else if let Some(begin_tok) = entity.begin_token {
            self.hardline()
                .append(self.kw_tok("begin", begin_tok))
                .append(self.format_concurrent_statements(&entity.statements))
        } else {
            self.hardline()
                .append(self.kw("begin"))
                .append(self.format_concurrent_statements(&entity.statements))
        };

        let end_trailing = self.trailing_comment(entity.get_end_token());

        context_doc
            .append(self.kw("entity"))
            .append(self.space())
            .append(name.clone())
            .append(self.space())
            .append(self.kw("is"))
            .append(generics_doc)
            .append(ports_doc)
            .append(decls_doc)
            .append(begin_stmts_doc)
            .append(self.hardline())
            .append(self.kw_tok("end", entity.end_token))
            .append(self.space())
            .append(self.kw("entity"))
            .append(self.space())
            .append(name)
            .append(self.punct(";"))
            .append(end_trailing)
    }

    // -----------------------------------------------------------------------
    // Architecture body
    // -----------------------------------------------------------------------

    pub fn format_architecture(&self, arch: &ArchitectureBody) -> Doc<'a> {
        let context_doc = self.format_context_clause(&arch.context_clause);
        // ident is WithDecl<Ident> = WithDecl<WithToken<Symbol>>; name via .tree.item
        let arch_name = self.ident(&arch.ident.tree.item.name_utf8());
        // entity_name is WithRef<Ident> = WithRef<WithToken<Symbol>>; name via .item.item
        let entity_name = self.ident(&arch.entity_name.item.item.name_utf8());

        let decls_doc = if arch.decl.is_empty() {
            self.nil()
        } else {
            self.nest(self.hardline().append(self.format_declarations(&arch.decl)))
        };

        let stmts_doc = self.format_concurrent_statements(&arch.statements);

        let end_trailing = self.trailing_comment(arch.get_end_token());

        context_doc
            .append(self.kw("architecture"))
            .append(self.space())
            .append(arch_name.clone())
            .append(self.space())
            .append(self.kw("of"))
            .append(self.space())
            .append(entity_name)
            .append(self.space())
            .append(self.kw("is"))
            .append(decls_doc)
            .append(self.hardline())
            .append(self.kw_tok("begin", arch.begin_token))
            .append(stmts_doc)
            .append(self.hardline())
            .append(self.kw_tok("end", arch.end_token))
            .append(self.space())
            .append(self.kw("architecture"))
            .append(self.space())
            .append(arch_name)
            .append(self.punct(";"))
            .append(end_trailing)
    }

    // -----------------------------------------------------------------------
    // Package declaration
    // -----------------------------------------------------------------------

    pub fn format_package(&self, pkg: &PackageDeclaration) -> Doc<'a> {
        let context_doc = self.format_context_clause(&pkg.context_clause);
        let name = self.ident(&pkg.ident.tree.item.name_utf8());

        let generics_doc = if let Some(generics) = &pkg.generic_clause {
            self.nest(
                self.hardline()
                    .append(self.kw("generic"))
                    .append(self.space())
                    .append(self.format_interface_list_semi(generics)),
            )
        } else {
            self.nil()
        };

        let decls_doc = if pkg.decl.is_empty() {
            self.nil()
        } else {
            self.nest(self.hardline().append(self.format_declarations(&pkg.decl)))
        };

        let end_trailing = self.trailing_comment(pkg.get_end_token());

        context_doc
            .append(self.kw("package"))
            .append(self.space())
            .append(name.clone())
            .append(self.space())
            .append(self.kw("is"))
            .append(generics_doc)
            .append(decls_doc)
            .append(self.hardline())
            .append(self.kw_tok("end", pkg.end_token))
            .append(self.space())
            .append(self.kw("package"))
            .append(self.space())
            .append(name)
            .append(self.punct(";"))
            .append(end_trailing)
    }

    // -----------------------------------------------------------------------
    // Package body
    // -----------------------------------------------------------------------

    pub fn format_package_body(&self, body: &PackageBody) -> Doc<'a> {
        let context_doc = self.format_context_clause(&body.context_clause);
        let name = self.ident(&body.ident.tree.item.name_utf8());

        let decls_doc = if body.decl.is_empty() {
            self.nil()
        } else {
            self.nest(self.hardline().append(self.format_declarations(&body.decl)))
        };

        let end_trailing = self.trailing_comment(body.get_end_token());

        context_doc
            .append(self.kw("package"))
            .append(self.space())
            .append(self.kw("body"))
            .append(self.space())
            .append(name.clone())
            .append(self.space())
            .append(self.kw("is"))
            .append(decls_doc)
            .append(self.hardline())
            .append(self.kw_tok("end", body.end_token))
            .append(self.space())
            .append(self.kw("package"))
            .append(self.space())
            .append(self.kw("body"))
            .append(self.space())
            .append(name)
            .append(self.punct(";"))
            .append(end_trailing)
    }

    // -----------------------------------------------------------------------
    // Context declaration
    // -----------------------------------------------------------------------

    pub fn format_context(&self, ctx: &ContextDeclaration) -> Doc<'a> {
        let name = self.ident(&ctx.ident.tree.item.name_utf8());
        // ctx.items is ContextClause = Vec<ContextItem>; iterate directly
        let items: Vec<Doc<'a>> =
            ctx.items.iter().map(|item| self.format_context_item(item)).collect();

        let body_doc = if items.is_empty() {
            self.nil()
        } else {
            self.nest(self.hardline().append(self.join_hardline(items)))
        };

        self.kw("context")
            .append(self.space())
            .append(name.clone())
            .append(self.space())
            .append(self.kw("is"))
            .append(body_doc)
            .append(self.hardline())
            .append(self.kw_tok("end", ctx.end_token))
            .append(self.space())
            .append(self.kw("context"))
            .append(self.space())
            .append(name)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Configuration declaration
    // -----------------------------------------------------------------------

    pub fn format_configuration(&self, config: &ConfigurationDeclaration) -> Doc<'a> {
        let context_doc = self.format_context_clause(&config.context_clause);
        let name = self.ident(&config.ident.tree.item.name_utf8());
        let entity_name = self.format_name(&config.entity_name.item);

        let decls_doc = if config.decl.is_empty() {
            self.nil()
        } else {
            let items: Vec<Doc<'a>> =
                config.decl.iter().map(|d| self.format_declaration(d)).collect();
            self.nest(self.hardline().append(self.join_hardline(items)))
        };

        let vunit_docs = if config.vunit_bind_inds.is_empty() {
            self.nil()
        } else {
            let vunits: Vec<Doc<'a>> = config
                .vunit_bind_inds
                .iter()
                .map(|v| {
                    let names = self.format_name_list(&v.vunit_list);
                    self.kw("use")
                        .append(self.space())
                        .append(self.kw("vunit"))
                        .append(self.space())
                        .append(names)
                        .append(self.punct(";"))
                })
                .collect();
            self.nest(self.hardline().append(self.join_hardline(vunits)))
        };

        let block_config_doc = self.format_block_configuration(&config.block_config);

        context_doc
            .append(self.kw("configuration"))
            .append(self.space())
            .append(name.clone())
            .append(self.space())
            .append(self.kw("of"))
            .append(self.space())
            .append(entity_name)
            .append(self.space())
            .append(self.kw("is"))
            .append(decls_doc)
            .append(vunit_docs)
            .append(self.nest(self.hardline().append(block_config_doc)))
            .append(self.hardline())
            .append(self.kw_tok("end", config.end_token))
            .append(self.space())
            .append(self.kw("configuration"))
            .append(self.space())
            .append(name)
            .append(self.punct(";"))
    }

    fn format_block_configuration(&self, block: &vhdl_lang::ast::BlockConfiguration) -> Doc<'a> {
        // block_spec is WithTokenSpan<Name>; format as a name
        let spec_doc = self.format_name(&block.block_spec.item);

        let use_clauses: Vec<Doc<'a>> =
            block.use_clauses.iter().map(|u| self.format_use_clause(u)).collect();
        let use_doc = if use_clauses.is_empty() {
            self.nil()
        } else {
            self.nest(self.hardline().append(self.join_hardline(use_clauses)))
        };

        let items: Vec<Doc<'a>> =
            block.items.iter().map(|item| self.format_configuration_item(item)).collect();
        let items_doc = if items.is_empty() {
            self.nil()
        } else {
            self.nest(self.hardline().append(self.join_hardline(items)))
        };

        self.kw("for")
            .append(self.space())
            .append(spec_doc)
            .append(use_doc)
            .append(items_doc)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("for"))
            .append(self.punct(";"))
    }

    fn format_configuration_item(&self, item: &ConfigurationItem) -> Doc<'a> {
        match item {
            ConfigurationItem::Block(block) => self.format_block_configuration(block),
            ConfigurationItem::Component(comp) => self.format_component_configuration(comp),
        }
    }

    fn format_component_configuration(
        &self,
        comp: &vhdl_lang::ast::ComponentConfiguration,
    ) -> Doc<'a> {
        let spec = self.format_component_specification(&comp.spec);

        let binding_doc = if let Some(binding) = &comp.bind_ind {
            self.nest(self.hardline().append(self.format_binding_indication(binding)))
        } else {
            self.nil()
        };

        let vunit_docs = if comp.vunit_bind_inds.is_empty() {
            self.nil()
        } else {
            let vunits: Vec<Doc<'a>> = comp
                .vunit_bind_inds
                .iter()
                .map(|v| {
                    let names = self.format_name_list(&v.vunit_list);
                    self.kw("use")
                        .append(self.space())
                        .append(self.kw("vunit"))
                        .append(self.space())
                        .append(names)
                        .append(self.punct(";"))
                })
                .collect();
            self.nest(self.hardline().append(self.join_hardline(vunits)))
        };

        let block_config_doc = if let Some(block) = &comp.block_config {
            self.nest(self.hardline().append(self.format_block_configuration(block)))
        } else {
            self.nil()
        };

        self.kw("for")
            .append(self.space())
            .append(spec)
            .append(binding_doc)
            .append(vunit_docs)
            .append(block_config_doc)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("for"))
            .append(self.punct(";"))
    }
}
