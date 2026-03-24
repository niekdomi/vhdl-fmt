use pretty::DocAllocator;
use vhdl_lang::HasTokenSpan;
use vhdl_lang::ast::token_range::WithTokenSpan;
use vhdl_lang::ast::{
    AliasDeclaration, ArrayIndex, Attribute, AttributeDeclaration, AttributeSpecification,
    ComponentDeclaration, Declaration, ElementDeclaration, EntityName, EnumerationLiteral,
    FileDeclaration, LibraryClause, ModeViewDeclaration, ObjectClass, ObjectDeclaration,
    PackageInstantiation, PhysicalTypeDeclaration, ProtectedTypeBody, ProtectedTypeDeclaration,
    ProtectedTypeDeclarativeItem, SubtypeIndication, TypeDeclaration, TypeDefinition, UseClause,
};

use crate::fmt::{Doc, Formatter};

impl<'a> Formatter<'a> {
    // -----------------------------------------------------------------------
    // Declaration dispatch
    // -----------------------------------------------------------------------

    pub fn format_declarations(&self, decls: &[WithTokenSpan<Declaration>]) -> Doc<'a> {
        self.format_item_list(
            decls,
            |d| (d.get_start_token(), d.get_end_token()),
            super::Formatter::try_group_declarations,
            super::Formatter::format_declaration_group,
            Self::format_declaration,
        )
    }

    fn try_group_declarations(&self, decls: &[WithTokenSpan<Declaration>], i: usize) -> usize {
        if !matches!(decls[i].item, Declaration::Object(_)) {
            return 0;
        }
        let mut j = i + 1;
        while j < decls.len() {
            if matches!(decls[j].item, Declaration::Object(_)) {
                let prev_end = decls[j - 1].get_end_token();
                let next_start = decls[j].get_start_token();
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

    fn format_declaration_group(
        &self,
        decls: &[WithTokenSpan<Declaration>],
        start: usize,
        len: usize,
    ) -> Vec<Doc<'a>> {
        let group: Vec<&ObjectDeclaration> = decls[start..start + len]
            .iter()
            .filter_map(|d| if let Declaration::Object(obj) = &d.item { Some(obj) } else { None })
            .collect();
        self.format_aligned_object_group(&group)
    }

    pub fn format_declaration(&self, decl: &WithTokenSpan<Declaration>) -> Doc<'a> {
        match &decl.item {
            Declaration::Object(obj) => self.format_object_declaration(obj),
            Declaration::File(file) => self.format_file_declaration(file),
            Declaration::Type(type_decl) => self.format_type_declaration(type_decl),
            Declaration::Component(comp) => self.format_component_declaration(comp),
            Declaration::Attribute(attr) => self.format_attribute(attr),
            Declaration::Alias(alias) => self.format_alias_declaration(alias),
            Declaration::SubprogramDeclaration(sub) => self.format_subprogram_declaration(sub),
            Declaration::SubprogramInstantiation(inst) => {
                self.format_subprogram_instantiation(inst)
            }
            Declaration::SubprogramBody(body) => self.format_subprogram_body(body),
            Declaration::Use(use_clause) => self.format_use_clause(use_clause),
            Declaration::Package(pkg) => self.format_package_instantiation(pkg),
            Declaration::Configuration(config) => self.format_configuration_specification(config),
            Declaration::View(view) => self.format_view_declaration(view),
        }
    }

    // -----------------------------------------------------------------------
    // Object declarations (signal, variable, constant, shared variable)
    // -----------------------------------------------------------------------

    pub fn format_object_declaration(&self, obj: &ObjectDeclaration) -> Doc<'a> {
        let class_kw = match obj.class {
            ObjectClass::Signal => self.kw("signal"),
            ObjectClass::Variable => self.kw("variable"),
            ObjectClass::Constant => self.kw("constant"),
            ObjectClass::SharedVariable => {
                self.kw("shared").append(self.space()).append(self.kw("variable"))
            }
        };

        let idents_doc = self.intersperse(
            obj.idents.iter().map(|id| self.ident(&id.tree.item.name_utf8())),
            self.arena.text(", "),
        );

        let subtype_doc = self.format_subtype_indication(&obj.subtype_indication);

        let default_doc = if let Some(expr) = &obj.expression {
            self.space()
                .append(self.punct(":="))
                .append(self.space())
                .append(self.format_expression(expr.as_ref()))
        } else {
            self.nil()
        };

        class_kw
            .append(self.space())
            .append(idents_doc)
            .append(self.space())
            .append(self.punct(":"))
            .append(self.space())
            .append(subtype_doc)
            .append(default_doc)
            .append(self.punct(";"))
    }

    /// Format a group of consecutive object declarations with aligned `:` and `:=`.
    fn format_aligned_object_group(&self, objs: &[&ObjectDeclaration]) -> Vec<Doc<'a>> {
        let parts: Vec<_> = objs
            .iter()
            .map(|obj| {
                let prefix = self.format_obj_decl_prefix(obj);
                let prefix_width = self.doc_width(&prefix);
                let subtype = self.format_subtype_indication(&obj.subtype_indication);
                let subtype_width = self.doc_width(&subtype);
                let default =
                    obj.expression.as_ref().map(|expr| self.format_expression(expr.as_ref()));
                (prefix, prefix_width, subtype, subtype_width, default)
            })
            .collect();

        let max_prefix = parts.iter().map(|p| p.1).max().unwrap_or(0);
        let has_any_default = parts.iter().any(|p| p.4.is_some());
        let max_subtype =
            if has_any_default { parts.iter().map(|p| p.3).max().unwrap_or(0) } else { 0 };

        parts
            .into_iter()
            .map(|(prefix, pw, subtype, sw, default)| {
                let pad1 = " ".repeat(max_prefix - pw);
                let mut d = prefix
                    .append(self.arena.text(pad1))
                    .append(self.space())
                    .append(self.punct(":"))
                    .append(self.space())
                    .append(subtype);
                if let Some(default_expr) = default {
                    let pad2 = " ".repeat(max_subtype - sw);
                    d = d
                        .append(self.arena.text(pad2))
                        .append(self.space())
                        .append(self.punct(":="))
                        .append(self.space())
                        .append(default_expr);
                }
                d.append(self.punct(";"))
            })
            .collect()
    }

    /// Build the prefix part of an object declaration: `<class> <idents>`.
    fn format_obj_decl_prefix(&self, obj: &ObjectDeclaration) -> Doc<'a> {
        let class_kw = match obj.class {
            ObjectClass::Signal => self.kw("signal"),
            ObjectClass::Variable => self.kw("variable"),
            ObjectClass::Constant => self.kw("constant"),
            ObjectClass::SharedVariable => {
                self.kw("shared").append(self.space()).append(self.kw("variable"))
            }
        };
        let idents_doc = self.intersperse(
            obj.idents.iter().map(|id| self.ident(&id.tree.item.name_utf8())),
            self.arena.text(", "),
        );
        class_kw.append(self.space()).append(idents_doc)
    }

    // -----------------------------------------------------------------------
    // File declarations
    // -----------------------------------------------------------------------

    fn format_file_declaration(&self, file: &FileDeclaration) -> Doc<'a> {
        let idents_doc = self.intersperse(
            file.idents.iter().map(|id| self.ident(&id.tree.item.name_utf8())),
            self.arena.text(", "),
        );
        let subtype_doc = self.format_subtype_indication(&file.subtype_indication);

        let open_info_doc = if let Some((_tok, open_expr)) = &file.open_info {
            self.space()
                .append(self.kw("open"))
                .append(self.space())
                .append(self.format_expression(open_expr.as_ref()))
        } else {
            self.nil()
        };

        let file_name_doc = if let Some((_tok, name_expr)) = &file.file_name {
            self.space()
                .append(self.kw("is"))
                .append(self.space())
                .append(self.format_expression(name_expr.as_ref()))
        } else {
            self.nil()
        };

        self.kw("file")
            .append(self.space())
            .append(idents_doc)
            .append(self.punct(":"))
            .append(self.space())
            .append(subtype_doc)
            .append(open_info_doc)
            .append(file_name_doc)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Type declarations
    // -----------------------------------------------------------------------

    pub fn format_type_declaration(&self, decl: &TypeDeclaration) -> Doc<'a> {
        let name = self.ident(&decl.ident.tree.item.name_utf8());
        match &decl.def {
            TypeDefinition::Incomplete(_) => {
                self.kw("type").append(self.space()).append(name).append(self.punct(";"))
            }
            def => {
                let def_doc = self.format_type_definition(def, &decl.ident.tree.item.name_utf8());
                self.kw("type")
                    .append(self.space())
                    .append(name)
                    .append(self.space())
                    .append(self.kw("is"))
                    .append(self.space())
                    .append(def_doc)
                    .append(self.punct(";"))
            }
        }
    }

    fn format_type_definition(&self, def: &TypeDefinition, type_name: &str) -> Doc<'a> {
        match def {
            TypeDefinition::Enumeration(literals) => {
                let lits: Vec<Doc<'a>> = literals
                    .iter()
                    .map(|l| self.format_enumeration_literal(&l.tree.item))
                    .collect();
                self.punct("(")
                    .append(self.intersperse(lits, self.arena.text(", ")))
                    .append(self.punct(")"))
            }
            TypeDefinition::Numeric(range) => {
                self.kw("range").append(self.space()).append(self.format_range(range))
            }
            TypeDefinition::Physical(phys) => self.format_physical_type(phys),
            TypeDefinition::Array(indices, _of_tok, subtype) => {
                self.format_array_type(indices, subtype)
            }
            TypeDefinition::Record(elements) => self.format_record_type(elements, type_name),
            TypeDefinition::Access(subtype) => self
                .kw("access")
                .append(self.space())
                .append(self.format_subtype_indication(subtype)),
            TypeDefinition::File(name) => self
                .kw("file")
                .append(self.space())
                .append(self.kw("of"))
                .append(self.space())
                .append(self.format_name(&name.item)),
            TypeDefinition::Protected(prot) => {
                self.format_protected_type_declaration(prot, type_name)
            }
            TypeDefinition::ProtectedBody(body) => self.format_protected_type_body(body, type_name),
            TypeDefinition::Subtype(subtype) => self.format_subtype_indication(subtype),
            TypeDefinition::Incomplete(_) => self.nil(), // handled above
        }
    }

    fn format_physical_type(&self, phys: &PhysicalTypeDeclaration) -> Doc<'a> {
        let range_doc = self.format_range(&phys.range);
        let primary = self.ident(&phys.primary_unit.tree.item.name_utf8());

        let secondary: Vec<Doc<'a>> = phys
            .secondary_units
            .iter()
            .map(|(ident, literal)| {
                let name = self.ident(&ident.tree.item.name_utf8());
                let lit = self.format_physical_literal(literal);
                name.append(self.space())
                    .append(self.punct("="))
                    .append(self.space())
                    .append(lit)
                    .append(self.punct(";"))
            })
            .collect();

        let units_body = if secondary.is_empty() {
            self.nest(self.hardline().append(primary.append(self.punct(";"))))
        } else {
            let sec_doc = self.join_hardline(secondary);
            self.nest(
                self.hardline()
                    .append(primary.append(self.punct(";")))
                    .append(self.hardline())
                    .append(sec_doc),
            )
        };

        self.kw("range")
            .append(self.space())
            .append(range_doc)
            .append(self.hardline())
            .append(self.nest(self.kw("units").append(units_body)))
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("units"))
    }

    fn format_physical_literal(
        &self,
        literal: &WithTokenSpan<vhdl_lang::ast::PhysicalLiteral>,
    ) -> Doc<'a> {
        use vhdl_lang::ast::AbstractLiteral;
        let value_doc = match &literal.item.value {
            AbstractLiteral::Integer(i) => self.arena.text(i.to_string()),
            AbstractLiteral::Real(r) => self.arena.text(r.to_string()),
        };
        // unit is WithRef<Ident> = WithRef<WithToken<Symbol>>; inner symbol via .item.item
        let unit = self.ident(&literal.item.unit.item.item.name_utf8());
        value_doc.append(self.space()).append(unit)
    }

    fn format_enumeration_literal(&self, lit: &EnumerationLiteral) -> Doc<'a> {
        match lit {
            EnumerationLiteral::Identifier(sym) => self.ident(&sym.name_utf8()),
            EnumerationLiteral::Character(c) => self.arena.text(format!("'{}'", *c as char)),
        }
    }

    fn format_array_type(&self, indices: &[ArrayIndex], subtype: &SubtypeIndication) -> Doc<'a> {
        let index_docs: Vec<Doc<'a>> = indices
            .iter()
            .map(|idx| match idx {
                ArrayIndex::IndexSubtypeDefintion(name) => self
                    .format_name(&name.item)
                    .append(self.space())
                    .append(self.kw("range"))
                    .append(self.space())
                    .append(self.punct("<>")),
                ArrayIndex::Discrete(range) => self.format_discrete_range(&range.item),
            })
            .collect();

        let indices_doc = self.intersperse(index_docs, self.arena.text(", "));
        let subtype_doc = self.format_subtype_indication(subtype);

        self.kw("array")
            .append(self.space())
            .append(self.punct("("))
            .append(indices_doc)
            .append(self.punct(")"))
            .append(self.space())
            .append(self.kw("of"))
            .append(self.space())
            .append(subtype_doc)
    }

    fn format_record_type(&self, elements: &[ElementDeclaration], type_name: &str) -> Doc<'a> {
        let elems: Vec<Doc<'a>> = if elements.len() > 1 {
            self.format_aligned_record_elements(elements)
        } else {
            elements.iter().map(|e| self.format_element_declaration(e)).collect()
        };
        let body = self.join_hardline(elems);
        self.kw("record")
            .append(self.nest(self.hardline().append(body)))
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("record"))
            .append(self.space())
            .append(self.ident(type_name))
    }

    fn format_element_declaration(&self, elem: &ElementDeclaration) -> Doc<'a> {
        let idents_doc = self.intersperse(
            elem.idents.iter().map(|id| self.ident(&id.tree.item.name_utf8())),
            self.arena.text(", "),
        );
        idents_doc
            .append(self.space())
            .append(self.punct(":"))
            .append(self.space())
            .append(self.format_subtype_indication(&elem.subtype))
            .append(self.punct(";"))
    }

    fn format_aligned_record_elements(&self, elements: &[ElementDeclaration]) -> Vec<Doc<'a>> {
        let parts: Vec<_> = elements
            .iter()
            .map(|elem| {
                let idents_doc = self.intersperse(
                    elem.idents.iter().map(|id| self.ident(&id.tree.item.name_utf8())),
                    self.arena.text(", "),
                );
                let idents_width = self.doc_width(&idents_doc);
                let subtype_doc = self.format_subtype_indication(&elem.subtype);
                (idents_doc, idents_width, subtype_doc)
            })
            .collect();

        let max_idents = parts.iter().map(|p| p.1).max().unwrap_or(0);

        parts
            .into_iter()
            .map(|(idents_doc, iw, subtype_doc)| {
                let pad = " ".repeat(max_idents - iw);
                idents_doc
                    .append(self.arena.text(pad))
                    .append(self.space())
                    .append(self.punct(":"))
                    .append(self.space())
                    .append(subtype_doc)
                    .append(self.punct(";"))
            })
            .collect()
    }

    fn format_protected_type_declaration(
        &self,
        prot: &ProtectedTypeDeclaration,
        type_name: &str,
    ) -> Doc<'a> {
        let items: Vec<Doc<'a>> = prot
            .items
            .iter()
            .map(|item| match item {
                ProtectedTypeDeclarativeItem::Subprogram(sub) => {
                    self.format_subprogram_declaration(sub)
                }
            })
            .collect();

        let body = if items.is_empty() {
            self.nil()
        } else {
            self.nest(self.hardline().append(self.join_hardline(items)))
        };

        self.kw("protected")
            .append(body)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("protected"))
            .append(self.space())
            .append(self.ident(type_name))
    }

    fn format_protected_type_body(&self, body: &ProtectedTypeBody, type_name: &str) -> Doc<'a> {
        let decls = self.format_declarations(&body.decl);
        let decls_doc = if body.decl.is_empty() {
            self.nil()
        } else {
            self.nest(self.hardline().append(decls))
        };

        self.kw("protected")
            .append(self.space())
            .append(self.kw("body"))
            .append(decls_doc)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("protected"))
            .append(self.space())
            .append(self.kw("body"))
            .append(self.space())
            .append(self.ident(type_name))
    }

    // -----------------------------------------------------------------------
    // Component declarations
    // -----------------------------------------------------------------------

    pub fn format_component_declaration(&self, comp: &ComponentDeclaration) -> Doc<'a> {
        let name = self.ident(&comp.ident.tree.item.name_utf8());

        let generics_doc = if let Some(generics) = &comp.generic_list {
            self.nest(
                self.hardline()
                    .append(self.kw("generic"))
                    .append(self.space())
                    .append(self.format_interface_list_semi(generics)),
            )
        } else {
            self.nil()
        };

        let ports_doc = if let Some(ports) = &comp.port_list {
            self.nest(
                self.hardline()
                    .append(self.kw("port"))
                    .append(self.space())
                    .append(self.format_interface_list_semi(ports)),
            )
        } else {
            self.nil()
        };

        self.kw("component")
            .append(self.space())
            .append(name.clone())
            .append(self.space())
            .append(self.kw("is"))
            .append(generics_doc)
            .append(ports_doc)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("component"))
            .append(self.space())
            .append(name)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Attribute declarations and specifications
    // -----------------------------------------------------------------------

    fn format_attribute(&self, attr: &Attribute) -> Doc<'a> {
        match attr {
            Attribute::Declaration(decl) => self.format_attribute_declaration(decl),
            Attribute::Specification(spec) => self.format_attribute_specification(spec),
        }
    }

    fn format_attribute_declaration(&self, decl: &AttributeDeclaration) -> Doc<'a> {
        self.kw("attribute")
            .append(self.space())
            .append(self.ident(&decl.ident.tree.item.name_utf8()))
            .append(self.punct(":"))
            .append(self.space())
            .append(self.format_name(&decl.type_mark.item))
            .append(self.punct(";"))
    }

    fn format_attribute_specification(&self, spec: &AttributeSpecification) -> Doc<'a> {
        // spec.ident is WithRef<Ident> = WithRef<WithToken<Symbol>>
        let attr_name = self.ident(&spec.ident.item.item.name_utf8());
        let entity_name_doc = match &spec.entity_name {
            EntityName::Name(name) => {
                // name.designator is WithToken<WithRef<Designator>>; inner Designator via .item.item
                let d = self.designator(&name.designator.item.item);
                if let Some(sig) = &name.signature {
                    d.append(self.format_signature(sig))
                } else {
                    d
                }
            }
            EntityName::All => self.kw("all"),
            EntityName::Others => self.kw("others"),
        };
        let entity_class_doc = self.format_entity_class(&spec.entity_class);
        let expr_doc = self.format_expression(spec.expr.as_ref());

        self.kw("attribute")
            .append(self.space())
            .append(attr_name)
            .append(self.space())
            .append(self.kw("of"))
            .append(self.space())
            .append(entity_name_doc)
            .append(self.punct(":"))
            .append(self.space())
            .append(entity_class_doc)
            .append(self.space())
            .append(self.kw("is"))
            .append(self.space())
            .append(expr_doc)
            .append(self.punct(";"))
    }

    fn format_entity_class(&self, class: &vhdl_lang::ast::EntityClass) -> Doc<'a> {
        use vhdl_lang::ast::EntityClass;
        let s = match class {
            EntityClass::Entity => "entity",
            EntityClass::Architecture => "architecture",
            EntityClass::Configuration => "configuration",
            EntityClass::Procedure => "procedure",
            EntityClass::Function => "function",
            EntityClass::Package => "package",
            EntityClass::Type => "type",
            EntityClass::Subtype => "subtype",
            EntityClass::Constant => "constant",
            EntityClass::Signal => "signal",
            EntityClass::Variable => "variable",
            EntityClass::Component => "component",
            EntityClass::Label => "label",
            EntityClass::Literal => "literal",
            EntityClass::Units => "units",
            EntityClass::File => "file",
        };
        self.kw(s)
    }

    // -----------------------------------------------------------------------
    // Alias declarations
    // -----------------------------------------------------------------------

    fn format_alias_declaration(&self, alias: &AliasDeclaration) -> Doc<'a> {
        // designator is WithDecl<WithToken<Designator>>; inner Designator via .tree.item
        let name = self.designator(&alias.designator.tree.item);
        let subtype_doc = if let Some(subtype) = &alias.subtype_indication {
            self.punct(":")
                .append(self.space())
                .append(self.format_subtype_indication(subtype))
                .append(self.space())
        } else {
            self.space()
        };
        let target = self.format_name(&alias.name.item);
        let sig_doc = if let Some(sig) = &alias.signature {
            self.format_signature(sig)
        } else {
            self.nil()
        };
        self.kw("alias")
            .append(self.space())
            .append(name)
            .append(subtype_doc)
            .append(self.kw("is"))
            .append(self.space())
            .append(target)
            .append(sig_doc)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Use / library / context-reference clauses
    // -----------------------------------------------------------------------

    pub fn format_use_clause(&self, clause: &UseClause) -> Doc<'a> {
        self.kw("use")
            .append(self.space())
            .append(self.format_name_list(&clause.name_list))
            .append(self.punct(";"))
    }

    pub fn format_library_clause(&self, clause: &LibraryClause) -> Doc<'a> {
        // name_list is Vec<WithRef<Ident>> = Vec<WithRef<WithToken<Symbol>>>
        // WithRef<T>.item gives T; WithToken<Symbol>.item gives Symbol
        let names = self.intersperse(
            clause.name_list.iter().map(|id| self.ident(&id.item.item.name_utf8())),
            self.arena.text(", "),
        );
        self.kw("library").append(self.space()).append(names).append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Package instantiation (as a declaration)
    // -----------------------------------------------------------------------

    pub fn format_package_instantiation(&self, pkg: &PackageInstantiation) -> Doc<'a> {
        let name = self.ident(&pkg.ident.tree.item.name_utf8());
        let pkg_name = self.format_name(&pkg.package_name.item);
        let generic_map_doc = if let Some(gm) = &pkg.generic_map {
            self.space().append(self.format_named_map_aspect("generic", gm))
        } else {
            self.nil()
        };
        self.kw("package")
            .append(self.space())
            .append(name)
            .append(self.space())
            .append(self.kw("is"))
            .append(self.space())
            .append(self.kw("new"))
            .append(self.space())
            .append(pkg_name)
            .append(generic_map_doc)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // Configuration specification (for … use …)
    // -----------------------------------------------------------------------

    fn format_configuration_specification(
        &self,
        config: &vhdl_lang::ast::ConfigurationSpecification,
    ) -> Doc<'a> {
        let spec = self.format_component_specification(&config.spec);
        let binding = self.format_binding_indication(&config.bind_ind);
        let end_for = if config.end_token.is_some() {
            self.hardline()
                .append(self.kw("end"))
                .append(self.space())
                .append(self.kw("for"))
                .append(self.punct(";"))
        } else {
            self.punct(";")
        };

        let vunit_docs = if config.vunit_bind_inds.is_empty() {
            self.nil()
        } else {
            let vunits: Vec<Doc<'a>> = config
                .vunit_bind_inds
                .iter()
                .map(|v| self.format_vunit_binding_indication(v))
                .collect();
            self.hardline().append(self.join_hardline(vunits))
        };

        self.kw("for")
            .append(self.space())
            .append(spec)
            .append(self.hardline())
            .append(self.nest(binding))
            .append(vunit_docs)
            .append(end_for)
    }

    pub fn format_component_specification(
        &self,
        spec: &vhdl_lang::ast::ComponentSpecification,
    ) -> Doc<'a> {
        use vhdl_lang::ast::InstantiationList;
        let list_doc = match &spec.instantiation_list {
            InstantiationList::Labels(labels) => self.intersperse(
                labels.iter().map(|l| self.ident(&l.item.name_utf8())),
                self.arena.text(", "),
            ),
            InstantiationList::Others => self.kw("others"),
            InstantiationList::All => self.kw("all"),
        };
        let comp_name = self.format_name(&spec.component_name.item);
        list_doc.append(self.punct(":")).append(self.space()).append(comp_name)
    }

    pub fn format_binding_indication(&self, bind: &vhdl_lang::ast::BindingIndication) -> Doc<'a> {
        use vhdl_lang::ast::EntityAspect;
        let entity_aspect_doc = if let Some(aspect) = &bind.entity_aspect {
            let aspect_doc = match aspect {
                EntityAspect::Entity(name, arch) => {
                    let name_doc = self.format_name(&name.item);
                    let arch_doc = if let Some(a) = arch {
                        self.punct("(")
                            .append(self.ident(&a.item.name_utf8()))
                            .append(self.punct(")"))
                    } else {
                        self.nil()
                    };
                    self.kw("entity").append(self.space()).append(name_doc).append(arch_doc)
                }
                EntityAspect::Configuration(name) => self
                    .kw("configuration")
                    .append(self.space())
                    .append(self.format_name(&name.item)),
                EntityAspect::Open => self.kw("open"),
            };
            self.kw("use").append(self.space()).append(aspect_doc).append(self.punct(";"))
        } else {
            self.nil()
        };

        let generic_map_doc = if let Some(gm) = &bind.generic_map {
            self.hardline()
                .append(self.format_named_map_aspect("generic", gm))
                .append(self.punct(";"))
        } else {
            self.nil()
        };

        let port_map_doc = if let Some(pm) = &bind.port_map {
            self.hardline()
                .append(self.format_named_map_aspect("port", pm))
                .append(self.punct(";"))
        } else {
            self.nil()
        };

        entity_aspect_doc.append(generic_map_doc).append(port_map_doc)
    }

    fn format_vunit_binding_indication(
        &self,
        vunit: &vhdl_lang::ast::VUnitBindingIndication,
    ) -> Doc<'a> {
        let names = self.format_name_list(&vunit.vunit_list);
        self.kw("use")
            .append(self.space())
            .append(self.kw("vunit"))
            .append(self.space())
            .append(names)
            .append(self.punct(";"))
    }

    // -----------------------------------------------------------------------
    // View (mode view) declarations
    // -----------------------------------------------------------------------

    fn format_view_declaration(&self, view: &ModeViewDeclaration) -> Doc<'a> {
        let name = self.ident(&view.ident.tree.item.name_utf8());
        let subtype_doc = self.format_subtype_indication(&view.typ);
        let elems: Vec<Doc<'a>> =
            view.elements.iter().map(|e| self.format_mode_view_element(e)).collect();
        let body = if elems.is_empty() {
            self.nil()
        } else {
            self.nest(self.hardline().append(self.join_hardline(elems)))
        };
        self.kw("view")
            .append(self.space())
            .append(name.clone())
            .append(self.space())
            .append(self.kw("of"))
            .append(self.space())
            .append(subtype_doc)
            .append(self.space())
            .append(self.kw("is"))
            .append(body)
            .append(self.hardline())
            .append(self.kw("end"))
            .append(self.space())
            .append(self.kw("view"))
            .append(self.space())
            .append(name)
            .append(self.punct(";"))
    }
}
