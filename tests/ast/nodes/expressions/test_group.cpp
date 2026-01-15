#include "ast/nodes/expressions.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("GroupExpr", "[expressions][group]")
{
    SECTION("Positional aggregate")
    {
        const auto* expr = test_helpers::parseExpr("(0, 1, 2)");
        const auto* group = std::get_if<ast::GroupExpr>(expr);
        REQUIRE(group != nullptr);
        REQUIRE(group->children.size() == 3);

        const auto* elem0 = std::get_if<ast::TokenExpr>(group->children.data());
        REQUIRE(elem0 != nullptr);
        REQUIRE(elem0->text == "0");

        const auto* elem1 = std::get_if<ast::TokenExpr>(&group->children.at(1));
        REQUIRE(elem1 != nullptr);
        REQUIRE(elem1->text == "1");

        const auto* elem2 = std::get_if<ast::TokenExpr>(&group->children.at(2));
        REQUIRE(elem2 != nullptr);
        REQUIRE(elem2->text == "2");
    }

    SECTION("Named associations")
    {
        const auto* expr = test_helpers::parseExpr("(0 => '1', 1 => '0')");
        const auto* group = std::get_if<ast::GroupExpr>(expr);
        REQUIRE(group != nullptr);
        REQUIRE(group->children.size() == 2);

        const auto* first = std::get_if<ast::BinaryExpr>(group->children.data());
        REQUIRE(first != nullptr);
        REQUIRE(first->op == "=>");

        const auto* first_left = std::get_if<ast::TokenExpr>(first->left.get());
        REQUIRE(first_left != nullptr);
        REQUIRE(first_left->text == "0");

        const auto* first_right = std::get_if<ast::TokenExpr>(first->right.get());
        REQUIRE(first_right != nullptr);
        REQUIRE(first_right->text == "'1'");

        const auto* second = std::get_if<ast::BinaryExpr>(&group->children.at(1));
        REQUIRE(second != nullptr);
        REQUIRE(second->op == "=>");

        const auto* second_left = std::get_if<ast::TokenExpr>(second->left.get());
        REQUIRE(second_left != nullptr);
        REQUIRE(second_left->text == "1");

        const auto* second_right = std::get_if<ast::TokenExpr>(second->right.get());
        REQUIRE(second_right != nullptr);
        REQUIRE(second_right->text == "'0'");
    }

    SECTION("Others keyword")
    {
        const auto* expr = test_helpers::parseExpr("(0 => '1', others => '0')");
        const auto* group = std::get_if<ast::GroupExpr>(expr);
        REQUIRE(group != nullptr);
        REQUIRE(group->children.size() == 2);

        const auto* first = std::get_if<ast::BinaryExpr>(group->children.data());
        REQUIRE(first != nullptr);
        REQUIRE(first->op == "=>");

        const auto* second = std::get_if<ast::BinaryExpr>(&group->children.at(1));
        REQUIRE(second != nullptr);
        REQUIRE(second->op == "=>");

        const auto* others = std::get_if<ast::TokenExpr>(second->left.get());
        REQUIRE(others != nullptr);
        REQUIRE(others->text == "others");
    }

    SECTION("Nested aggregates")
    {
        const auto* expr = test_helpers::parseExpr("((1, 2), (3, 4))");
        const auto* outer_group = std::get_if<ast::GroupExpr>(expr);
        REQUIRE(outer_group != nullptr);
        REQUIRE(outer_group->children.size() == 2);

        const auto* first_group = std::get_if<ast::GroupExpr>(outer_group->children.data());
        REQUIRE(first_group != nullptr);
        REQUIRE(first_group->children.size() == 2);

        const auto* elem1 = std::get_if<ast::TokenExpr>(first_group->children.data());
        REQUIRE(elem1 != nullptr);
        REQUIRE(elem1->text == "1");

        const auto* elem2 = std::get_if<ast::TokenExpr>(&first_group->children.at(1));
        REQUIRE(elem2 != nullptr);
        REQUIRE(elem2->text == "2");

        const auto* second_group = std::get_if<ast::GroupExpr>(&outer_group->children.at(1));
        REQUIRE(second_group != nullptr);
        REQUIRE(second_group->children.size() == 2);

        const auto* elem3 = std::get_if<ast::TokenExpr>(second_group->children.data());
        REQUIRE(elem3 != nullptr);
        REQUIRE(elem3->text == "3");

        const auto* elem4 = std::get_if<ast::TokenExpr>(&second_group->children.at(1));
        REQUIRE(elem4 != nullptr);
        REQUIRE(elem4->text == "4");
    }
}
