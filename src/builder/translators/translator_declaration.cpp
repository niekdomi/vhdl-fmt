#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>

namespace builder {

// ---------------------- Clauses ----------------------

auto Translator::makeGenericClause(vhdlParser::Generic_clauseContext &ctx) -> ast::GenericClause
{
    auto clause = make<ast::GenericClause>(ctx);

    auto *list = ctx.generic_list();
    if (list == nullptr) {
        return clause;
    }

    const auto &declarations = list->interface_constant_declaration();
    clause.generics
      = std::views::transform(declarations, [&](auto *decl) { return makeGenericParam(*decl); })
      | std::ranges::to<std::vector>();

    return clause;
}

auto Translator::makePortClause(vhdlParser::Port_clauseContext &ctx) -> ast::PortClause
{
    auto clause = make<ast::PortClause>(ctx);

    auto *list = ctx.port_list();
    if (list == nullptr) {
        return clause;
    }

    auto *iface = list->interface_port_list();
    if (iface == nullptr) {
        return clause;
    }

    const auto &declarations = iface->interface_port_declaration();
    clause.ports
      = std::views::transform(declarations, [&](auto *decl) { return makeSignalPort(*decl); })
      | std::ranges::to<std::vector>();

    return clause;
}

// ---------------------- Interface declarations ----------------------

auto Translator::makeGenericParam(vhdlParser::Interface_constant_declarationContext &ctx)
  -> ast::GenericParam
{
    auto param = make<ast::GenericParam>(ctx);

    param.names = ctx.identifier_list()->identifier()
                | std::views::transform([](auto *id) { return id->getText(); })
                | std::ranges::to<std::vector>();

    if (auto *stype = ctx.subtype_indication()) {
        param.type_name = stype->getText();
    }

    if (auto *expr = ctx.expression()) {
        param.default_expr = makeExpr(*expr);
    }

    return param;
}

// ---------------------- Object declarations ----------------------

auto Translator::makeSignalPort(vhdlParser::Interface_port_declarationContext &ctx) -> ast::Port
{
    auto port = make<ast::Port>(ctx);

    port.names = ctx.identifier_list()->identifier()
               | std::views::transform([](auto *id) { return id->getText(); })
               | std::ranges::to<std::vector>();

    if (auto *mode = ctx.signal_mode()) {
        port.mode = mode->getText();
    }

    if (auto *stype = ctx.subtype_indication()) {
        port.type_name = stype->selected_name(0)->getText();

        if (auto *constraint_ctx = stype->constraint()) {
            port.constraint = makeConstraint(*constraint_ctx);
        }
    }

    if (auto *expr = ctx.expression()) {
        port.default_expr = makeExpr(*expr);
    }

    return port;
}

auto Translator::makeConstantDecl(vhdlParser::Constant_declarationContext &ctx) -> ast::ConstantDecl
{
    auto decl = make<ast::ConstantDecl>(ctx);

    decl.names = ctx.identifier_list()->identifier()
               | std::views::transform([](auto *id) { return id->getText(); })
               | std::ranges::to<std::vector>();

    if (auto *stype = ctx.subtype_indication()) {
        decl.type_name = stype->selected_name(0)->getText();
    }

    if (auto *expr = ctx.expression()) {
        decl.init_expr = makeExpr(*expr);
    }

    return decl;
}

auto Translator::makeSignalDecl(vhdlParser::Signal_declarationContext &ctx) -> ast::SignalDecl
{
    auto decl = make<ast::SignalDecl>(ctx);

    decl.names = ctx.identifier_list()->identifier()
               | std::views::transform([](auto *id) { return id->getText(); })
               | std::ranges::to<std::vector>();

    if (auto *stype = ctx.subtype_indication()) {
        decl.type_name = stype->selected_name(0)->getText();

        if (auto *constraint_ctx = stype->constraint()) {
            decl.constraint = makeConstraint(*constraint_ctx);
        }
    }

    decl.has_bus_kw = false;
    if (auto *kind = ctx.signal_kind()) {
        if (kind->BUS() != nullptr) {
            decl.has_bus_kw = true;
        }
    }

    if (auto *expr = ctx.expression()) {
        decl.init_expr = makeExpr(*expr);
    }

    return decl;
}

auto Translator::makeVariableDecl(vhdlParser::Variable_declarationContext &ctx) -> ast::VariableDecl
{
    auto decl = make<ast::VariableDecl>(ctx);

    if (ctx.SHARED() != nullptr) {
        decl.shared = true;
    }

    decl.names = ctx.identifier_list()->identifier()
               | std::views::transform([](auto *id) { return id->getText(); })
               | std::ranges::to<std::vector>();

    if (auto *stype = ctx.subtype_indication()) {
        decl.type_name = stype->selected_name(0)->getText();

        if (auto *constraint_ctx = stype->constraint()) {
            decl.constraint = makeConstraint(*constraint_ctx);
        }
    }

    if (auto *expr = ctx.expression()) {
        decl.init_expr = makeExpr(*expr);
    }

    return decl;
}

} // namespace builder
