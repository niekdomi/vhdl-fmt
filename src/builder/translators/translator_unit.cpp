#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "nodes/declarations.hpp"
#include "nodes/statements.hpp"
#include "vhdlParser.h"

#include <optional>
#include <string>
#include <utility>
#include <vector>

namespace builder {

// ---------------------- Top-level ----------------------

auto Translator::buildDesignFile(ast::DesignFile& dest, vhdlParser::Design_fileContext* ctx) -> void
{
    for (auto* unit_ctx : ctx->design_unit()) {
        auto* lib_unit = unit_ctx->library_unit();
        if (lib_unit == nullptr) {
            continue;
        }

        // Parse context clause (library and use clauses)
        std::vector<ast::ContextItem> context{};
        if (auto* context_ctx = unit_ctx->context_clause()) {
            context = makeContextClause(*context_ctx);
        }

        // Check primary units (entity_declaration | configuration_declaration |
        // package_declaration)
        if (auto* primary = lib_unit->primary_unit()) {
            if (auto* entity_ctx = primary->entity_declaration()) {
                auto entity = makeEntity(*entity_ctx);
                entity.context = std::move(context);
                dest.units.emplace_back(std::move(entity));
            }
            // TODO(someone): Handle configuration_declaration and package_declaration
        }
        // Check secondary units (architecture_body | package_body)
        else if (auto* secondary = lib_unit->secondary_unit())
        {
            if (auto* arch_ctx = secondary->architecture_body()) {
                auto arch = makeArchitecture(*arch_ctx);
                arch.context = std::move(context);
                dest.units.emplace_back(std::move(arch));
            }
            // TODO(someone): Handle package_body
        }
    }
}

// ---------------------- Design units ----------------------

auto Translator::makeEntity(vhdlParser::Entity_declarationContext& ctx) -> ast::Entity
{
    auto* header = ctx.entity_header();

    return build<ast::Entity>(ctx)
      .set(&ast::Entity::name, ctx.identifier(0)->getText())
      .set(&ast::Entity::has_end_entity_keyword, ctx.ENTITY().size() > 1)
      .maybe(&ast::Entity::end_label, ctx.identifier(1), [](auto& id) { return id.getText(); })
      .maybe(&ast::Entity::generic_clause,
             (header != nullptr) ? header->generic_clause() : nullptr,
             [&](auto& gc) { return makeGenericClause(gc); })
      .maybe(&ast::Entity::port_clause,
             (header != nullptr) ? header->port_clause() : nullptr,
             [&](auto& pc) { return makePortClause(pc); })
      .build();
}

auto Translator::makeArchitecture(vhdlParser::Architecture_bodyContext& ctx) -> ast::Architecture
{
    return build<ast::Architecture>(ctx)
      .set(&ast::Architecture::name, ctx.identifier(0)->getText())
      .set(&ast::Architecture::entity_name, ctx.identifier(1)->getText())
      .set(&ast::Architecture::has_end_architecture_keyword, ctx.ARCHITECTURE().size() > 1)
      .maybe(
        &ast::Architecture::end_label, ctx.identifier(2), [](auto& id) { return id.getText(); })
      .maybe(&ast::Architecture::decls,
             ctx.architecture_declarative_part(),
             [&](auto& dp) { return makeArchitectureDeclarativePart(dp); })
      .maybe(&ast::Architecture::stmts,
             ctx.architecture_statement_part(),
             [&](auto& sp) { return makeArchitectureStatementPart(sp); })
      .build();
}

auto Translator::makeArchitectureDeclarativePart(
  vhdlParser::Architecture_declarative_partContext& ctx) -> std::vector<ast::Declaration>
{
    std::vector<ast::Declaration> items{};

    for (auto* item : ctx.block_declarative_item()) {
        if (auto* const_ctx = item->constant_declaration()) {
            items.emplace_back(makeConstantDecl(*const_ctx));
        } else if (auto* sig_ctx = item->signal_declaration()) {
            items.emplace_back(makeSignalDecl(*sig_ctx));
        } else if (auto* type_ctx = item->type_declaration()) {
            items.emplace_back(makeTypeDecl(*type_ctx));
        } else if (auto* comp_ctx = item->component_declaration()) {
            items.emplace_back(makeComponentDecl(*comp_ctx));
        } else if (auto* var_ctx = item->variable_declaration()) {
            items.emplace_back(makeVariableDecl(*var_ctx));
        }
        // TODO(vedivad): Add more declaration types as needed (subprograms, etc.)
    }

    return items;
}

auto Translator::makeArchitectureStatementPart(vhdlParser::Architecture_statement_partContext& ctx)
  -> std::vector<ast::ConcurrentStatement>
{
    std::vector<ast::ConcurrentStatement> stmts{};

    for (auto* stmt : ctx.architecture_statement()) {
        if (auto* proc = stmt->process_statement()) {
            stmts.emplace_back(makeProcess(*proc));
        } else if (auto* sig_assign = stmt->concurrent_signal_assignment_statement()) {
            // Extract label from architecture_statement level
            auto* label = stmt->label_colon();
            auto* label_id = (label != nullptr) ? label->identifier() : nullptr;
            std::optional<std::string> label_str;

            if (label_id != nullptr) {
                label_str = label_id->getText();
            }

            stmts.emplace_back(makeConcurrentAssign(*sig_assign, label_str));
        }
        // TODO(someone): Add more concurrent statement types (component instantiation,
        // generate, etc.)
    }

    return stmts;
}

// ---------------------- Context clauses ----------------------

auto Translator::makeContextClause(vhdlParser::Context_clauseContext& ctx)
  -> std::vector<ast::ContextItem>
{
    std::vector<ast::ContextItem> items{};

    for (auto* item_ctx : ctx.context_item()) {
        if (auto* lib_ctx = item_ctx->library_clause()) {
            items.emplace_back(makeLibraryClause(*lib_ctx));
        } else if (auto* use_ctx = item_ctx->use_clause()) {
            items.emplace_back(makeUseClause(*use_ctx));
        }
    }

    return items;
}

auto Translator::makeLibraryClause(vhdlParser::Library_clauseContext& ctx) -> ast::LibraryClause
{
    std::vector<std::string> names{};

    if (auto* name_list = ctx.logical_name_list()) {
        for (auto* name_ctx : name_list->logical_name()) {
            names.push_back(name_ctx->getText());
        }
    }

    return build<ast::LibraryClause>(ctx)
      .set(&ast::LibraryClause::logical_names, std::move(names))
      .build();
}

auto Translator::makeUseClause(vhdlParser::Use_clauseContext& ctx) -> ast::UseClause
{
    std::vector<std::string> names{};

    for (auto* name_ctx : ctx.selected_name()) {
        names.push_back(name_ctx->getText());
    }

    return build<ast::UseClause>(ctx)
      .set(&ast::UseClause::selected_names, std::move(names))
      .build();
}

} // namespace builder
