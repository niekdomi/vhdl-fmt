#include "ast/nodes/expressions.hpp"
#include "expr_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("TokenExpr", "[expressions][token]")
{
    SECTION("Integer literal")
    {
        const auto *expr = expr_utils::parseExpr("42");
        const auto *tok = std::get_if<ast::TokenExpr>(expr);
        REQUIRE(tok != nullptr);
        REQUIRE(tok->text == "42");
    }

    SECTION("Bit literal")
    {
        const auto *expr = expr_utils::parseExpr("'0'");
        const auto *tok = std::get_if<ast::TokenExpr>(expr);
        REQUIRE(tok != nullptr);
        REQUIRE(tok->text == "'0'");
    }

    SECTION("Identifier")
    {
        const auto *expr = expr_utils::parseExpr("MAX_VALUE");
        const auto *tok = std::get_if<ast::TokenExpr>(expr);
        REQUIRE(tok != nullptr);
        REQUIRE(tok->text == "MAX_VALUE");
    }
}
