#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Port: Single input port", "[declarations][port]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic);
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->port_clause.ports.size() == 1);

    const auto &port = entity->port_clause.ports[0];
    REQUIRE(port.names.size() == 1);
    REQUIRE(port.names[0] == "clk");
    REQUIRE(port.mode == "in");
    REQUIRE(port.type_name == "std_logic");
}

TEST_CASE("Port: Single output port", "[declarations][port]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (valid : out std_logic);
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->port_clause.ports.size() == 1);

    const auto &port = entity->port_clause.ports[0];
    REQUIRE(port.names[0] == "valid");
    REQUIRE(port.mode == "out");
    REQUIRE(port.type_name == "std_logic");
}

TEST_CASE("Port: Multiple ports same declaration", "[declarations][port]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk, rst, enable : in std_logic);
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->port_clause.ports.size() == 1);

    const auto &port = entity->port_clause.ports[0];
    REQUIRE(port.names.size() == 3);
    REQUIRE(port.names[0] == "clk");
    REQUIRE(port.names[1] == "rst");
    REQUIRE(port.names[2] == "enable");
    REQUIRE(port.mode == "in");
}
