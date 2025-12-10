#include "ast/nodes/declarations/objects.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("Variable Declaration Rendering", "[pretty_printer][declarations][objects]")
{
    ast::VariableDecl var;
    var.names = { "counter" };
    var.subtype = ast::SubtypeIndication{ .type_mark = "integer" };

    SECTION("Standard Variable")
    {
        REQUIRE(emit::test::render(var) == "variable counter : integer;");
    }

    SECTION("Shared Variable")
    {
        var.shared = true;
        REQUIRE(emit::test::render(var) == "shared variable counter : integer;");
    }

    SECTION("With Initialization")
    {
        var.init_expr = ast::TokenExpr{ .text = "0" };
        REQUIRE(emit::test::render(var) == "variable counter : integer := 0;");
    }
}
