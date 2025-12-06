#include "expr_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("ParenExpr", "[expressions][paren]")
{
    SECTION("Simple parenthesized expression")
    {
        const auto *expr = expr_utils::parseExpr("(x)");
        const auto *paren = std::get_if<ast::ParenExpr>(expr);
        REQUIRE(paren != nullptr);

        const auto *inner = std::get_if<ast::TokenExpr>(paren->inner.get());
        REQUIRE(inner != nullptr);
        REQUIRE(inner->text == "x");
    }

    SECTION("Precedence control")
    {
        const auto *expr = expr_utils::parseExpr("(a + b) * c");
        const auto *mult = std::get_if<ast::BinaryExpr>(expr);
        REQUIRE(mult != nullptr);
        REQUIRE(mult->op == "*");

        const auto *paren = std::get_if<ast::ParenExpr>(mult->left.get());
        REQUIRE(paren != nullptr);

        const auto *add = std::get_if<ast::BinaryExpr>(paren->inner.get());
        REQUIRE(add != nullptr);
        REQUIRE(add->op == "+");

        const auto *left = std::get_if<ast::TokenExpr>(add->left.get());
        REQUIRE(left != nullptr);
        REQUIRE(left->text == "a");

        const auto *right = std::get_if<ast::TokenExpr>(add->right.get());
        REQUIRE(right != nullptr);
        REQUIRE(right->text == "b");

        const auto *c = std::get_if<ast::TokenExpr>(mult->right.get());
        REQUIRE(c != nullptr);
        REQUIRE(c->text == "c");
    }

    SECTION("Nested parentheses")
    {
        const auto *expr = expr_utils::parseExpr("((x))");
        const auto *outer_paren = std::get_if<ast::ParenExpr>(expr);
        REQUIRE(outer_paren != nullptr);

        const auto *inner_paren = std::get_if<ast::ParenExpr>(outer_paren->inner.get());
        REQUIRE(inner_paren != nullptr);

        const auto *token = std::get_if<ast::TokenExpr>(inner_paren->inner.get());
        REQUIRE(token != nullptr);
        REQUIRE(token->text == "x");
    }
}
