#include "ast/nodes/expressions.hpp"
#include "expr_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("BinaryExpr", "[expressions][binary]")
{
    SECTION("Simple binary operation")
    {
        const auto* expr = expr_utils::parseExpr("10 + 20");
        const auto* binary = std::get_if<ast::BinaryExpr>(expr);
        REQUIRE(binary != nullptr);
        REQUIRE(binary->op == "+");

        const auto* left = std::get_if<ast::TokenExpr>(binary->left.get());
        REQUIRE(left != nullptr);
        REQUIRE(left->text == "10");

        const auto* right = std::get_if<ast::TokenExpr>(binary->right.get());
        REQUIRE(right != nullptr);
        REQUIRE(right->text == "20");
    }

    SECTION("Left-associative chaining")
    {
        const auto* expr = expr_utils::parseExpr("a and b and c");
        const auto* outer = std::get_if<ast::BinaryExpr>(expr);
        REQUIRE(outer != nullptr);
        REQUIRE(outer->op == "and");

        const auto* right = std::get_if<ast::TokenExpr>(outer->right.get());
        REQUIRE(right != nullptr);
        REQUIRE(right->text == "c");

        const auto* inner = std::get_if<ast::BinaryExpr>(outer->left.get());
        REQUIRE(inner != nullptr);
        REQUIRE(inner->op == "and");

        const auto* left1 = std::get_if<ast::TokenExpr>(inner->left.get());
        REQUIRE(left1 != nullptr);
        REQUIRE(left1->text == "a");

        const auto* left2 = std::get_if<ast::TokenExpr>(inner->right.get());
        REQUIRE(left2 != nullptr);
        REQUIRE(left2->text == "b");
    }

    SECTION("Operator precedence")
    {
        const auto* expr = expr_utils::parseExpr("a + b * c");
        const auto* outer = std::get_if<ast::BinaryExpr>(expr);
        REQUIRE(outer != nullptr);
        REQUIRE(outer->op == "+");

        const auto* left = std::get_if<ast::TokenExpr>(outer->left.get());
        REQUIRE(left != nullptr);
        REQUIRE(left->text == "a");

        const auto* inner = std::get_if<ast::BinaryExpr>(outer->right.get());
        REQUIRE(inner != nullptr);
        REQUIRE(inner->op == "*");

        const auto* inner_left = std::get_if<ast::TokenExpr>(inner->left.get());
        REQUIRE(inner_left != nullptr);
        REQUIRE(inner_left->text == "b");

        const auto* inner_right = std::get_if<ast::TokenExpr>(inner->right.get());
        REQUIRE(inner_right != nullptr);
        REQUIRE(inner_right->text == "c");
    }
}
