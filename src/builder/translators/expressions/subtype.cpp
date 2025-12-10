#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <optional>
#include <variant>

namespace builder {

auto Translator::makeConstraint(vhdlParser::ConstraintContext &ctx)
  -> std::optional<ast::Constraint>
{
    // Dispatch based on concrete constraint type
    if (auto *index = ctx.index_constraint()) {
        return makeIndexConstraint(*index);
    }

    if (auto *range = ctx.range_constraint()) {
        return makeRangeConstraint(*range);
    }

    // Fallback: return empty optional
    return std::nullopt;
}

auto Translator::makeIndexConstraint(vhdlParser::Index_constraintContext &ctx)
  -> ast::IndexConstraint
{
    return build<ast::IndexConstraint>(ctx)
      .set(&ast::IndexConstraint::ranges,
           build<ast::GroupExpr>(ctx)
             .collect(&ast::GroupExpr::children,
                      ctx.discrete_range(),
                      [&](auto *dr) { return makeDiscreteRange(*dr); })
             .build())
      .build();
}

auto Translator::makeRangeConstraint(vhdlParser::Range_constraintContext &ctx)
  -> std::optional<ast::RangeConstraint>
{
    auto *range_decl = ctx.range_decl();
    auto *explicit_r = (range_decl != nullptr) ? range_decl->explicit_range() : nullptr;
    if (explicit_r == nullptr) {
        return std::nullopt;
    }

    auto range_expr = makeRange(*explicit_r);
    auto *bin = std::get_if<ast::BinaryExpr>(&range_expr);
    if (bin == nullptr) {
        return std::nullopt;
    }

    return build<ast::RangeConstraint>(ctx)
      .set(&ast::RangeConstraint::range, std::move(*bin))
      .build();
}

auto Translator::makeRange(vhdlParser::Explicit_rangeContext &ctx) -> ast::Expr
{
    // If there's no direction, it's just a simple expression (single value, not a range)
    if (ctx.direction() == nullptr || ctx.simple_expression().size() < 2) {
        return makeSimpleExpr(*ctx.simple_expression(0));
    }

    return makeBinary(ctx,
                      ctx.direction()->getText(),
                      makeSimpleExpr(*ctx.simple_expression(0)),
                      makeSimpleExpr(*ctx.simple_expression(1)));
}

auto Translator::makeDiscreteRange(vhdlParser::Discrete_rangeContext &ctx) -> ast::Expr
{
    // discrete_range : range_decl | subtype_indication
    if (auto *rd = ctx.range_decl()) {
        if (auto *er = rd->explicit_range()) {
            return makeRange(*er);
        }
        return makeToken(*rd);
    }

    // subtype_indication (e.g., "integer range 0 to 7" or just "natural")
    return makeToken(ctx);
}

auto Translator::makeSubtypeIndication(vhdlParser::Subtype_indicationContext &ctx)
  -> ast::SubtypeIndication
{
    return build<ast::SubtypeIndication>(ctx)
      .apply([&](auto &node) {
          auto names = ctx.selected_name();

          // Grammar: selected_name (selected_name)? ...
          if (names.size() >= 2) {
              // First is resolution function, second is type mark
              node.resolution_func = names[0]->getText();
              node.type_mark = names[1]->getText();
          } else if (!names.empty()) {
              // Just type mark
              node.type_mark = names[0]->getText();
          }
      })
      .maybe(&ast::SubtypeIndication::constraint,
             ctx.constraint(),
             [this](auto &c) { return makeConstraint(c); })
      .build();
}

} // namespace builder
