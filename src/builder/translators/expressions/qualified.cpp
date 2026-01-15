#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <stdexcept>
#include <utility>

namespace builder {

auto Translator::makeQualifiedExpr(vhdlParser::Qualified_expressionContext& ctx)
  -> ast::QualifiedExpr
{
    ast::GroupExpr operand{};

    if (auto* agg = ctx.aggregate()) {
        operand = makeAggregate(*agg);
    }

    // If missing, return nothing.
    auto* subtype = ctx.subtype_indication();
    if (subtype == nullptr) {
        throw std::runtime_error("Qualified expression must have a subtype indication");
    }

    return build<ast::QualifiedExpr>(ctx)
      .set(&ast::QualifiedExpr::type_mark, makeSubtypeIndication(*subtype))
      .setBox(&ast::QualifiedExpr::operand, std::move(operand))
      .build();
}

} // namespace builder
