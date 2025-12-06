#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <algorithm>
#include <iterator>
#include <memory>
#include <ranges>
#include <string>
#include <utility>

namespace builder {

auto Translator::makeName(vhdlParser::NameContext &ctx) -> ast::Expr
{
    const auto &parts = ctx.name_part();
    // For formatting: check if we have any structural parts (calls, slices, attributes)
    // If not, just keep the whole name as a single token
    const auto has_structure = std::ranges::any_of(parts, [](auto *part) {
        return part->function_call_or_indexed_name_part()
            != nullptr
            || part->slice_name_part()
            != nullptr
            || part->attribute_name_part()
            != nullptr;
    });

    if (!has_structure) {
        // Simple name (possibly with dots like "rec.field") - keep as one token
        return makeToken(ctx);
    }

    // Has structural parts - build up the base, then apply operations
    // Start with the identifier/literal and consume any leading dot selections
    std::string base_text;
    if (ctx.identifier() != nullptr) {
        base_text = ctx.identifier()->getText();
    } else if (ctx.STRING_LITERAL() != nullptr) {
        base_text = ctx.STRING_LITERAL()->getText();
    } else {
        // Shouldn't happen, but fallback
        return makeToken(ctx);
    }

    // Consume consecutive selected_name_parts into base
    const auto selected_parts
      = parts | std::views::take_while([](auto *p) { return p->selected_name_part() != nullptr; });

    for (auto *part : selected_parts) {
        base_text += part->getText();
    }

    ast::Expr base = makeToken(ctx, std::move(base_text));

    const auto structural_parts = parts | std::views::drop(std::ranges::distance(selected_parts));

    // Process remaining structural parts
    for (auto *part : structural_parts) {
        if (auto *slice = part->slice_name_part()) {
            base = makeSliceExpr(std::move(base), *slice);
        } else if (auto *call = part->function_call_or_indexed_name_part()) {
            base = makeCallExpr(std::move(base), *call);
        } else if (auto *attr = part->attribute_name_part()) {
            base = makeAttributeExpr(std::move(base), *attr);
        }
        // Ignore any remaining selected_name_parts (shouldn't happen after structure)
    }

    return base;
}

auto Translator::makeSliceExpr(ast::Expr base, vhdlParser::Slice_name_partContext &ctx) -> ast::Expr
{
    return build<ast::CallExpr>(ctx)
      .setBox(&ast::CallExpr::callee, std::move(base))
      .maybeBox(
        &ast::CallExpr::args, ctx.discrete_range(), [&](auto &dr) { return makeDiscreteRange(dr); })
      .build();
}

auto Translator::makeCallExpr(ast::Expr base,
                              vhdlParser::Function_call_or_indexed_name_partContext &ctx)
  -> ast::Expr
{
    auto *assoc_list = ctx.actual_parameter_part();
    auto *list_ctx = (assoc_list != nullptr) ? assoc_list->association_list() : nullptr;
    auto associations = (list_ctx != nullptr) ? list_ctx->association_element()
                                              : decltype(list_ctx->association_element()){};

    return build<ast::CallExpr>(ctx)
      .setBox(&ast::CallExpr::callee, std::move(base))
      .apply([&](auto &node) {
          if (assoc_list == nullptr) {
              return;
          }

          if (list_ctx == nullptr) {
              node.args = std::make_unique<ast::Expr>(makeToken(ctx));
              return;
          }

          if (associations.size() == 1) {
              node.args = std::make_unique<ast::Expr>(makeCallArgument(*associations[0]));
          } else {
              node.args = std::make_unique<ast::Expr>(
                build<ast::GroupExpr>(*list_ctx)
                  .collect(&ast::GroupExpr::children,
                           associations,
                           [&](auto *elem) { return makeCallArgument(*elem); })
                  .build());
          }
      })
      .build();
}

auto Translator::makeAttributeExpr(ast::Expr base, vhdlParser::Attribute_name_partContext &ctx)
  -> ast::Expr
{
    // Extract attribute name (everything after the apostrophe)
    const std::string full_text = ctx.getText();
    const std::string attr_text = full_text.substr(1); // Skip leading apostrophe

    // Check if there's a parenthesized expression (attribute with parameter)
    auto *param_expr = ctx.expression();

    // Find where the attribute name ends (before the paren if it exists)
    std::string attr_name = attr_text;
    if (param_expr != nullptr) {
        // Remove the parameter part from attribute name
        const auto paren_pos = attr_text.find('(');
        if (paren_pos != std::string::npos) {
            attr_name = attr_text.substr(0, paren_pos);
        }
    }

    return build<ast::AttributeExpr>(ctx)
      .setBox(&ast::AttributeExpr::prefix, std::move(base))
      .set(&ast::AttributeExpr::attribute, std::move(attr_name))
      .maybe(&ast::AttributeExpr::arg,
             param_expr,
             [&](auto &expr) { return std::make_unique<ast::Expr>(makeExpr(expr)); })
      .build();
}

auto Translator::makeCallArgument(vhdlParser::Association_elementContext &ctx) -> ast::Expr
{
    auto *actual = ctx.actual_part();
    auto *designator = (actual != nullptr) ? actual->actual_designator() : nullptr;
    auto *expr = (designator != nullptr) ? designator->expression() : nullptr;

    if (expr != nullptr) {
        return makeExpr(*expr);
    }

    return makeToken(ctx);
}

} // namespace builder
