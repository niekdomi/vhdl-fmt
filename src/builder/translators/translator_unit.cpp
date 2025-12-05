#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "nodes/declarations.hpp"
#include "nodes/statements.hpp"
#include "vhdlParser.h"

#include <vector>

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
                dest.units.emplace_back(makeEntity(*entity_ctx));
            }
            // TODO(someone): Handle configuration_declaration and package_declaration
        }
        // Check secondary units (architecture_body | package_body)
        else if (auto *secondary = lib_unit->secondary_unit()) {
            if (auto *arch_ctx = secondary->architecture_body()) {
                dest.units.emplace_back(makeArchitecture(*arch_ctx));
            }
            // TODO(someone): Handle package_body
        }
    }
}

// ---------------------- Design units ----------------------

auto Translator::makeEntity(vhdlParser::Entity_declarationContext &ctx) -> ast::Entity
{
    auto *header = ctx.entity_header();

    return build<ast::Entity>(ctx)
      .set(&ast::Entity::name, ctx.identifier(0)->getText())
      .set(&ast::Entity::has_end_entity_keyword, ctx.ENTITY().size() > 1)
      .maybe(&ast::Entity::end_label, ctx.identifier(1), [](auto &id) { return id.getText(); })
      .maybe(&ast::Entity::generic_clause,
             (header != nullptr) ? header->generic_clause() : nullptr,
             [&](auto &gc) { return makeGenericClause(gc); })
      .maybe(&ast::Entity::port_clause,
             (header != nullptr) ? header->port_clause() : nullptr,
             [&](auto &pc) { return makePortClause(pc); })
      .build();
}

auto Translator::makeArchitecture(vhdlParser::Architecture_bodyContext &ctx) -> ast::Architecture
{
    return build<ast::Architecture>(ctx)
      .set(&ast::Architecture::name, ctx.identifier(0)->getText())
      .set(&ast::Architecture::entity_name, ctx.identifier(1)->getText())
      .set(&ast::Architecture::has_end_architecture_keyword, ctx.ARCHITECTURE().size() > 1)
      .maybe(
        &ast::Architecture::end_label, ctx.identifier(2), [](auto &id) { return id.getText(); })
      .maybe(&ast::Architecture::decls,
             ctx.architecture_declarative_part(),
             [&](auto &dp) { return makeArchitectureDeclarativePart(dp); })
      .maybe(&ast::Architecture::stmts,
             ctx.architecture_statement_part(),
             [&](auto &sp) { return makeArchitectureStatementPart(sp); })
      .build();
}

auto Translator::makeArchitectureDeclarativePart(
  vhdlParser::Architecture_declarative_partContext &ctx) -> std::vector<ast::Declaration>
{
    std::vector<ast::Declaration> decls{};

    for (auto *item : ctx.block_declarative_item()) {
        if (auto *const_ctx = item->constant_declaration()) {
            decls.emplace_back(makeConstantDecl(*const_ctx));
        } else if (auto *sig_ctx = item->signal_declaration()) {
            decls.emplace_back(makeSignalDecl(*sig_ctx));
        }
        // TODO(someone): Add more declaration types as needed (variables, types, subprograms,
        // etc.)
    }

    return decls;
}

auto Translator::makeArchitectureStatementPart(vhdlParser::Architecture_statement_partContext &ctx)
  -> std::vector<ast::ConcurrentStatement>
{
    std::vector<ast::ConcurrentStatement> stmts{};

    for (auto *stmt : ctx.architecture_statement()) {
        if (auto *proc = stmt->process_statement()) {
            stmts.emplace_back(makeProcess(*proc));
        } else if (auto *sig_assign = stmt->concurrent_signal_assignment_statement()) {
            stmts.emplace_back(makeConcurrentAssign(*sig_assign));
        }
        // TODO(someone): Add more concurrent statement types (component instantiation,
        // generate, etc.)
    }

    return stmts;
}

} // namespace builder
