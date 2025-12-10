#include "ast/nodes/statements.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("For Loop Rendering", "[pretty_printer][statements][loop]")
{
    ast::ForLoop loop;
    loop.iterator = "i";
    loop.range = ast::TokenExpr{ .text = "0 to 7" };
    loop.body.emplace_back(ast::NullStatement{});

    SECTION("Basic For Loop")
    {
        constexpr auto EXPECTED = "for i in 0 to 7 loop\n  null;\nend loop;";
        REQUIRE(emit::test::render(loop) == EXPECTED);
    }
}
