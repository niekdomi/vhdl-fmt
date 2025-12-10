#include "ast/nodes/declarations/objects.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeSignalDecl(vhdlParser::Signal_declarationContext &ctx) -> ast::SignalDecl
{
    auto *skind = ctx.signal_kind();

    return build<ast::SignalDecl>(ctx)
      .set(&ast::SignalDecl::names, extractNames(ctx.identifier_list()))
      .set(&ast::SignalDecl::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .set(&ast::SignalDecl::has_bus_kw, skind != nullptr && skind->BUS() != nullptr)
      .maybe(
        &ast::SignalDecl::init_expr, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .build();
}

} // namespace builder
