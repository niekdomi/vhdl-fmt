#include "ast/nodes/statements.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("While Loop Rendering", "[pretty_printer][statements][loop]")
{
    ast::WhileLoop loop;
    loop.condition = ast::TokenExpr{ .text = "enabled" };
    loop.body.emplace_back(ast::NullStatement{});

    SECTION("Basic While Loop")
    {
        constexpr auto EXPECTED = "while enabled loop\n  null;\nend loop;";
        REQUIRE(emit::test::render(loop) == EXPECTED);
    }
}
