#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <memory>

namespace builder {

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

} // namespace builder
