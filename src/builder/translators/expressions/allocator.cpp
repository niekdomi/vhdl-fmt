#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <utility>

namespace builder {

auto Translator::makeAllocator(vhdlParser::AllocatorContext &ctx) -> ast::UnaryExpr
{
    ast::Expr operand{};

    if (auto *qual = ctx.qualified_expression()) {
        operand = makeQualifiedExpr(*qual);
    } else if (auto *subtype = ctx.subtype_indication()) {
        operand = makeSubtypeIndication(*subtype);
    } else {
        operand = makeToken(ctx);
    }

    return makeUnary(ctx, "new", std::move(operand));
}

} // namespace builder
