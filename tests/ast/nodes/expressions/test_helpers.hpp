#ifndef TEST_HELPERS_HPP
#define TEST_HELPERS_HPP

#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <format>
#include <string>
#include <string_view>
#include <variant>

namespace test_helpers {

/// Helper to build a minimal VHDL snippet with a signal initialization
inline auto makeVhdl(std::string_view type, std::string_view init_expr) -> std::string
{
    return std::format(R"(
        entity E is end E;
        architecture A of E is
            signal x : {} := {};
        begin
        end A;
    )",
                       type,
                       init_expr);
}

/// Extract expression from signal initialization in the architecture
inline auto getSignalInitExpr(const ast::DesignFile &design) -> const ast::Expr *
{
    if (design.units.size() < 2) {
        return nullptr;
    }
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    if ((arch == nullptr) || arch->decls.empty()) {
        return nullptr;
    }
    const auto *decl_item = std::get_if<ast::Declaration>(&arch->decls[0]);
    if (decl_item == nullptr) {
        return nullptr;
    }
    const auto *signal = std::get_if<ast::SignalDecl>(decl_item);
    if ((signal == nullptr) || !signal->init_expr.has_value()) {
        return nullptr;
    }
    return &(*signal->init_expr);
}

/// Parse VHDL and extract the signal init expression
inline auto parseExpr(std::string_view type, std::string_view init_expr) -> const ast::Expr *
{
    static ast::DesignFile design; // Static to keep alive for returned pointer
    design = builder::buildFromString(makeVhdl(type, init_expr));
    return getSignalInitExpr(design);
}

/// Assert that expr is a TokenExpr with given text
inline auto requireToken(const ast::Expr *expr, std::string_view expected_text) -> const ast::TokenExpr *
{
    REQUIRE(expr != nullptr);
    const auto *token = std::get_if<ast::TokenExpr>(expr);
    REQUIRE(token != nullptr);
    REQUIRE(token->text == expected_text);
    return token;
}

/// Assert that expr is a BinaryExpr with given operator
inline auto requireBinary(const ast::Expr *expr, std::string_view expected_op) -> const ast::BinaryExpr *
{
    REQUIRE(expr != nullptr);
    const auto *binary = std::get_if<ast::BinaryExpr>(expr);
    REQUIRE(binary != nullptr);
    REQUIRE(binary->op == expected_op);
    return binary;
}

/// Assert that expr is a UnaryExpr with given operator
inline auto requireUnary(const ast::Expr *expr, std::string_view expected_op) -> const ast::UnaryExpr *
{
    REQUIRE(expr != nullptr);
    const auto *unary = std::get_if<ast::UnaryExpr>(expr);
    REQUIRE(unary != nullptr);
    REQUIRE(unary->op == expected_op);
    return unary;
}

/// Assert that expr is a ParenExpr
inline auto requireParen(const ast::Expr *expr) -> const ast::ParenExpr *
{
    REQUIRE(expr != nullptr);
    const auto *paren = std::get_if<ast::ParenExpr>(expr);
    REQUIRE(paren != nullptr);
    return paren;
}

/// Assert that expr is a CallExpr
inline auto requireCall(const ast::Expr *expr) -> const ast::CallExpr *
{
    REQUIRE(expr != nullptr);
    const auto *call = std::get_if<ast::CallExpr>(expr);
    REQUIRE(call != nullptr);
    return call;
}

/// Assert that expr is a GroupExpr with expected number of children
inline auto requireGroup(const ast::Expr *expr, size_t expected_size) -> const ast::GroupExpr *
{
    REQUIRE(expr != nullptr);
    const auto *group = std::get_if<ast::GroupExpr>(expr);
    REQUIRE(group != nullptr);
    REQUIRE(group->children.size() == expected_size);
    return group;
}

/// Assert that expr is an AttributeExpr with given attribute name
inline auto requireAttribute(const ast::Expr *expr, std::string_view expected_attr) -> const ast::AttributeExpr *
{
    REQUIRE(expr != nullptr);
    const auto *attr = std::get_if<ast::AttributeExpr>(expr);
    REQUIRE(attr != nullptr);
    REQUIRE(attr->attribute == expected_attr);
    return attr;
}

/// Assert that expr is a QualifiedExpr with given type_mark
inline auto requireQualified(const ast::Expr *expr, std::string_view expected_type) -> const ast::QualifiedExpr *
{
    REQUIRE(expr != nullptr);
    const auto *qual = std::get_if<ast::QualifiedExpr>(expr);
    REQUIRE(qual != nullptr);
    REQUIRE(qual->type_mark == expected_type);
    return qual;
}

/// Assert that expr is a PhysicalLiteral with expected value and unit
inline auto requirePhysical(const ast::Expr *expr, std::string_view expected_value, std::string_view expected_unit)
    -> const ast::PhysicalLiteral *
{
    REQUIRE(expr != nullptr);
    const auto *physical = std::get_if<ast::PhysicalLiteral>(expr);
    REQUIRE(physical != nullptr);
    REQUIRE(physical->value == expected_value);
    REQUIRE(physical->unit == expected_unit);
    return physical;
}

} // namespace test_helpers

#endif // TEST_HELPERS_HPP
