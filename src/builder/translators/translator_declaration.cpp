#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>
#include <string>
#include <vector>

namespace builder {

// ============================================================================
// Extraction Helpers
// ============================================================================

namespace {

auto extractNames(vhdlParser::Identifier_listContext *ctx) -> std::vector<std::string>
{
    if (ctx == nullptr) {
        return {};
    }
    return ctx->identifier()
         | std::views::transform([](auto *id) { return id->getText(); })
         | std::ranges::to<std::vector>();
}

auto extractTypeName(vhdlParser::Subtype_indicationContext *ctx) -> std::string
{
    if (ctx == nullptr || ctx->selected_name().empty()) {
        return {};
    }
    return ctx->selected_name(0)->getText();
}

auto extractTypeFullText(vhdlParser::Subtype_indicationContext *ctx) -> std::string
{
    if (ctx == nullptr) {
        return {};
    }
    return ctx->getText();
}

auto extractMode(vhdlParser::Signal_modeContext *ctx) -> std::string
{
    if (ctx == nullptr) {
        return {};
    }
    return ctx->getText();
}

/// @brief Helper to extract type info from subtype_indication into node fields.
/// @tparam Node AST node type with type_name and constraint fields.
template<typename Node>
void extractSubtypeInfo(Node &node,
                        vhdlParser::Subtype_indicationContext *stype,
                        auto &&make_constraint_fn)
{
    if (stype == nullptr) {
        return;
    }
    node.type_name = extractTypeName(stype);
    if (auto *constr = stype->constraint()) {
        node.constraint = make_constraint_fn(*constr);
    }
}

} // namespace

// ============================================================================
// Translator Implementation
// ============================================================================

// ---------------------- Clauses ----------------------

auto Translator::makeGenericClause(vhdlParser::Generic_clauseContext &ctx) -> ast::GenericClause
{
    return build<ast::GenericClause>(ctx)
      .collectFrom(
        &ast::GenericClause::generics,
        ctx.generic_list(),
        [](auto &list) { return list.interface_constant_declaration(); },
        [&](auto *decl) { return makeGenericParam(*decl); })
      .build();
}

auto Translator::makePortClause(vhdlParser::Port_clauseContext &ctx) -> ast::PortClause
{
    auto *port_list = ctx.port_list();
    auto *iface = (port_list != nullptr) ? port_list->interface_port_list() : nullptr;

    return build<ast::PortClause>(ctx)
      .collect(&ast::PortClause::ports,
               (iface != nullptr) ? iface->interface_port_declaration()
                                  : decltype(iface->interface_port_declaration()){},
               [&](auto *decl) { return makeSignalPort(*decl); })
      .build();
}

// ---------------------- Interface declarations ----------------------

auto Translator::makeGenericParam(vhdlParser::Interface_constant_declarationContext &ctx)
  -> ast::GenericParam
{
    return build<ast::GenericParam>(ctx)
      .set(&ast::GenericParam::names, extractNames(ctx.identifier_list()))
      .set(&ast::GenericParam::type_name, extractTypeFullText(ctx.subtype_indication()))
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
      .apply([&](auto &node) {
          extractSubtypeInfo(
            node, ctx.subtype_indication(), [&](auto &c) { return makeConstraint(c); });
      })
      .maybe(&ast::Port::default_expr, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .build();
}

auto Translator::makeConstantDecl(vhdlParser::Constant_declarationContext &ctx) -> ast::ConstantDecl
{
    return build<ast::ConstantDecl>(ctx)
      .set(&ast::ConstantDecl::names, extractNames(ctx.identifier_list()))
      .set(&ast::ConstantDecl::type_name, extractTypeName(ctx.subtype_indication()))
      .maybe(
        &ast::ConstantDecl::init_expr, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .build();
}

auto Translator::makeSignalDecl(vhdlParser::Signal_declarationContext &ctx) -> ast::SignalDecl
{
    auto *skind = ctx.signal_kind();

    return build<ast::SignalDecl>(ctx)
      .set(&ast::SignalDecl::names, extractNames(ctx.identifier_list()))
      .apply([&](auto &node) {
          extractSubtypeInfo(
            node, ctx.subtype_indication(), [&](auto &c) { return makeConstraint(c); });
      })
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
      .apply([&](auto &node) {
          extractSubtypeInfo(
            node, ctx.subtype_indication(), [&](auto &c) { return makeConstraint(c); });
      })
      .maybe(
        &ast::VariableDecl::init_expr, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .build();
}

} // namespace builder
