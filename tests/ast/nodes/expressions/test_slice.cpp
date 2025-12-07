#include "expr_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("SliceExpr", "[expressions][slice]")
{
    SECTION("Simple slice with downto")
    {
        const auto *expr = expr_utils::parseExpr("data(7 downto 0)");
        const auto *slice = std::get_if<ast::SliceExpr>(expr);
        REQUIRE(slice != nullptr);

        const auto *prefix = std::get_if<ast::TokenExpr>(slice->prefix.get());
        REQUIRE(prefix != nullptr);
        REQUIRE(prefix->text == "data");

        const auto *range = std::get_if<ast::BinaryExpr>(slice->range.get());
        REQUIRE(range != nullptr);
        REQUIRE(range->op == "downto");

        const auto *left = std::get_if<ast::TokenExpr>(range->left.get());
        REQUIRE(left != nullptr);
        REQUIRE(left->text == "7");

        const auto *right = std::get_if<ast::TokenExpr>(range->right.get());
        REQUIRE(right != nullptr);
        REQUIRE(right->text == "0");
    }

    SECTION("Slice with to direction")
    {
        const auto *expr = expr_utils::parseExpr("data(0 to 7)");
        const auto *slice = std::get_if<ast::SliceExpr>(expr);
        REQUIRE(slice != nullptr);

        const auto *prefix = std::get_if<ast::TokenExpr>(slice->prefix.get());
        REQUIRE(prefix != nullptr);
        REQUIRE(prefix->text == "data");

        const auto *range = std::get_if<ast::BinaryExpr>(slice->range.get());
        REQUIRE(range != nullptr);
        REQUIRE(range->op == "to");

        const auto *left = std::get_if<ast::TokenExpr>(range->left.get());
        REQUIRE(left != nullptr);
        REQUIRE(left->text == "0");

        const auto *right = std::get_if<ast::TokenExpr>(range->right.get());
        REQUIRE(right != nullptr);
        REQUIRE(right->text == "7");
    }
}
