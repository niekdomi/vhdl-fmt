#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

// ---------------------- Top-level ----------------------

void Translator::buildDesignFile(ast::DesignFile &dest, vhdlParser::Design_fileContext &ctx)
{
    for (auto *unit_ctx : ctx.design_unit()) {
        if (auto *ctx_clause = unit_ctx->context_clause()) {
            auto context_clause = makeContextClause(ctx_clause);
        }

        auto *lib_unit = unit_ctx->library_unit();
        if (lib_unit == nullptr) {
            continue;
        }

        // Check primary units (entity_declaration | configuration_declaration |
        // package_declaration | context_declaration)
        if (auto *primary = lib_unit->primary_unit()) {
            if (auto *entity_ctx = primary->entity_declaration()) {
                dest.units.emplace_back(makeEntity(entity_ctx));
            } else if (auto *context_ctx = primary->context_declaration()) {
                dest.units.emplace_back(makeContextDeclaration(context_ctx));
            }
            // TODO(someone): Handle configuration_declaration and package_declaration
        }
        // Check secondary units (architecture_body | package_body)
        else if (auto *secondary = lib_unit->secondary_unit()) {
            if (auto *arch_ctx = secondary->architecture_body()) {
                dest.units.emplace_back(makeArchitecture(arch_ctx));
            }
            // TODO(someone): Handle package_body
        }
    }
}

// ---------------------- Design units ----------------------

auto Translator::makeEntity(vhdlParser::Entity_declarationContext *ctx) -> ast::Entity
{
    if (ctx == nullptr) {
        return {};
    }

    auto entity = make<ast::Entity>(ctx);

    entity.name = ctx->identifier(0)->getText();

    // Optional end label (ENTITY ... END ENTITY <id>)
    if (ctx->identifier().size() > 1) {
        entity.end_label = ctx->identifier(1)->getText();
    }

    if (auto *header = ctx->entity_header()) {
        if (auto *gen_clause = header->generic_clause()) {
            entity.generic_clause = makeGenericClause(gen_clause);
        }
        if (auto *port_clause = header->port_clause()) {
            entity.port_clause = makePortClause(port_clause);
        }
    }

    return entity;
}

auto Translator::makeArchitecture(vhdlParser::Architecture_bodyContext *ctx) -> ast::Architecture
{
    if (ctx == nullptr) {
        return {};
    }

    auto arch = make<ast::Architecture>(ctx);

    arch.name = ctx->identifier(0)->getText();
    arch.entity_name = ctx->identifier(1)->getText();

    // Walk declarative part and collect declarations directly
    if (auto *decl_part = ctx->architecture_declarative_part()) {
        for (auto *item : decl_part->block_declarative_item()) {
            if (auto *const_ctx = item->constant_declaration()) {
                arch.decls.emplace_back(makeConstantDecl(const_ctx));
            } else if (auto *sig_ctx = item->signal_declaration()) {
                arch.decls.emplace_back(makeSignalDecl(sig_ctx));
            } else if (auto *alias_ctx = item->alias_declaration()) {
                arch.decls.emplace_back(makeAliasDecl(alias_ctx));
            } else if (auto *type_ctx = item->type_declaration()) {
                arch.decls.emplace_back(makeTypeDecl(type_ctx));
            } else if (auto *subtype_ctx = item->subtype_declaration()) {
                arch.decls.emplace_back(makeSubtypeDecl(subtype_ctx));
            } else if (auto *subprog_decl = item->subprogram_declaration()) {
                if (auto decl = makeSubprogramDeclaration(subprog_decl)) {
                    arch.decls.emplace_back(std::move(*decl));
                }
            } else if (auto *subprog_body = item->subprogram_body()) {
                if (auto decl = makeSubprogramBody(subprog_body)) {
                    arch.decls.emplace_back(std::move(*decl));
                }
            }
            // TODO(someone): Add more declaration types as needed (variables, subprograms, etc.)
        }
    }

    // Walk statement part and collect concurrent statements
    if (auto *stmt_part = ctx->architecture_statement_part()) {
        for (auto *stmt : stmt_part->architecture_statement()) {
            if (auto *proc = stmt->process_statement()) {
                arch.stmts.emplace_back(makeProcess(proc));
            } else if (auto *sig_assign = stmt->concurrent_signal_assignment_statement()) {
                arch.stmts.emplace_back(makeConcurrentAssign(sig_assign));
            }
            // TODO(someone): Add more concurrent statement types (component instantiation,
            // generate, etc.)
        }
    }

    return arch;
}

auto Translator::makeContextDeclaration(vhdlParser::Context_declarationContext *ctx)
  -> ast::ContextDeclaration
{
    if (ctx == nullptr) {
        return {};
    }

    auto context_decl = make<ast::ContextDeclaration>(ctx);

    // Get the context name (first identifier)
    context_decl.name = ctx->identifier(0)->getText();

    // Parse the context clause to get library/use clauses
    if (auto *ctx_clause = ctx->context_clause()) {
        context_decl.items = makeContextClause(ctx_clause);
    }

    return context_decl;
}

