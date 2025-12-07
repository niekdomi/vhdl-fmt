#include "ast/nodes/expressions.hpp"
#include "expr_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("UnaryExpr", "[expressions][unary]")
{
    SECTION("Negation operator")
    {
        const auto *expr = expr_utils::parseExpr("-42");
        const auto *unary = std::get_if<ast::UnaryExpr>(expr);
        REQUIRE(unary != nullptr);
        REQUIRE(unary->op == "-");

        const auto *val = std::get_if<ast::TokenExpr>(unary->value.get());
        REQUIRE(val != nullptr);
        REQUIRE(val->text == "42");
    }

    SECTION("Plus operator")
    {
        const auto *expr = expr_utils::parseExpr("+42");
        const auto *unary = std::get_if<ast::UnaryExpr>(expr);
        REQUIRE(unary != nullptr);
        REQUIRE(unary->op == "+");

        const auto *val = std::get_if<ast::TokenExpr>(unary->value.get());
        REQUIRE(val != nullptr);
        REQUIRE(val->text == "42");
    }

    SECTION("Not operator")
    {
        const auto *expr = expr_utils::parseExpr("not ready");
        const auto *unary = std::get_if<ast::UnaryExpr>(expr);
        REQUIRE(unary != nullptr);
        REQUIRE(unary->op == "not");

        const auto *val = std::get_if<ast::TokenExpr>(unary->value.get());
        REQUIRE(val != nullptr);
        REQUIRE(val->text == "ready");
    }
}
