#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeFactor(vhdlParser::FactorContext &ctx) -> ast::Expr
{
    if (ctx.DOUBLESTAR() != nullptr) {
        return makeBinary(ctx, "**", makePrimary(*ctx.primary(0)), makePrimary(*ctx.primary(1)));
    }

    if (ctx.ABS() != nullptr) {
        return makeUnary(ctx, "abs", makePrimary(*ctx.primary(0)));
    }

    if (ctx.NOT() != nullptr) {
        return makeUnary(ctx, "not", makePrimary(*ctx.primary(0)));
    }

    return makePrimary(*ctx.primary(0));
}

} // namespace builder
