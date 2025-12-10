#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <optional>
#include <string>
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
      .collectFrom(
        &ast::Architecture::decls,
        ctx.architecture_declarative_part(),
        [](auto &dp) { return dp.block_declarative_item(); },
        [this](auto *item) { return makeArchitectureDeclarativeItem(*item); })
      .collectFrom(
        &ast::Architecture::stmts,
        ctx.architecture_statement_part(),
        [](auto &sp) { return sp.architecture_statement(); },
        [this](auto *stmt) { return makeArchitectureStatement(*stmt); })
      .build();
}

auto Translator::makeArchitectureDeclarativeItem(vhdlParser::Block_declarative_itemContext &ctx)
  -> ast::Declaration
{
    if (auto *const_ctx = ctx.constant_declaration()) {
        return makeConstantDecl(*const_ctx);
    }
    if (auto *sig_ctx = ctx.signal_declaration()) {
        return makeSignalDecl(*sig_ctx);
    }
    if (auto *type_ctx = ctx.type_declaration()) {
        return makeTypeDecl(*type_ctx);
    }
    if (auto *comp_ctx = ctx.component_declaration()) {
        return makeComponentDecl(*comp_ctx);
    }
    if (auto *var_ctx = ctx.variable_declaration()) {
        return makeVariableDecl(*var_ctx);
    }
    // TODO(vedivad): Add subprogram_declaration, subprogram_body, file_declaration,
    // alias_declaration, etc.

    return {};
}

auto Translator::makeArchitectureStatement(vhdlParser::Architecture_statementContext &ctx)
  -> ast::ConcurrentStatement
{
    if (auto *proc = ctx.process_statement()) {
        return makeProcess(*proc);
    }

    if (auto *sig_assign = ctx.concurrent_signal_assignment_statement()) {
        auto *label = ctx.label_colon();
        std::optional<std::string> label_str;
        if ((label != nullptr) && (label->identifier() != nullptr)) {
            label_str = label->identifier()->getText();
        }

        return makeConcurrentAssign(*sig_assign, label_str);
    }

    // TODO(vedivad): Add component_instantiation, generate_statement, etc.

    return {};
}

} // namespace builder
