#include "ast/nodes/declarations/objects.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("Constant Declaration Rendering", "[pretty_printer][declarations][objects]")
{
    ast::ConstantDecl cst{ .names = { "WIDTH" },
                           .subtype = ast::SubtypeIndication{ .type_mark = "integer" },
                           .init_expr = ast::TokenExpr{ .text = "8" } };

    SECTION("Basic Constant")
    {
        REQUIRE(emit::test::render(cst) == "constant WIDTH : integer := 8;");
    }

    SECTION("Multiple Constants")
    {
        cst.names = { "MIN", "MAX" };
        REQUIRE(emit::test::render(cst) == "constant MIN, MAX : integer := 8;");
    }
}
