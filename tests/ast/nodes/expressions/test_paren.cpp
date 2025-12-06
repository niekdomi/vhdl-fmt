#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

using namespace test_helpers;

TEST_CASE("ParenExpr: Simple parenthesized expressions", "[expressions][paren]")
{
    SECTION("(x)")
    {
        const auto *expr = parseExpr("integer", "(x)");
        const auto *paren = requireParen(expr);
        requireToken(paren->inner.get(), "x");
    }

    SECTION("(42)")
    {
        const auto *expr = parseExpr("integer", "(42)");
        const auto *paren = requireParen(expr);
        requireToken(paren->inner.get(), "42");
    }

    SECTION("('1')")
    {
        const auto *expr = parseExpr("std_logic", "('1')");
        const auto *paren = requireParen(expr);
        requireToken(paren->inner.get(), "'1'");
    }
}

TEST_CASE("ParenExpr: Precedence control", "[expressions][paren][precedence]")
{
    SECTION("(a + b) * c - parentheses change precedence")
    {
        const auto *expr = parseExpr("integer", "(a + b) * c");
        const auto *outer = requireBinary(expr, "*");

        // Left side is a ParenExpr
        const auto *paren = requireParen(outer->left.get());
        const auto *inner = requireBinary(paren->inner.get(), "+");
        requireToken(inner->left.get(), "a");
        requireToken(inner->right.get(), "b");

        // Right side is a token
        requireToken(outer->right.get(), "c");
    }

    SECTION("a * (b + c)")
    {
        const auto *expr = parseExpr("integer", "a * (b + c)");
        const auto *outer = requireBinary(expr, "*");

        requireToken(outer->left.get(), "a");

        const auto *paren = requireParen(outer->right.get());
        const auto *inner = requireBinary(paren->inner.get(), "+");
        requireToken(inner->left.get(), "b");
        requireToken(inner->right.get(), "c");
    }

    SECTION("(a and b) or c")
    {
        const auto *expr = parseExpr("boolean", "(a and b) or c");
        const auto *outer = requireBinary(expr, "or");

        const auto *paren = requireParen(outer->left.get());
        const auto *inner = requireBinary(paren->inner.get(), "and");
        requireToken(inner->left.get(), "a");
        requireToken(inner->right.get(), "b");

        requireToken(outer->right.get(), "c");
    }
}

TEST_CASE("ParenExpr: Nested parentheses", "[expressions][paren][nested]")
{
    SECTION("((x))")
    {
        const auto *expr = parseExpr("integer", "((x))");
        const auto *outer_paren = requireParen(expr);
        const auto *inner_paren = requireParen(outer_paren->inner.get());
        requireToken(inner_paren->inner.get(), "x");
    }

    SECTION("((a + b) * (c + d))")
    {
        const auto *expr = parseExpr("integer", "((a + b) * (c + d))");
        const auto *outer_paren = requireParen(expr);

        const auto *mult = requireBinary(outer_paren->inner.get(), "*");

        // Left: (a + b)
        const auto *left_paren = requireParen(mult->left.get());
        const auto *left_add = requireBinary(left_paren->inner.get(), "+");
        requireToken(left_add->left.get(), "a");
        requireToken(left_add->right.get(), "b");

        // Right: (c + d)
        const auto *right_paren = requireParen(mult->right.get());
        const auto *right_add = requireBinary(right_paren->inner.get(), "+");
        requireToken(right_add->left.get(), "c");
        requireToken(right_add->right.get(), "d");
    }
}

TEST_CASE("ParenExpr: Clarity parentheses", "[expressions][paren][clarity]")
{
    SECTION("(a) + (b)")
    {
        const auto *expr = parseExpr("integer", "(a) + (b)");
        const auto *binary = requireBinary(expr, "+");

        const auto *left_paren = requireParen(binary->left.get());
        requireToken(left_paren->inner.get(), "a");

        const auto *right_paren = requireParen(binary->right.get());
        requireToken(right_paren->inner.get(), "b");
    }
}