// ---------------------- Alias, Type, Subtype Declarations ----------------------

auto Translator::makeAliasDecl(vhdlParser::Alias_declarationContext *ctx) -> ast::AliasDecl
{
    if (ctx == nullptr) {
        return {};
    }

    auto alias_decl = make<ast::AliasDecl>(ctx);

    // Get alias name
    if (auto *designator = ctx->alias_designator()) {
        if (auto *id = designator->identifier()) {
            alias_decl.name = id->getText();
        }
    }

    // Get type indication if present
    if (auto *indication = ctx->alias_indication()) {
        if (auto *subtype_ind = indication->subtype_indication()) {
            const auto &selected = subtype_ind->selected_name();
            if (!selected.empty() && selected[0] != nullptr) {
                alias_decl.type_name = selected[0]->getText();
            }
        }

        if (alias_decl.type_name.empty()) {
            auto type_text = indication->getText();
            const auto paren_pos = type_text.find_first_of("( ");
            if (paren_pos != std::string::npos) {
                alias_decl.type_name = type_text.substr(0, paren_pos);
            } else {
                alias_decl.type_name = std::move(type_text);
            }
        }
    }

    // Get the aliased target (the name after 'is')
    if (auto *name = ctx->name()) {
        alias_decl.target = makeName(name);
    }

    return alias_decl;
}

auto Translator::makeTypeDecl(vhdlParser::Type_declarationContext *ctx) -> ast::TypeDecl
{
    if (ctx == nullptr) {
        return {};
    }

    auto type_decl = make<ast::TypeDecl>(ctx);

    // Get type name
    if (auto *id = ctx->identifier()) {
        type_decl.name = id->getText();
    }

    // Get type definition - store as optional Expr for now
    // Could be enumeration, array, record, etc.
    if (auto *def = ctx->type_definition()) {
        // For now, just store the text representation
        // TODO(domi): Parse specific type definitions if needed
        type_decl.definition = makeToken(ctx, def->getText());
    }

    return type_decl;
}

auto Translator::makeSubtypeDecl(vhdlParser::Subtype_declarationContext *ctx) -> ast::SubtypeDecl
{
    if (ctx == nullptr) {
        return {};
    }

    auto subtype_decl = make<ast::SubtypeDecl>(ctx);

    // Get subtype name
    if (auto *id = ctx->identifier()) {
        subtype_decl.name = id->getText();
    }

    // Get subtype indication (base type and constraint)
    if (auto *subtype_ind = ctx->subtype_indication()) {
        // Get base type name
        if (!subtype_ind->selected_name().empty()) {
            subtype_decl.base_type = subtype_ind->selected_name(0)->getText();
        }

        // Get constraint if present
        if (auto *constraint = subtype_ind->constraint()) {
            subtype_decl.constraint = makeConstraint(constraint);
        }
    }

    return subtype_decl;
}

// ---------------------- Context Clauses ----------------------

auto Translator::makeContextClause(vhdlParser::Context_clauseContext *ctx)
  -> std::vector<ast::ContextItem>
{
    std::vector<ast::ContextItem> items;

    if (ctx == nullptr) {
        return items;
    }

    // Iterate through all context items in the clause
    for (auto *item_ctx : ctx->context_item()) {
        if (item_ctx != nullptr) {
            items.push_back(makeContextItem(item_ctx));
        }
    }

    return items;
}

auto Translator::makeContextItem(vhdlParser::Context_itemContext *ctx) -> ast::ContextItem
{
    if (ctx == nullptr) {
        return ast::LibraryClause{};
    }

    if (auto *lib_clause = ctx->library_clause()) {
        return makeLibraryClause(lib_clause);
    }

    if (auto *use_clause = ctx->use_clause()) {
        return makeUseClause(use_clause);
    }

    // Fallback - should not reach here with valid grammar
    return ast::LibraryClause{};
}

auto Translator::makeLibraryClause(vhdlParser::Library_clauseContext *ctx) -> ast::LibraryClause
{
    if (ctx == nullptr) {
        return {};
    }

    auto clause = make<ast::LibraryClause>(ctx);

    // Extract all library logical names
    for (auto *logical_name : ctx->logical_name_list()->logical_name()) {
        if (logical_name != nullptr) {
            clause.logical_names.push_back(logical_name->getText());
        }
    }

    return clause;
}

auto Translator::makeUseClause(vhdlParser::Use_clauseContext *ctx) -> ast::UseClause
{
    if (ctx == nullptr) {
        return {};
    }

    auto clause = make<ast::UseClause>(ctx);

    // Extract all selected names
    for (auto *selected_name : ctx->selected_name()) {
        if (selected_name != nullptr) {
            clause.selected_names.push_back(selected_name->getText());
        }
    }

    return clause;
}

} // namespace builder
