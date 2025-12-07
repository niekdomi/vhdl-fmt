#include "ast/nodes/declarations.hpp"
#include "decl_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("Declaration: Component", "[builder][decl][component]")
{
    SECTION("Simple Component")
    {
        const auto *decl
          = decl_utils::parse<ast::ComponentDecl>("component my_comp is end component;");
        REQUIRE(decl != nullptr);
        REQUIRE(decl->name == "my_comp");
        REQUIRE(decl->has_is_keyword == true);
    }

    SECTION("Component with Generics")
    {
        const auto *decl
          = decl_utils::parse<ast::ComponentDecl>("component adder is\n"
                                                  "  generic(WIDTH : integer := 32);\n"
                                                  "end component;");
        REQUIRE(decl != nullptr);

        const auto &generics = decl->generic_clause.generics;
        REQUIRE(generics.size() == 1);

        const auto &g0 = generics[0];
        REQUIRE(g0.names.size() == 1);
        REQUIRE(g0.names[0] == "WIDTH");
        REQUIRE(g0.subtype.type_mark == "integer");
        REQUIRE(g0.default_expr.has_value());
    }

    SECTION("Component with Ports")
    {
        const auto *decl
          = decl_utils::parse<ast::ComponentDecl>("component mux is\n"
                                                  "  port(\n"
                                                  "    sel : in std_logic;\n"
                                                  "    d_in : in std_logic_vector(3 downto 0);\n"
                                                  "    d_out : out std_logic\n"
                                                  "  );\n"
                                                  "end component;");
        REQUIRE(decl != nullptr);

        const auto &ports = decl->port_clause.ports;
        REQUIRE(ports.size() == 3);

        // Port 0
        REQUIRE(ports[0].names[0] == "sel");
        REQUIRE(ports[0].mode == "in");
        REQUIRE(ports[0].subtype.type_mark == "std_logic");

        // Port 1 (with constraint)
        REQUIRE(ports[1].names[0] == "d_in");
        REQUIRE(ports[1].mode == "in");
        REQUIRE(ports[1].subtype.type_mark == "std_logic_vector");
        REQUIRE(ports[1].subtype.constraint.has_value());

        // Port 2
        REQUIRE(ports[2].names[0] == "d_out");
        REQUIRE(ports[2].mode == "out");
    }
}
