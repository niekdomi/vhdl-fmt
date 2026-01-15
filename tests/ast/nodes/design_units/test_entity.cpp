#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Entity: Basic entity declaration with ports and generics", "[design_units][entity]")
{
    const std::string_view file = R"(
        entity MyEntity is
            generic (WIDTH : integer := 8);
            port (clk : in std_logic; data : out std_logic_vector(7 downto 0));
        end MyEntity;
    )";

    const auto design = builder::buildFromString(file);
    REQUIRE(design.units.size() == 1);

    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->name == "MyEntity");
    REQUIRE(entity->end_label.has_value());
    REQUIRE(entity->end_label.value() == "MyEntity");
    REQUIRE(entity->generic_clause.generics.size() == 1);
    REQUIRE(entity->port_clause.ports.size() == 2);
}

TEST_CASE("Entity: Multiple generics", "[design_units][entity]")
{
    const std::string_view file = R"(
        entity Counter is
            generic (
                WIDTH : integer := 8;
                RESET_VAL : integer := 0;
                ENABLE_ASYNC : boolean := false
            );
            port (clk : in std_logic);
        end Counter;
    )";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->generic_clause.generics.size() == 3);
    REQUIRE(entity->generic_clause.generics[0].names[0] == "WIDTH");
    REQUIRE(entity->generic_clause.generics[1].names[0] == "RESET_VAL");
    REQUIRE(entity->generic_clause.generics[2].names[0] == "ENABLE_ASYNC");
}

TEST_CASE("Entity: Minimal entity without ports or generics", "[design_units][entity]")
{
    const std::string_view file = R"(
        entity MinimalEntity is
        end MinimalEntity;
    )";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->name == "MinimalEntity");
    REQUIRE(entity->generic_clause.generics.empty());
    REQUIRE(entity->port_clause.ports.empty());
}
