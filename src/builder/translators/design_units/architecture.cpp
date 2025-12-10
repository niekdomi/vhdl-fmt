#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <vector>

namespace builder {

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
    std::vector<ast::Declaration> items{};

    for (auto *item : ctx.block_declarative_item()) {
        if (auto *const_ctx = item->constant_declaration()) {
            items.emplace_back(makeConstantDecl(*const_ctx));
        } else if (auto *sig_ctx = item->signal_declaration()) {
            items.emplace_back(makeSignalDecl(*sig_ctx));
        } else if (auto *type_ctx = item->type_declaration()) {
            items.emplace_back(makeTypeDecl(*type_ctx));
        } else if (auto *comp_ctx = item->component_declaration()) {
            items.emplace_back(makeComponentDecl(*comp_ctx));
        } else if (auto *var_ctx = item->variable_declaration()) {
            items.emplace_back(makeVariableDecl(*var_ctx));
        }
        // TODO: Add more declaration types as needed
    }

    return items;
}

auto Translator::makeArchitectureStatementPart(vhdlParser::Architecture_statement_partContext &ctx)
  -> std::vector<ast::ConcurrentStatement>
{
    std::vector<ast::ConcurrentStatement> stmts{};

    for (auto *stmt : ctx.architecture_statement()) {
        if (auto *proc = stmt->process_statement()) {
            stmts.emplace_back(makeProcess(*proc));
        } else if (auto *sig_assign = stmt->concurrent_signal_assignment_statement()) {
            // Extract label from architecture_statement level
            auto *label = stmt->label_colon();
            auto *label_id = (label != nullptr) ? label->identifier() : nullptr;
            std::optional<std::string> label_str;

            if (label_id != nullptr) {
                label_str = label_id->getText();
            }

            stmts.emplace_back(makeConcurrentAssign(*sig_assign, label_str));
        }
        // TODO: Add more concurrent statement types
    }

    return stmts;
}

} // namespace builder
