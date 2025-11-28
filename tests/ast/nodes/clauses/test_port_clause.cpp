#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("PortClause: Single port", "[clauses][port]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (
                clk : in std_logic
            );
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.port_clause.ports.size() == 1);
    REQUIRE(entity.port_clause.ports[0].names[0] == "clk");
    REQUIRE(entity.port_clause.ports[0].mode == "in");
    REQUIRE(entity.port_clause.ports[0].type_name == "std_logic");
}

TEST_CASE("PortClause: Multiple ports with different modes", "[clauses][port]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (
                clk : in std_logic;
                reset : in std_logic;
                data_out : out std_logic_vector(7 downto 0);
                enable : inout std_logic
            );
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.port_clause.ports.size() == 4);
    REQUIRE(entity.port_clause.ports[0].names[0] == "clk");
    REQUIRE(entity.port_clause.ports[0].mode == "in");
    REQUIRE(entity.port_clause.ports[1].names[0] == "reset");
    REQUIRE(entity.port_clause.ports[2].names[0] == "data_out");
    REQUIRE(entity.port_clause.ports[2].mode == "out");
    REQUIRE(entity.port_clause.ports[3].mode == "inout");
}
