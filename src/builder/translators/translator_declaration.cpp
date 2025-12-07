#include "ast/nodes/declarations.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

// ---------------------- Clauses ----------------------

auto Translator::makeGenericClause(vhdlParser::Generic_clauseContext &ctx) -> ast::GenericClause
{
    return build<ast::GenericClause>(ctx)
      .collectFrom(
        &ast::GenericClause::generics,
        ctx.generic_list(),
        [](auto &list) { return list.interface_constant_declaration(); },
        [this](auto *decl) { return makeGenericParam(*decl); })
      .build();
}

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

// ---------------------- Interface declarations ----------------------

auto Translator::makeGenericParam(vhdlParser::Interface_constant_declarationContext &ctx)
  -> ast::GenericParam
{
    return build<ast::GenericParam>(ctx)
      .set(&ast::GenericParam::names, extractNames(ctx.identifier_list()))
      .set(&ast::GenericParam::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .maybe(&ast::GenericParam::default_expr,
             ctx.expression(),
             [&](auto &expr) { return makeExpr(expr); })
      .build();
}

// ---------------------- Object declarations ----------------------

auto Translator::makeSignalPort(vhdlParser::Interface_port_declarationContext &ctx) -> ast::Port
{
    return build<ast::Port>(ctx)
      .set(&ast::Port::names, extractNames(ctx.identifier_list()))
      .set(&ast::Port::mode, extractMode(ctx.signal_mode()))
      .set(&ast::Port::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .maybe(&ast::Port::default_expr, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .build();
}

auto Translator::makeConstantDecl(vhdlParser::Constant_declarationContext &ctx) -> ast::ConstantDecl
{
    return build<ast::ConstantDecl>(ctx)
      .set(&ast::ConstantDecl::names, extractNames(ctx.identifier_list()))
      .set(&ast::ConstantDecl::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .maybe(
        &ast::ConstantDecl::init_expr, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .build();
}

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

auto Translator::makeVariableDecl(vhdlParser::Variable_declarationContext &ctx) -> ast::VariableDecl
{
    return build<ast::VariableDecl>(ctx)
      .set(&ast::VariableDecl::shared, ctx.SHARED() != nullptr)
      .set(&ast::VariableDecl::names, extractNames(ctx.identifier_list()))
      .set(&ast::VariableDecl::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .maybe(
        &ast::VariableDecl::init_expr, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .build();
}

auto Translator::makeComponentDecl(vhdlParser::Component_declarationContext &ctx)
  -> ast::ComponentDecl
{
    return build<ast::ComponentDecl>(ctx)
      .set(&ast::ComponentDecl::name, ctx.identifier(0)->getText())
      .set(&ast::ComponentDecl::has_is_keyword, ctx.IS() != nullptr)
      .maybe(
        &ast::ComponentDecl::end_label, ctx.identifier(1), [](auto &id) { return id.getText(); })
      .maybe(&ast::ComponentDecl::generic_clause,
             ctx.generic_clause(),
             [&](auto &gc) { return makeGenericClause(gc); })
      .maybe(&ast::ComponentDecl::port_clause,
             ctx.port_clause(),
             [&](auto &pc) { return makePortClause(pc); })
      .build();
}

} // namespace builder
