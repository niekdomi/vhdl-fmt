#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <string>
#include <utility>
#include <vector>

namespace builder {

auto Translator::makeContextClause(vhdlParser::Context_clauseContext &ctx)
  -> std::vector<ast::ContextItem>
{
    std::vector<ast::ContextItem> items{};

    for (auto *item_ctx : ctx.context_item()) {
        if (auto *lib_ctx = item_ctx->library_clause()) {
            items.emplace_back(makeLibraryClause(*lib_ctx));
        } else if (auto *use_ctx = item_ctx->use_clause()) {
            items.emplace_back(makeUseClause(*use_ctx));
        }
    }

    return items;
}

auto Translator::makeLibraryClause(vhdlParser::Library_clauseContext &ctx) -> ast::LibraryClause
{
    std::vector<std::string> names{};

    if (auto *name_list = ctx.logical_name_list()) {
        for (auto *name_ctx : name_list->logical_name()) {
            names.push_back(name_ctx->getText());
        }
    }

    return build<ast::LibraryClause>(ctx)
      .set(&ast::LibraryClause::logical_names, std::move(names))
      .build();
}

auto Translator::makeUseClause(vhdlParser::Use_clauseContext &ctx) -> ast::UseClause
{
    std::vector<std::string> names{};

    for (auto *name_ctx : ctx.selected_name()) {
        names.push_back(name_ctx->getText());
    }

    return build<ast::UseClause>(ctx)
      .set(&ast::UseClause::selected_names, std::move(names))
      .build();
}

} // namespace builder
