#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("PhysicalLiteral Rendering", "[pretty_printer][expressions][physical]")
{
    SECTION("Integer with time unit")
    {
        const ast::PhysicalLiteral lit{.value = "10", .unit = "ns"};
        REQUIRE(emit::test::render(lit) == "10 ns");
    }

    SECTION("Decimal with time unit")
    {
        const ast::PhysicalLiteral lit{.value = "2.5", .unit = "us"};
        REQUIRE(emit::test::render(lit) == "2.5 us");
    }

    SECTION("Different units")
    {
        const ast::PhysicalLiteral lit{.value = "100", .unit = "MHz"};
        REQUIRE(emit::test::render(lit) == "100 MHz");
    }
}
