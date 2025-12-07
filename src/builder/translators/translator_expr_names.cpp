#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <algorithm>
#include <memory>
#include <ranges>
#include <string>
#include <utility>

namespace builder {

auto Translator::makeName(vhdlParser::NameContext &ctx) -> ast::Expr
{
    const auto parts = ctx.name_part();

    // 1. Find split point
    const auto split_it
      = std::ranges::find_if(parts, [](auto *p) { return p->selected_name_part() == nullptr; });

    // 2. Build Base Name
    std::string text{};
    if (auto *id = ctx.identifier()) {
        text = id->getText();
    } else if (auto *lit = ctx.STRING_LITERAL()) {
        text = lit->getText();
    } else {
        return makeToken(ctx);
    }

    for (auto *part : std::ranges::subrange(parts.begin(), split_it)) {
        text += part->getText();
    }

    ast::Expr base = makeToken(ctx, std::move(text));

    // 3. Fold Structure
    for (auto *part : std::ranges::subrange(split_it, parts.end())) {
        if (auto *s = part->slice_name_part()) {
            base = makeSliceExpr(std::move(base), *s);
        } else if (auto *c = part->function_call_or_indexed_name_part()) {
            base = makeCallExpr(std::move(base), *c);
        } else if (auto *a = part->attribute_name_part()) {
            base = makeAttributeExpr(std::move(base), *a);
        }
    }

    return base;
}

auto Translator::makeSliceExpr(ast::Expr base, vhdlParser::Slice_name_partContext &ctx) -> ast::Expr
{
    return build<ast::SliceExpr>(ctx)
      .setBox(&ast::SliceExpr::prefix, std::move(base))
      .maybeBox(&ast::SliceExpr::range,
                ctx.discrete_range(),
                [&](auto &dr) { return makeDiscreteRange(dr); })
      .build();
}

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

auto Translator::makeAttributeExpr(ast::Expr base, vhdlParser::Attribute_name_partContext &ctx)
  -> ast::Expr
{
    return build<ast::AttributeExpr>(ctx)
      .setBox(&ast::AttributeExpr::prefix, std::move(base))
      .set(&ast::AttributeExpr::attribute, ctx.attribute_designator()->getText())
      .maybe(&ast::AttributeExpr::arg,
             ctx.expression(), // Pass the pointer directly
             [&](auto &expr) { return std::make_unique<ast::Expr>(makeExpr(expr)); })
      .build();
}

auto Translator::makeCallArgument(vhdlParser::Association_elementContext &ctx) -> ast::Expr
{
    auto *actual = ctx.actual_part();
    if (actual == nullptr) {
        return makeToken(ctx);
    }

    // Resolve the inner content (Expression or OPEN token)
    // actual_designator is available in both grammar alternatives.
    auto *designator = actual->actual_designator();
    ast::Expr content{};

    if (designator != nullptr && designator->expression() != nullptr) {
        content = makeExpr(*designator->expression());
    } else if (designator != nullptr) {
        // Handle 'OPEN' keyword
        content = makeToken(*designator);
    } else {
        return makeToken(*actual);
    }

    // Check for function call / type conversion syntax: name(actual_designator)
    if (auto *name_ctx = actual->name()) {
        ast::GroupExpr args{};
        args.children.push_back(std::move(content));

        return build<ast::CallExpr>(*actual)
          .setBox(&ast::CallExpr::callee, makeName(*name_ctx))
          .setBox(&ast::CallExpr::args, std::move(args))
          .build();
    }

    // Otherwise, it is just the direct content
    return content;
}

} // namespace builder
