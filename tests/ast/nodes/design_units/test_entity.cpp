#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Entity: Simple entity without ports or generics", "[design_units][entity]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity SimpleEntity is
        end SimpleEntity;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.name == "SimpleEntity");
    REQUIRE(entity.generic_clause.generics.empty());
    REQUIRE(entity.port_clause.ports.empty());
    REQUIRE(entity.decls.empty());
    REQUIRE(entity.stmts.empty());
}

TEST_CASE("Entity: Entity with ports", "[design_units][entity]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Counter is
            port (
                clk : in std_logic;
                reset : in std_logic;
                count : out integer
            );
        end Counter;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.name == "Counter");
    REQUIRE(entity.port_clause.ports.size() == 3);
    REQUIRE(entity.generic_clause.generics.empty());
}

TEST_CASE("Entity: Entity with generics and ports", "[design_units][entity]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity GenericEntity is
            generic (
                WIDTH : integer := 8;
                DEPTH : natural := 16
            );
            port (
                data_in : in std_logic_vector(WIDTH-1 downto 0);
                data_out : out std_logic_vector(WIDTH-1 downto 0)
            );
        end GenericEntity;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.name == "GenericEntity");
    REQUIRE(entity.generic_clause.generics.size() == 2);
    REQUIRE(entity.port_clause.ports.size() == 2);
}
