#include "ast/nodes/statements/sequential.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("Infinite Loop Rendering", "[pretty_printer][statements][loop]")
{
    ast::Loop loop;
    loop.body.emplace_back(ast::NullStatement{});

    SECTION("Simple Loop")
    {
        constexpr auto EXPECTED = "loop\n  null;\nend loop;";
        REQUIRE(emit::test::render(loop) == EXPECTED);
    }

    SECTION("Labeled Loop")
    {
        loop.label = "main_loop";
        constexpr auto EXPECTED = "main_loop: loop\n  null;\nend loop;";
        REQUIRE(emit::test::render(loop) == EXPECTED);
    }
}
