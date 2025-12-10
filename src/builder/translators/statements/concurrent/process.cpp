#include "ast/nodes/declarations.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeProcess(vhdlParser::Process_statementContext &ctx) -> ast::Process
{
    auto *label = ctx.label_colon();
    auto *label_id = (label != nullptr) ? label->identifier() : nullptr;

    return build<ast::Process>(ctx)
      .maybe(&ast::Process::label, label_id, [](auto &id) { return id.getText(); })
      .collectFrom(
        &ast::Process::sensitivity_list,
        ctx.sensitivity_list(),
        [](auto &sl) { return sl.name(); },
        [](auto *name) { return name->getText(); })
      .collectFrom(
        &ast::Process::decls,
        ctx.process_declarative_part(),
        [](auto &dp) { return dp.process_declarative_item(); },
        [this](auto *item) { return makeProcessDeclarativeItem(*item); })
      .collectFrom(
        &ast::Process::body,
        ctx.process_statement_part(),
        [](auto &part) { return part.sequential_statement(); },
        [this](auto *stmt) { return makeSequentialStatement(*stmt); })
      .build();
}

auto Translator::makeProcessDeclarativeItem(vhdlParser::Process_declarative_itemContext &ctx)
  -> ast::Declaration
{
    if (auto *var_ctx = ctx.variable_declaration()) {
        return makeVariableDecl(*var_ctx);
    }

    if (auto *const_ctx = ctx.constant_declaration()) {
        return makeConstantDecl(*const_ctx);
    }

    if (auto *type_ctx = ctx.type_declaration()) {
        return makeTypeDecl(*type_ctx);
    }

    if (auto *file_ctx = ctx.file_declaration()) {
        // TODO(vedivad): Implement makeFileDecl
        // return makeFileDecl(*file_ctx);
    }

    if (auto *alias_ctx = ctx.alias_declaration()) {
        // TODO(vedivad): Implement makeAliasDecl
        // return makeAliasDecl(*alias_ctx);
    }

    return {};
}

} // namespace builder
