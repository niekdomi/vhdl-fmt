#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

using namespace test_helpers;

TEST_CASE("GroupExpr: Simple aggregates", "[expressions][group][aggregate]")
{
    SECTION("(0, 1, 2)")
    {
        const auto *expr = parseExpr("array_type", "(0, 1, 2)");

        // Direct GroupExpr (parentheses are implicit in aggregate context)
        const auto *group = requireGroup(expr, 3);

        requireToken(&group->children[0], "0");
        requireToken(&group->children[1], "1");
        requireToken(&group->children[2], "2");
    }

    SECTION("(a, b, c, d)")
    {
        const auto *expr = parseExpr("array_type", "(a, b, c, d)");

        const auto *group = requireGroup(expr, 4);

        requireToken(&group->children[0], "a");
        requireToken(&group->children[1], "b");
        requireToken(&group->children[2], "c");
        requireToken(&group->children[3], "d");
    }
}

TEST_CASE("GroupExpr: Named associations", "[expressions][group][named]")
{
    SECTION("(0 => '1', 1 => '0')")
    {
        const auto *expr = parseExpr("std_logic_vector(1 downto 0)", "(0 => '1', 1 => '0')");

        const auto *group = requireGroup(expr, 2);

        // First element: 0 => '1'
        const auto *first = requireBinary(&group->children[0], "=>");
        requireToken(first->left.get(), "0");
        requireToken(first->right.get(), "'1'");

        // Second element: 1 => '0'
        const auto *second = requireBinary(&group->children[1], "=>");
        requireToken(second->left.get(), "1");
        requireToken(second->right.get(), "'0'");
    }

    SECTION("(field1 => value1, field2 => value2)")
    {
        const auto *expr = parseExpr("record_type", "(field1 => value1, field2 => value2)");

        const auto *group = requireGroup(expr, 2);

        const auto *first = requireBinary(&group->children[0], "=>");
        requireToken(first->left.get(), "field1");
        requireToken(first->right.get(), "value1");

        const auto *second = requireBinary(&group->children[1], "=>");
        requireToken(second->left.get(), "field2");
        requireToken(second->right.get(), "value2");
    }
}

TEST_CASE("GroupExpr: Others keyword", "[expressions][group][others]")
{
    SECTION("(others => '0')")
    {
        const auto *expr = parseExpr("std_logic_vector(7 downto 0)", "(others => '0')");

        // Could be either a BinaryExpr directly or a GroupExpr with one element
        const auto *group = std::get_if<ast::GroupExpr>(expr);
        if (group != nullptr) {
            REQUIRE(group->children.size() == 1);
            const auto *binary = requireBinary(&group->children[0], "=>");
            requireToken(binary->left.get(), "others");
            requireToken(binary->right.get(), "'0'");
        } else {
            const auto *binary = requireBinary(expr, "=>");
            requireToken(binary->left.get(), "others");
            requireToken(binary->right.get(), "'0'");
        }
    }

    SECTION("(0 => '1', others => '0')")
    {
        const auto *expr = parseExpr("std_logic_vector(7 downto 0)", "(0 => '1', others => '0')");

        const auto *group = requireGroup(expr, 2);

        const auto *first = requireBinary(&group->children[0], "=>");
        requireToken(first->left.get(), "0");
        requireToken(first->right.get(), "'1'");

        const auto *second = requireBinary(&group->children[1], "=>");
        requireToken(second->left.get(), "others");
        requireToken(second->right.get(), "'0'");
    }
}

TEST_CASE("GroupExpr: Mixed positional and named", "[expressions][group][mixed]")
{
    SECTION("Positional element in aggregate")
    {
        const auto *expr = parseExpr("std_logic_vector(7 downto 0)", "(x\"AB\")");

        const auto *paren = std::get_if<ast::ParenExpr>(expr);
        REQUIRE(paren != nullptr);

        // Single positional element is not a GroupExpr
        requireToken(paren->inner.get(), "x\"AB\"");
    }
}

TEST_CASE("GroupExpr: Nested aggregates", "[expressions][group][nested]")
{
    SECTION("((1, 2), (3, 4))")
    {
        const auto *expr = parseExpr("matrix_type", "((1, 2), (3, 4))");

        const auto *outer_group = requireGroup(expr, 2);

        // First element: (1, 2)
        const auto *first_group = requireGroup(&outer_group->children[0], 2);
        requireToken(&first_group->children[0], "1");
        requireToken(&first_group->children[1], "2");

        // Second element: (3, 4)
        const auto *second_group = requireGroup(&outer_group->children[1], 2);
        requireToken(&second_group->children[0], "3");
        requireToken(&second_group->children[1], "4");
    }
}
