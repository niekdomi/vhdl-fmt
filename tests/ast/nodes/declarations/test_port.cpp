#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Port: Single input port", "[declarations][port]")
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

    const auto &port = entity.port_clause.ports[0];
    REQUIRE(port.names.size() == 1);
    REQUIRE(port.names[0] == "clk");
    REQUIRE(port.mode == "in");
    REQUIRE(port.type_name == "std_logic");
    REQUIRE_FALSE(port.default_expr.has_value());
}

TEST_CASE("Port: Multiple names in single port declaration", "[declarations][port]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (
                a, b, c : in std_logic
            );
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.port_clause.ports.size() == 1);

    const auto &port = entity.port_clause.ports[0];
    REQUIRE(port.names.size() == 3);
    REQUIRE(port.names[0] == "a");
    REQUIRE(port.names[1] == "b");
    REQUIRE(port.names[2] == "c");
    REQUIRE(port.mode == "in");
    REQUIRE(port.type_name == "std_logic");
}

TEST_CASE("Port: Output port with vector type and constraint", "[declarations][port]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (
                data : out std_logic_vector(7 downto 0)
            );
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.port_clause.ports.size() == 1);

    const auto &port = entity.port_clause.ports[0];
    REQUIRE(port.names.size() == 1);
    REQUIRE(port.names[0] == "data");
    REQUIRE(port.mode == "out");
    REQUIRE(port.type_name == "std_logic_vector");
    REQUIRE(port.constraint.has_value());
}
