#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <utility>

namespace builder {

auto Translator::makeSliceExpr(ast::Expr base, vhdlParser::Slice_name_partContext &ctx) -> ast::Expr
{
    return build<ast::SliceExpr>(ctx)
      .setBox(&ast::SliceExpr::prefix, std::move(base))
      .maybeBox(&ast::SliceExpr::range,
                ctx.discrete_range(),
                [&](auto &dr) { return makeDiscreteRange(dr); })
      .build();
}

} // namespace builder
