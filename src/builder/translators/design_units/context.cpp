#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <stdexcept>

namespace builder {

auto Translator::makeContextItem(vhdlParser::Context_itemContext *ctx) -> ast::ContextItem
{
    // A context item is either a library clause or a use clause
    if (auto *lib_ctx = ctx->library_clause()) {
        return makeLibraryClause(*lib_ctx);
    }

    if (auto *use_ctx = ctx->use_clause()) {
        return makeUseClause(*use_ctx);
    }

    // Unreachable, just abort as loss is guaranteed
    throw std::runtime_error("Unknown context item type");
}

auto Translator::makeLibraryClause(vhdlParser::Library_clauseContext &ctx) -> ast::LibraryClause
{
    return build<ast::LibraryClause>(ctx)
      .collectFrom(
        &ast::LibraryClause::logical_names,
        ctx.logical_name_list(),
        [](auto &list) { return list.logical_name(); },
        [](auto *name_ctx) { return name_ctx->getText(); })
      .build();
}

auto Translator::makeUseClause(vhdlParser::Use_clauseContext &ctx) -> ast::UseClause
{
    return build<ast::UseClause>(ctx)
      .collect(&ast::UseClause::selected_names,
               ctx.selected_name(),
               [](auto *name_ctx) { return name_ctx->getText(); })
      .build();
}

} // namespace builder
