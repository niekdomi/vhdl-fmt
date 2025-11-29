#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

// ---------------------- Top-level ----------------------

void Translator::buildDesignFile(ast::DesignFile &dest, vhdlParser::Design_fileContext *ctx)
{
    for (auto *unit_ctx : ctx->design_unit()) {
        auto *lib_unit = unit_ctx->library_unit();
        if (lib_unit == nullptr) {
            continue;
        }

        // Check primary units (entity_declaration | configuration_declaration |
        // package_declaration)
        if (auto *primary = lib_unit->primary_unit()) {
            if (auto *entity_ctx = primary->entity_declaration()) {
                dest.units.emplace_back(makeEntity(entity_ctx));
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
    auto entity = make<ast::Entity>(ctx);

    entity.name = ctx->identifier(0)->getText();

    // Check for 'entity' keyword in END statement
    if (ctx->ENTITY().size() > 1) {
        entity.has_end_entity_keyword = true;
    }

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
    auto arch = make<ast::Architecture>(ctx);

    arch.name = ctx->identifier(0)->getText();
    arch.entity_name = ctx->identifier(1)->getText();

    // Check for 'architecture' keyword in END statement
    if (ctx->ARCHITECTURE().size() > 1) {
        arch.has_end_architecture_keyword = true;
    }

    // Optional end label (ARCHITECTURE ... END ARCHITECTURE <id>)
    if (ctx->identifier().size() > 2) {
        arch.end_label = ctx->identifier(2)->getText();
    }

    // Walk declarative part and collect declarations directly
    if (auto *decl_part = ctx->architecture_declarative_part()) {
        for (auto *item : decl_part->block_declarative_item()) {
            if (auto *const_ctx = item->constant_declaration()) {
                arch.decls.emplace_back(makeConstantDecl(const_ctx));
            } else if (auto *sig_ctx = item->signal_declaration()) {
                arch.decls.emplace_back(makeSignalDecl(sig_ctx));
            }
            // TODO(someone): Add more declaration types as needed (variables, types, subprograms,
            // etc.)
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

} // namespace builder
