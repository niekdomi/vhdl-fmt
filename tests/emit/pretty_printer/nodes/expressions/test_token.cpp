#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("TokenExpr Rendering", "[pretty_printer][expressions][token]")
{
    SECTION("Integer literal")
    {
        const ast::TokenExpr token{.text = "42"};
        REQUIRE(emit::test::render(token) == "42");
    }

    SECTION("Bit string literal")
    {
        const ast::TokenExpr token{.text = "x\"NICE\""};
        REQUIRE(emit::test::render(token) == "x\"NICE\"");
    }

    SECTION("Identifier")
    {
        const ast::TokenExpr token{.text = "my_signal"};
        REQUIRE(emit::test::render(token) == "my_signal");
    }
}
