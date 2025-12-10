#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string>
#include <utility>
#include <vector>

namespace {

auto makeGeneric(std::string name, std::string type, std::string def_val) -> ast::GenericParam
{
    return ast::GenericParam{ .names = { std::move(name) },
                              .subtype = ast::SubtypeIndication{ .type_mark = std::move(type) },
                              .default_expr = ast::TokenExpr{ .text = std::move(def_val) } };
}

} // namespace

TEST_CASE("GenericParam Rendering", "[pretty_printer][declarations]")
{
    ast::GenericParam param{ .subtype{ .type_mark = "integer" } };

    SECTION("Basic Declarations")
    {
        SECTION("Single Name")
        {
            param.names = { "WIDTH" };
            REQUIRE(emit::test::render(param) == "WIDTH : integer");
        }

        SECTION("Multiple Names")
        {
            param.names = { "WIDTH", "HEIGHT", "DEPTH" };
            param.subtype = ast::SubtypeIndication{ .type_mark = "positive" }; // Override type
            REQUIRE(emit::test::render(param) == "WIDTH, HEIGHT, DEPTH : positive");
        }
    }

    SECTION("With Default Values")
    {
        SECTION("Single Name with Default")
        {
            param.names = { "WIDTH" };
            param.default_expr = ast::TokenExpr{ .text = "8" };
            REQUIRE(emit::test::render(param) == "WIDTH : integer := 8");
        }

        SECTION("Multiple Names with Default")
        {
            param.names = { "A", "B" };
            param.subtype = ast::SubtypeIndication{ .type_mark = "natural" };
            param.default_expr = ast::TokenExpr{ .text = "0" };
            REQUIRE(emit::test::render(param) == "A, B : natural := 0");
        }
    }
}

TEST_CASE("GenericClause Rendering", "[pretty_printer][clauses][generic]")
{
    ast::GenericClause clause{};

    SECTION("Empty Clause")
    {
        REQUIRE(emit::test::render(clause).empty());
    }

    SECTION("Single Parameter")
    {
        clause.generics.push_back(makeGeneric("WIDTH", "integer", "8"));
        REQUIRE(emit::test::render(clause) == "generic ( WIDTH : integer := 8 );");
    }

    SECTION("Multiple Parameters")
    {
        clause.generics.push_back(makeGeneric("WIDTH", "positive", "8"));
        clause.generics.push_back(makeGeneric("HEIGHT", "positive", "16"));

        REQUIRE(emit::test::render(clause)
                == "generic ( WIDTH : positive := 8; HEIGHT : positive := 16 );");
    }
}
