#include "ast/nodes/design_units.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("Entity", "[design_units][entity]")
{
    auto parse_entity = test_helpers::parseDesignUnit<ast::Entity>;

    SECTION("Minimal Entity (Structure)")
    {
        const auto *entity = parse_entity("entity Minimal is end Minimal;");
        REQUIRE(entity != nullptr);
        
        CHECK(entity->name == "Minimal");
        CHECK_FALSE(entity->has_end_entity_keyword);
        CHECK(entity->end_label.value_or("") == "Minimal");
        
        CHECK(entity->generic_clause.generics.empty());
        CHECK(entity->port_clause.ports.empty());
    }

    SECTION("Entity with 'end entity' keyword")
    {
        const auto *entity = parse_entity("entity KW_Test is end entity;");
        REQUIRE(entity != nullptr);
        
        CHECK(entity->name == "KW_Test");
        CHECK(entity->has_end_entity_keyword);
        CHECK_FALSE(entity->end_label.has_value());
    }

    SECTION("Entity with Interface Lists (Container Check)")
    {
        // Verify that the entity parser correctly captures the clauses.
        const auto *entity = parse_entity(R"(
            entity InterfaceTest is
                generic (G : integer);
                port (clk : in bit);
            end InterfaceTest;
        )");
        REQUIRE(entity != nullptr);

        // Verify Generic Clause presence
        REQUIRE(entity->generic_clause.generics.size() == 1);
        CHECK(entity->generic_clause.generics[0].names[0] == "G");

        // Verify Port Clause presence
        REQUIRE(entity->port_clause.ports.size() == 1);
        CHECK(entity->port_clause.ports[0].names[0] == "clk");
    }
}