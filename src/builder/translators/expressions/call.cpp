#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>

namespace builder {

auto Translator::makeCallExpr(ast::Expr base,
                              vhdlParser::Function_call_or_indexed_name_partContext &ctx)
  -> ast::Expr
{
    auto *param_part = ctx.actual_parameter_part();
    auto *assoc_list = (param_part != nullptr) ? param_part->association_list() : nullptr;

    ast::GroupExpr group{};

    if (assoc_list != nullptr) {
        group.children = assoc_list->association_element()
                       | std::views::transform([&](auto *elem) { return makeCallArgument(*elem); })
                       | std::ranges::to<decltype(group.children)>();
    }

    return build<ast::CallExpr>(ctx)
      .setBox(&ast::CallExpr::callee, std::move(base))
      .setBox(&ast::CallExpr::args, std::move(group))
      .build();
}

auto Translator::makeCallArgument(vhdlParser::Association_elementContext &ctx) -> ast::Expr
{
    auto *actual = ctx.actual_part();
    if (actual == nullptr) {
        return makeToken(ctx);
    }

    // Resolve the inner content of the actual part
    ast::Expr content = [&]() -> ast::Expr {
        auto *designator = actual->actual_designator();

        // If designator is missing, fallback immediately
        if (designator == nullptr) {
            return makeToken(*actual);
        }

        // Check for expression
        if (auto *expr = designator->expression()) {
            return makeExpr(*expr);
        }

        // Fallback: It must be the 'OPEN' keyword
        return makeToken(*designator);
    }();

    // 2. Check for function call / type conversion syntax: name(actual_designator)
    if (auto *name_ctx = actual->name()) {
        ast::GroupExpr args{};
        args.children.emplace_back(std::move(content));

        return build<ast::CallExpr>(*actual)
          .setBox(&ast::CallExpr::callee, makeName(*name_ctx))
          .setBox(&ast::CallExpr::args, std::move(args))
          .build();
    }

    return content;
}

} // namespace builder
