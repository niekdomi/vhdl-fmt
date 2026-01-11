#include "ast/nodes/declarations/objects.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("Signal Declaration Rendering", "[pretty_printer][declarations][objects]")
{
    ast::SignalDecl sig{ .names = { "clk" },
                         .subtype = ast::SubtypeIndication{ .type_mark = "std_logic" } };

    SECTION("Basic Signal")
    {
        REQUIRE(emit::test::render(sig) == "signal clk : std_logic;");
    }

    SECTION("Multiple Names")
    {
        sig.names = { "a", "b" };
        REQUIRE(emit::test::render(sig) == "signal a, b : std_logic;");
    }

    SECTION("With Initialization")
    {
        sig.init_expr = ast::TokenExpr{ .text = "'0'" };
        REQUIRE(emit::test::render(sig) == "signal clk : std_logic := '0';");
    }

    SECTION("With BUS Keyword")
    {
        sig.names = { "data_bus" };
        sig.has_bus_kw = true;
        REQUIRE(emit::test::render(sig) == "signal data_bus : std_logic bus;");
    }
}
