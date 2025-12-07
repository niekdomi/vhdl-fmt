#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("TokenExpr Rendering", "[pretty_printer][expressions][token]")
{
    SECTION("Integer literal")
    {
        ast::TokenExpr token;
        token.text = "42";

        REQUIRE(emit::test::render(token) == "42");
    }

    SECTION("Bit string literal")
    {
        ast::TokenExpr token;
        token.text = "x\"DEADBEEF\"";

        REQUIRE(emit::test::render(token) == "x\"DEADBEEF\"");
    }

    SECTION("Identifier")
    {
        ast::TokenExpr token;
        token.text = "my_signal";

        REQUIRE(emit::test::render(token) == "my_signal");
    }
}
