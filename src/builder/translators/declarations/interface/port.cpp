#include "ast/nodes/declarations/interface.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makePortClause(vhdlParser::Port_clauseContext &ctx) -> ast::PortClause
{
    return build<ast::PortClause>(ctx)
      .collectFrom(
        &ast::PortClause::ports,
        ctx.port_list(),
        [](auto &list) { return list.interface_port_declaration(); },
        [this](auto *decl) { return makeSignalPort(*decl); })
      .build();
}

auto Translator::makeSignalPort(vhdlParser::Interface_port_declarationContext &ctx) -> ast::Port
{
    return build<ast::Port>(ctx)
      .set(&ast::Port::names, extractNames(ctx.identifier_list()))
      .set(&ast::Port::mode, extractMode(ctx.signal_mode()))
      .set(&ast::Port::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .maybe(&ast::Port::default_expr, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .build();
}

} // namespace builder
