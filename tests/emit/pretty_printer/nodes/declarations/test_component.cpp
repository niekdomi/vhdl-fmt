#include "ast/nodes/declarations.hpp"
#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string>
#include <string_view>
#include <utility>

namespace {
// Helper to reduce boilerplate for generics and ports
auto makeGeneric(std::string name, std::string type, std::string def_val) -> ast::GenericParam
{
    return ast::GenericParam{ .names = { std::move(name) },
                              .subtype = ast::SubtypeIndication{ .type_mark = std::move(type) },
                              .default_expr = ast::TokenExpr{ .text = std::move(def_val) } };
}

auto makePort(std::string name, std::string mode, std::string type) -> ast::Port
{
    return ast::Port{ .names = { std::move(name) },
                      .mode = std::move(mode),
                      .subtype = ast::SubtypeIndication{ .type_mark = std::move(type) } };
}
} // namespace

TEST_CASE("ComponentDecl Rendering", "[pretty_printer][component]")
{
    // Shared setup
    ast::ComponentDecl comp{ .name = "my_comp" };

    SECTION("Minimal (No Generics, No Ports)")
    {
        SECTION("Basic")
        {
            const std::string result = emit::test::render(comp);
            constexpr std::string_view EXPECTED = "component my_comp\n"
                                                  "end component;";
            REQUIRE(result == EXPECTED);
        }

        SECTION("With 'IS' keyword")
        {
            comp.has_is_keyword = true;
            const std::string result = emit::test::render(comp);
            constexpr std::string_view EXPECTED = "component my_comp is\n"
                                                  "end component;";
            REQUIRE(result == EXPECTED);
        }

        SECTION("With End Label")
        {
            comp.end_label = "my_comp";
            const std::string result = emit::test::render(comp);
            constexpr std::string_view EXPECTED = "component my_comp\n"
                                                  "end component my_comp;";
            REQUIRE(result == EXPECTED);
        }
    }

    SECTION("With Interface Lists")
    {
        SECTION("Generic Clause Only")
        {
            comp.generic_clause.generics.push_back(makeGeneric("WIDTH", "integer", "8"));

            const std::string result = emit::test::render(comp);
            constexpr std::string_view EXPECTED = "component my_comp\n"
                                                  "  generic ( WIDTH : integer := 8 );\n"
                                                  "end component;";
            REQUIRE(result == EXPECTED);
        }

        SECTION("Port Clause Only")
        {
            comp.port_clause.ports.push_back(makePort("clk", "in", "std_logic"));

            const std::string result = emit::test::render(comp);
            constexpr std::string_view EXPECTED = "component my_comp\n"
                                                  "  port ( clk : in std_logic );\n"
                                                  "end component;";
            REQUIRE(result == EXPECTED);
        }

        SECTION("Both Generics and Ports")
        {
            comp.has_is_keyword = true;
            comp.generic_clause.generics.push_back(makeGeneric("N", "positive", "16"));
            comp.port_clause.ports.push_back(makePort("rst", "in", "std_logic"));

            const std::string result = emit::test::render(comp);
            constexpr std::string_view EXPECTED = "component my_comp is\n"
                                                  "  generic ( N : positive := 16 );\n"
                                                  "  port ( rst : in std_logic );\n"
                                                  "end component;";
            REQUIRE(result == EXPECTED);
        }
    }
}