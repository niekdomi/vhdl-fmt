#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <algorithm>
#include <ranges>
#include <string>
#include <utility>

namespace builder {

auto Translator::makeName(vhdlParser::NameContext& ctx) -> ast::Expr
{
    const auto parts = ctx.name_part();

    // 1. Find split point
    const auto split_it =
      std::ranges::find_if(parts, [](auto* p) { return p->selected_name_part() == nullptr; });

    // 2. Build Base Name
    std::string text{};
    if (auto* id = ctx.identifier()) {
        text = id->getText();
    } else if (auto* lit = ctx.STRING_LITERAL()) {
        text = lit->getText();
    } else {
        return makeToken(ctx);
    }

    for (auto* part : std::ranges::subrange(parts.begin(), split_it)) {
        text += part->getText();
    }

    ast::Expr base = makeToken(ctx, std::move(text));

    // 3. Fold Structure
    for (auto* part : std::ranges::subrange(split_it, parts.end())) {
        if (auto* s = part->slice_name_part()) {
            base = makeSliceExpr(std::move(base), *s);
        } else if (auto* c = part->function_call_or_indexed_name_part()) {
            base = makeCallExpr(std::move(base), *c);
        } else if (auto* a = part->attribute_name_part()) {
            base = makeAttributeExpr(std::move(base), *a);
        }
    }

    return base;
}

} // namespace builder
