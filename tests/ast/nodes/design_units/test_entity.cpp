#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("Entity", "[design_units][entity]")
{
    auto parse_entity = test_helpers::parseDesignUnit<ast::Entity>;

    SECTION("Basic entity with ports and generics")
    {
        const auto *entity = parse_entity(R"(
            entity MyEntity is
                generic (WIDTH : integer := 8);
                port (clk : in std_logic; data : out std_logic_vector(7 downto 0));
            end MyEntity;
        )");
        REQUIRE(entity != nullptr);
        CHECK(entity->name == "MyEntity");
        CHECK(entity->end_label.value_or("") == "MyEntity");

        // Generics
        REQUIRE(entity->generic_clause.generics.size() == 1);
        const auto &g1 = entity->generic_clause.generics[0];
        CHECK(g1.names[0] == "WIDTH");
        CHECK(g1.subtype.type_mark == "integer");
        
        REQUIRE(g1.default_expr.has_value());
        CHECK(std::get<ast::TokenExpr>(*g1.default_expr).text == "8");

        // Ports
        REQUIRE(entity->port_clause.ports.size() == 2);
        
        // Port 1: clk
        const auto &p1 = entity->port_clause.ports[0];
        CHECK(p1.names[0] == "clk");
        CHECK(p1.mode == "in");
        CHECK(p1.subtype.type_mark == "std_logic");

        // Port 2: data
        const auto &p2 = entity->port_clause.ports[1];
        CHECK(p2.names[0] == "data");
        CHECK(p2.mode == "out");
        CHECK(p2.subtype.type_mark == "std_logic_vector");
        
        REQUIRE(p2.subtype.constraint.has_value());
        const auto *idx_cstr = std::get_if<ast::IndexConstraint>(&*p2.subtype.constraint);
        REQUIRE(idx_cstr != nullptr);
        REQUIRE(idx_cstr->ranges.children.size() == 1);
        
        const auto *range = std::get_if<ast::BinaryExpr>(idx_cstr->ranges.children.data());
        REQUIRE(range != nullptr);
        CHECK(std::get<ast::TokenExpr>(*range->left).text == "7");
        CHECK(range->op == "downto");
        CHECK(std::get<ast::TokenExpr>(*range->right).text == "0");
    }

    SECTION("Multiple generics")
    {
        const auto *entity = parse_entity(R"(
            entity Counter is
                generic (
                    WIDTH : integer := 8;
                    RESET_VAL : integer := 0;
                    ENABLE_ASYNC : boolean := false
                );
                port (clk : in std_logic);
            end Counter;
        )");
        REQUIRE(entity != nullptr);
        
        REQUIRE(entity->generic_clause.generics.size() == 3);
        
        // Check types and default values
        CHECK(entity->generic_clause.generics[0].names[0] == "WIDTH");
        CHECK(entity->generic_clause.generics[0].subtype.type_mark == "integer");
        
        CHECK(entity->generic_clause.generics[1].names[0] == "RESET_VAL");
        CHECK(std::get<ast::TokenExpr>(*entity->generic_clause.generics[1].default_expr).text == "0");
        
        CHECK(entity->generic_clause.generics[2].names[0] == "ENABLE_ASYNC");
        CHECK(entity->generic_clause.generics[2].subtype.type_mark == "boolean");
        CHECK(std::get<ast::TokenExpr>(*entity->generic_clause.generics[2].default_expr).text == "false");
    }

    SECTION("Minimal entity")
    {
        const auto *entity = parse_entity(R"(
            entity MinimalEntity is
            end MinimalEntity;
        )");
        REQUIRE(entity != nullptr);
        CHECK(entity->name == "MinimalEntity");
        CHECK(entity->generic_clause.generics.empty());
        CHECK(entity->port_clause.ports.empty());
    }
}
