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

namespace {

/// Helper to build a minimal VHDL snippet with a signal initialization
auto makeVhdl(std::string_view type, std::string_view init_expr) -> std::string
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
auto getSignalInitExpr(const ast::DesignFile &design) -> const ast::Expr *
{
    if (design.units.size() < 2) {
        return nullptr;
    }
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    if ((arch == nullptr) || arch->decls.empty()) {
        return nullptr;
    }
    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
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
auto parseExpr(std::string_view type, std::string_view init_expr) -> const ast::Expr *
{
    static ast::DesignFile design; // Static to keep alive for returned pointer
    design = builder::buildFromString(makeVhdl(type, init_expr));
    return getSignalInitExpr(design);
}

/// Assert that expr is a BinaryExpr with given operator
auto requireBinary(const ast::Expr *expr, std::string_view expected_op) -> const ast::BinaryExpr *
{
    REQUIRE(expr != nullptr);
    const auto *binary = std::get_if<ast::BinaryExpr>(expr);
    REQUIRE(binary != nullptr);
    REQUIRE(binary->op == expected_op);
    return binary;
}

/// Assert that expr is a TokenExpr with given text
auto requireToken(const ast::Expr *expr, std::string_view expected_text) -> const ast::TokenExpr *
{
    REQUIRE(expr != nullptr);
    const auto *token = std::get_if<ast::TokenExpr>(expr);
    REQUIRE(token != nullptr);
    REQUIRE(token->text == expected_text);
    return token;
}

} // namespace

TEST_CASE("BinaryExpr: Simple operators", "[expressions][binary]")
{
    SECTION("Addition")
    {
        const auto *expr = parseExpr("integer", "10 + 20");
        const auto *binary = requireBinary(expr, "+");
        requireToken(binary->left.get(), "10");
        requireToken(binary->right.get(), "20");
    }

    SECTION("Logical AND")
    {
        const auto *expr = parseExpr("boolean", "true and false");
        const auto *binary = requireBinary(expr, "and");
        requireToken(binary->left.get(), "true");
        requireToken(binary->right.get(), "false");
    }

    SECTION("Equality")
    {
        const auto *expr = parseExpr("boolean", "a = b");
        const auto *binary = requireBinary(expr, "=");
        requireToken(binary->left.get(), "a");
        requireToken(binary->right.get(), "b");
    }

    SECTION("Concatenation")
    {
        const auto *expr = parseExpr("std_logic_vector(15 downto 0)", "a & b");
        const auto *binary = requireBinary(expr, "&");
        requireToken(binary->left.get(), "a");
        requireToken(binary->right.get(), "b");
    }
}

TEST_CASE("BinaryExpr: Chained operators (left-associative)", "[expressions][binary][chained]")
{
    SECTION("Chained logical AND: a and b and c -> (a and b) and c")
    {
        const auto *expr = parseExpr("boolean", "a and b and c");
        const auto *outer = requireBinary(expr, "and");
        requireToken(outer->right.get(), "c");

        const auto *inner = requireBinary(outer->left.get(), "and");
        requireToken(inner->left.get(), "a");
        requireToken(inner->right.get(), "b");
    }

    SECTION("Chained addition: 1 + 2 + 3 -> (1 + 2) + 3")
    {
        const auto *expr = parseExpr("integer", "1 + 2 + 3");
        const auto *outer = requireBinary(expr, "+");
        requireToken(outer->right.get(), "3");

        const auto *inner = requireBinary(outer->left.get(), "+");
        requireToken(inner->left.get(), "1");
        requireToken(inner->right.get(), "2");
    }

    SECTION("Chained multiplication: 2 * 3 * 4 -> (2 * 3) * 4")
    {
        const auto *expr = parseExpr("integer", "2 * 3 * 4");
        const auto *outer = requireBinary(expr, "*");
        requireToken(outer->right.get(), "4");

        const auto *inner = requireBinary(outer->left.get(), "*");
        requireToken(inner->left.get(), "2");
        requireToken(inner->right.get(), "3");
    }

    SECTION("Mixed adding operators: a + b - c -> (a + b) - c")
    {
        const auto *expr = parseExpr("integer", "a + b - c");
        const auto *outer = requireBinary(expr, "-");
        requireToken(outer->right.get(), "c");

        const auto *inner = requireBinary(outer->left.get(), "+");
        requireToken(inner->left.get(), "a");
        requireToken(inner->right.get(), "b");
    }
}
