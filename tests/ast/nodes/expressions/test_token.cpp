#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

// Helper to get expression from signal initialization
namespace {

auto getSignalInitExpr(const ast::DesignFile &design) -> const ast::Expr *
{
    if (design.units.size() < 2) {
        return nullptr;
    }

    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    if ((arch == nullptr) || arch->decls.empty()) {
        return nullptr;
    }

    const auto *signal = std::get_if<ast::SignalDecl>(arch->decls.data());
    if ((signal == nullptr) || !signal->init_expr.has_value()) {
        return nullptr;
    }

    return &(*signal->init_expr);
}

} // namespace

TEST_CASE("TokenExpr: Integer literal", "[expressions][token]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := 42;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *tok = std::get_if<ast::TokenExpr>(expr);
    REQUIRE(tok != nullptr);
    REQUIRE(tok->text == "42");
}

TEST_CASE("TokenExpr: Negative integer", "[expressions][token]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := -100;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    // Negative numbers are typically parsed as unary expressions
    // but if parsed as token, check for it
    if (const auto *tok = std::get_if<ast::TokenExpr>(expr)) {
        REQUIRE(tok->text == "-100");
    } else {
        // Likely UnaryExpr with "-" operator
        REQUIRE(std::holds_alternative<ast::UnaryExpr>(*expr));
    }
}

TEST_CASE("TokenExpr: Bit literal '0'", "[expressions][token]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : std_logic := '0';
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *tok = std::get_if<ast::TokenExpr>(expr);
    REQUIRE(tok != nullptr);
    REQUIRE(tok->text == "'0'");
}

TEST_CASE("TokenExpr: Bit literal '1'", "[expressions][token]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : std_logic := '1';
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *tok = std::get_if<ast::TokenExpr>(expr);
    REQUIRE(tok != nullptr);
    REQUIRE(tok->text == "'1'");
}

TEST_CASE("TokenExpr: Identifier", "[expressions][token]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := MAX_VALUE;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *tok = std::get_if<ast::TokenExpr>(expr);
    REQUIRE(tok != nullptr);
    REQUIRE(tok->text == "MAX_VALUE");
}
