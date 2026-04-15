use pretty::DocAllocator;
use vhdl_lang::HasTokenSpan;
use vhdl_lang::ast::{
    InterfaceDeclaration, InterfaceFileDeclaration, InterfaceList, InterfaceObjectDeclaration,
    InterfacePackageDeclaration, InterfacePackageGenericMapAspect, InterfaceSubprogramDeclaration,
    InterfaceType, MapAspect, ModeIndication, ModeViewElement, ModeViewIndication,
    ModeViewIndicationKind, ObjectClass, SimpleModeIndication, SubprogramDefault,
};

use crate::fmt::{Doc, Formatter};

impl<'a> Formatter<'a> {
    // -------------------------------------------------------------------------
    // Interface lists  (port / generic / parameter clauses)
    // -------------------------------------------------------------------------

    /// Format a full interface list including the leading keyword and parens:
    ///   `port (`
    ///       `item;`
    ///       `item`
    ///   `);`
    /// or for a bare parameter list just `( items )`.
    pub fn format_interface_list(&self, list: &InterfaceList) -> Doc<'a> {
        self.format_interface_list_inner(list, None)
    }

    /// Same as `format_interface_list` but appends a trailing `;` after the
    /// closing `)`.  Used for generic/port clauses inside entity/component.
    pub fn format_interface_list_semi(&self, list: &InterfaceList) -> Doc<'a> {
        self.format_interface_list_inner(list, Some(";"))
    }

    fn format_interface_list_inner(
        &self,
        list: &InterfaceList,
        trailing: Option<&'static str>,
    ) -> Doc<'a> {
        // Check which items are interface objects (candidates for alignment).
        let obj_count = list
            .items
            .iter()
            .filter(|item| matches!(item, InterfaceDeclaration::Object(_)))
            .count();

        // Build aligned docs for all interface objects if there are 2+.
        let aligned: Option<Vec<Doc<'a>>> = if obj_count > 1 {
            let objs: Vec<&InterfaceObjectDeclaration> = list
                .items
                .iter()
                .filter_map(|item| {
                    if let InterfaceDeclaration::Object(obj) = item { Some(obj) } else { None }
                })
                .collect();
            Some(self.format_aligned_interface_objects(&objs))
        } else {
            None
        };

        let mut aligned_iter = aligned.as_ref().map(|v| v.iter());

        // Build items with trailing comments and blank line preservation.
        let mut inner = self.nil();
        for (i, item) in list.items.iter().enumerate() {
            let item_doc = if matches!(item, InterfaceDeclaration::Object(_)) {
                if let Some(ref mut iter) = aligned_iter {
                    iter.next().unwrap().clone()
                } else {
                    self.format_interface_declaration(item)
                }
            } else {
                self.format_interface_declaration(item)
            };

            // Add semicolon for all but last item.
            let item_doc = if i < list.items.len() - 1 {
                item_doc.append(self.punct(";"))
            } else {
                item_doc
            };

            // Add trailing comment(s): scan the full item span for internal
            // comments, plus any comments between this item and the next.
            let item_start = item.get_start_token();
            let item_end = item.get_end_token();
            let tc = if i < list.items.len() - 1 {
                let next_start = list.items[i + 1].get_start_token();
                self.trailing_comments_in_span(item_start, next_start)
            } else {
                self.trailing_comments_in_span(item_start, item_end)
            };

            if i == 0 {
                let trivia = self.leading_comments(item.get_start_token());
                inner = inner.append(trivia).append(item_doc).append(tc);
            } else {
                let prev_end = list.items[i - 1].get_end_token();
                let trivia = self.node_trivia(prev_end, item.get_start_token());
                inner = inner.append(self.hardline()).append(trivia).append(item_doc).append(tc);
            }
        }

        let body = self
            .punct("(")
            .append(self.nest(self.hardline().append(inner)))
            .append(self.hardline())
            .append(self.punct(")"));

        if let Some(t) = trailing { body.append(self.punct(t)) } else { body }
    }

    /// Format a group of interface objects with aligned `:`, mode keywords, and types.
    fn format_aligned_interface_objects(
        &self,
        objs: &[&InterfaceObjectDeclaration],
    ) -> Vec<Doc<'a>> {
        // Collect parts: (prefix, prefix_width, mode_kw, mode_kw_width, subtype_default_doc)
        let parts: Vec<_> = objs
            .iter()
            .map(|obj| {
                let prefix = self.format_interface_obj_prefix(obj);
                let prefix_width = self.doc_width(&prefix);

                match &obj.mode {
                    ModeIndication::Simple(simple) => {
                        let mode_s = simple.mode.as_ref().map(|m| Self::mode_str(m.item));
                        let mode_kw: Option<Doc<'a>> = mode_s.map(|s| self.kw(s));
                        let mode_kw_width = mode_s.map_or(0, str::len);

                        let subtype = self.format_subtype_indication(&simple.subtype_indication);
                        let default = if let Some(expr) = &simple.expression {
                            self.space()
                                .append(self.punct(":="))
                                .append(self.space())
                                .append(self.format_expression(expr.as_ref()))
                        } else {
                            self.nil()
                        };

                        (prefix, prefix_width, mode_kw, mode_kw_width, subtype.append(default))
                    }
                    ModeIndication::View(_) => {
                        let mode_doc = self.format_mode_indication(&obj.mode);
                        (prefix, prefix_width, None, 0, mode_doc)
                    }
                }
            })
            .collect();

        let max_prefix = parts.iter().map(|p| p.1).max().unwrap_or(0);
        let max_mode_kw = parts.iter().map(|p| p.3).max().unwrap_or(0);

        parts
            .into_iter()
            .map(|(prefix, pw, mode_kw, mkw, subtype_default)| {
                let prefix_pad = " ".repeat(max_prefix - pw);
                let mut doc = prefix
                    .append(self.arena.text(prefix_pad))
                    .append(self.space())
                    .append(self.punct(":"))
                    .append(self.space());

                if let Some(kw) = mode_kw {
                    let mode_pad = " ".repeat(max_mode_kw - mkw);
                    doc = doc
                        .append(kw)
                        .append(self.arena.text(mode_pad))
                        .append(self.space())
                        .append(subtype_default);
                } else if max_mode_kw > 0 {
                    // No mode keyword but others have one — add padding.
                    let mode_pad = " ".repeat(max_mode_kw + 1);
                    doc = doc.append(self.arena.text(mode_pad)).append(subtype_default);
                } else {
                    doc = doc.append(subtype_default);
                }

                doc
            })
            .collect()
    }

    /// Returns true if the class keyword is the implicit default for the
    /// interface context and should be omitted.
    const fn is_implicit_class(list_type: &InterfaceType, class: &ObjectClass) -> bool {
        matches!(
            (list_type, class),
            (InterfaceType::Port, ObjectClass::Signal)
                | (InterfaceType::Generic, ObjectClass::Constant)
        )
    }

    /// Build an optional class keyword doc for an interface object.
    /// Returns `None` when the class is implicit for the context.
    fn interface_class_doc(&self, obj: &InterfaceObjectDeclaration) -> Option<Doc<'a>> {
        match &obj.mode {
            ModeIndication::Simple(simple) => {
                if Self::is_implicit_class(&obj.list_type, &simple.class) {
                    return None;
                }
                Some(self.object_class_kw(simple.class))
            }
            ModeIndication::View(_) => None,
        }
    }

    /// Build the prefix of an interface object: `[class] idents`.
    fn format_interface_obj_prefix(&self, obj: &InterfaceObjectDeclaration) -> Doc<'a> {
        let class_doc = self.interface_class_doc(obj);
        let idents_doc = self.intersperse(
            obj.idents.iter().map(|id| self.ident(&id.tree.item.name_utf8())),
            self.arena.text(", "),
        );
        if let Some(cls) = class_doc {
            cls.append(self.space()).append(idents_doc)
        } else {
            idents_doc
        }
    }

    // -------------------------------------------------------------------------
    // Individual interface declarations
    // -------------------------------------------------------------------------

    pub fn format_interface_declaration(&self, decl: &InterfaceDeclaration) -> Doc<'a> {
        match decl {
            InterfaceDeclaration::Object(obj) => self.format_interface_object(obj),
            InterfaceDeclaration::File(file) => self.format_interface_file_declaration(file),
            InterfaceDeclaration::Type(type_decl) => self
                .kw("type")
                .append(self.space())
                .append(self.ident(&type_decl.tree.item.name_utf8())),
            InterfaceDeclaration::Subprogram(sub) => {
                self.format_interface_subprogram_declaration(sub)
            }
            InterfaceDeclaration::Package(pkg) => self.format_interface_package_declaration(pkg),
        }
    }

    pub fn format_interface_object(&self, obj: &InterfaceObjectDeclaration) -> Doc<'a> {
        let class_doc = self.interface_class_doc(obj);

        // Identifier list  (e.g. `a, b, c`)
        let idents_doc = self.intersperse(
            obj.idents.iter().map(|id| self.ident(&id.tree.item.name_utf8())),
            self.arena.text(", "),
        );

        let mode_doc = self.format_mode_indication(&obj.mode);

        let base = idents_doc
            .append(self.space())
            .append(self.punct(":"))
            .append(self.space())
            .append(mode_doc);

        if let Some(cls) = class_doc {
            cls.append(self.space()).append(base)
        } else {
            base
        }
    }

    fn format_interface_file_declaration(&self, decl: &InterfaceFileDeclaration) -> Doc<'a> {
        let idents_doc = self.intersperse(
            decl.idents.iter().map(|id| self.ident(&id.tree.item.name_utf8())),
            self.arena.text(", "), // DocAllocator in scope
        );
        self.kw("file")
            .append(self.space())
            .append(idents_doc)
            .append(self.punct(":"))
            .append(self.space())
            .append(self.format_subtype_indication(&decl.subtype_indication))
    }

    fn format_interface_subprogram_declaration(
        &self,
        decl: &InterfaceSubprogramDeclaration,
    ) -> Doc<'a> {
        let spec = self.format_subprogram_specification(&decl.specification);
        if let Some(default) = &decl.default {
            let default_doc = match default {
                SubprogramDefault::Name(name) => self.format_name(&name.item),
                SubprogramDefault::Box => self.punct("<>"),
            };
            spec.append(self.space())
                .append(self.kw("is"))
                .append(self.space())
                .append(default_doc)
        } else {
            spec
        }
    }

    fn format_interface_package_declaration(&self, pkg: &InterfacePackageDeclaration) -> Doc<'a> {
        let name = self.ident(&pkg.ident.tree.item.name_utf8());
        let pkg_name = self.format_name(&pkg.package_name.item);
        let generic_map = match &pkg.generic_map.item {
            InterfacePackageGenericMapAspect::Map(list) => self
                .kw("generic")
                .append(self.space())
                .append(self.kw("map"))
                .append(self.space())
                .append(self.format_association_list_parens(list)),
            InterfacePackageGenericMapAspect::Box => self
                .kw("generic")
                .append(self.space())
                .append(self.kw("map"))
                .append(self.space())
                .append(self.punct("(<>)")),
            InterfacePackageGenericMapAspect::Default => self
                .kw("generic")
                .append(self.space())
                .append(self.kw("map"))
                .append(self.space())
                .append(self.punct("("))
                .append(self.kw("default"))
                .append(self.punct(")")),
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
            .append(self.space())
            .append(generic_map)
    }

    // -------------------------------------------------------------------------
    // Mode indications
    // -------------------------------------------------------------------------

    pub fn format_mode_indication(&self, mode: &ModeIndication) -> Doc<'a> {
        match mode {
            ModeIndication::Simple(s) => self.format_simple_mode_indication(s),
            ModeIndication::View(v) => self.format_mode_view_indication(v),
        }
    }

    fn format_simple_mode_indication(&self, mode: &SimpleModeIndication) -> Doc<'a> {
        let mode_doc =
            mode.mode.as_ref().map(|m| self.kw(Self::mode_str(m.item)).append(self.space()));
        let subtype = self.format_subtype_indication(&mode.subtype_indication);
        let default = if let Some(expr) = &mode.expression {
            self.space()
                .append(self.punct(":="))
                .append(self.space())
                .append(self.format_expression(expr.as_ref()))
        } else {
            self.nil()
        };

        let base = subtype.append(default);
        if let Some(m) = mode_doc { m.append(base) } else { base }
    }

    fn format_mode_view_indication(&self, mode: &ModeViewIndication) -> Doc<'a> {
        let name_doc = self.format_name(&mode.name.item);
        let name_wrapped = match &mode.kind {
            ModeViewIndicationKind::Array => {
                self.punct("(").append(name_doc).append(self.punct(")"))
            }
            ModeViewIndicationKind::Record => name_doc,
        };
        let subtype = if let Some((_tok, subtype)) = &mode.subtype_indication {
            self.space()
                .append(self.kw("of"))
                .append(self.space())
                .append(self.format_subtype_indication(subtype))
        } else {
            self.nil()
        };
        self.kw("view").append(self.space()).append(name_wrapped).append(subtype)
    }

    pub fn format_mode_view_element(&self, elem: &ModeViewElement) -> Doc<'a> {
        use vhdl_lang::ast::ElementMode;
        // Identifier list  (e.g. `a, b, c`)
        let idents_doc = self.intersperse(
            elem.names.iter().map(|id| self.ident(&id.tree.item.name_utf8())),
            self.arena.text(", "), // DocAllocator in scope
        );
        let mode_doc = match &elem.mode {
            ElementMode::Simple(m) => self.kw(Self::mode_str(m.item)),
            ElementMode::Record(name) => {
                self.kw("view").append(self.space()).append(self.format_name(&name.item))
            }
            ElementMode::Array(name) => self
                .kw("view")
                .append(self.space())
                .append(self.punct("("))
                .append(self.format_name(&name.item))
                .append(self.punct(")")),
        };
        idents_doc
            .append(self.punct(":"))
            .append(self.space())
            .append(mode_doc)
            .append(self.punct(";"))
    }

    // -------------------------------------------------------------------------
    // Map aspects (generic map / port map)
    // -------------------------------------------------------------------------

    /// Format `generic map ( … )` or `port map ( … )`.
    pub fn format_named_map_aspect(&self, keyword: &'static str, aspect: &MapAspect) -> Doc<'a> {
        self.kw(keyword)
            .append(self.space())
            .append(self.kw("map"))
            .append(self.space())
            .append(self.format_map_association_list_parens(&aspect.list))
    }
}
