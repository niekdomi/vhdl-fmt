#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <utility>

TEST_CASE("Entity Rendering", "[pretty_printer][design_units][entity]")
{
    // Common setup for all sections
    ast::Entity entity{ .name = "test_unit" };

    SECTION("Header Definitions")
    {
        SECTION("Minimal (No Generics, No Ports)")
        {
            const std::string result = emit::test::render(entity);
            constexpr std::string_view EXPECTED = "entity test_unit is\n"
                                                  "end;";
            REQUIRE(result == EXPECTED);
        }

        SECTION("Generics Only")
        {
            ast::GenericParam param{ .names = { "WIDTH" },
                                     .subtype = ast::SubtypeIndication{ .type_mark = "positive" },
                                     .default_expr = ast::TokenExpr{ .text = "8" } };
            entity.generic_clause.generics.emplace_back(std::move(param));

            const std::string result = emit::test::render(entity);
            constexpr std::string_view EXPECTED = "entity test_unit is\n"
                                                  "  generic ( WIDTH : positive := 8 );\n"
                                                  "end;";
            REQUIRE(result == EXPECTED);
        }

        SECTION("Ports Only")
        {
            entity.port_clause.ports.emplace_back(
              ast::Port{ .names = { "clk" },
                         .mode = "in",
                         .subtype = ast::SubtypeIndication{ .type_mark = "std_logic" } });
            entity.port_clause.ports.emplace_back(
              ast::Port{ .names = { "count" },
                         .mode = "out",
                         .subtype = ast::SubtypeIndication{ .type_mark = "natural" } });

            const std::string result = emit::test::render(entity);
            constexpr std::string_view EXPECTED
              = "entity test_unit is\n"
                "  port ( clk : in std_logic; count : out natural );\n"
                "end;";
            REQUIRE(result == EXPECTED);
        }

        SECTION("Generics and Ports with Constraints")
        {
            // Generic
            entity.generic_clause.generics.emplace_back(
              ast::GenericParam{ .names = { "DEPTH" },
                                 .subtype = ast::SubtypeIndication{ .type_mark = "positive" },
                                 .default_expr = ast::TokenExpr{ .text = "16" } });

            // Port Constraint Construction
            auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "7" });
            auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });
            ast::IndexConstraint idx_constraint;
            idx_constraint.ranges.children.emplace_back(ast::BinaryExpr{
              .left = std::move(left), .op = "downto", .right = std::move(right) });

            // Port
            entity.port_clause.ports.emplace_back(ast::Port{
              .names = { "data_in" },
              .mode = "in",
              .subtype = ast::SubtypeIndication{ .type_mark = "std_logic_vector",
                        .constraint
                                                 = ast::Constraint(std::move(idx_constraint)) }
            });

            const std::string result = emit::test::render(entity);
            constexpr std::string_view EXPECTED
              = "entity test_unit is\n"
                "  generic ( DEPTH : positive := 16 );\n"
                "  port ( data_in : in std_logic_vector(7 downto 0) );\n"
                "end;";
            REQUIRE(result == EXPECTED);
        }
    }

    SECTION("End Syntax Variations")
    {
        SECTION("Minimal: end;")
        {
            entity.has_end_entity_keyword = false;
            entity.end_label = std::nullopt;

            REQUIRE(emit::test::render(entity) == "entity test_unit is\nend;");
        }

        SECTION("Keyword Only: end entity;")
        {
            entity.has_end_entity_keyword = true;
            entity.end_label = std::nullopt;

            REQUIRE(emit::test::render(entity) == "entity test_unit is\nend entity;");
        }

        SECTION("Label Only: end <name>;")
        {
            entity.has_end_entity_keyword = false;
            entity.end_label = "test_unit";

            REQUIRE(emit::test::render(entity) == "entity test_unit is\nend test_unit;");
        }

        SECTION("Full: end entity <name>;")
        {
            entity.has_end_entity_keyword = true;
            entity.end_label = "test_unit";

            REQUIRE(emit::test::render(entity) == "entity test_unit is\nend entity test_unit;");
        }
    }
}

TEST_CASE("Entity with Context Clauses", "[pretty_printer][design_units][context]")
{
    SECTION("Entity with library clause")
    {
        ast::Entity entity{ .name = "test_unit" };
        entity.context.emplace_back(ast::LibraryClause{ .logical_names = { "ieee" } });

        const std::string result = emit::test::render(entity);
        constexpr std::string_view EXPECTED = "library ieee;\n"
                                              "entity test_unit is\n"
                                              "end;";
        REQUIRE(result == EXPECTED);
    }

    SECTION("Entity with library and use clauses")
    {
        ast::Entity entity{ .name = "test_unit" };
        entity.context.emplace_back(ast::LibraryClause{ .logical_names = { "ieee" } });
        entity.context.emplace_back(
          ast::UseClause{ .selected_names = { "ieee.std_logic_1164.all" } });
        entity.context.emplace_back(ast::UseClause{ .selected_names = { "ieee.numeric_std.all" } });

        const std::string result = emit::test::render(entity);
        constexpr std::string_view EXPECTED = "library ieee;\n"
                                              "use ieee.std_logic_1164.all;\n"
                                              "use ieee.numeric_std.all;\n"
                                              "entity test_unit is\n"
                                              "end;";
        REQUIRE(result == EXPECTED);
    }

    SECTION("Entity with multiple libraries")
    {
        ast::Entity entity{ .name = "test_unit" };
        entity.context.emplace_back(ast::LibraryClause{ .logical_names = { "ieee" } });
        entity.context.emplace_back(
          ast::UseClause{ .selected_names = { "ieee.std_logic_1164.all" } });
        entity.context.emplace_back(ast::LibraryClause{ .logical_names = { "work" } });
        entity.port_clause.ports.emplace_back(
          ast::Port{ .names = { "clk" },
                     .mode = "in",
                     .subtype = ast::SubtypeIndication{ .type_mark = "std_logic" } });

        const std::string result = emit::test::render(entity);
        constexpr std::string_view EXPECTED = "library ieee;\n"
                                              "use ieee.std_logic_1164.all;\n"
                                              "library work;\n"
                                              "entity test_unit is\n"
                                              "  port ( clk : in std_logic );\n"
                                              "end;";
        REQUIRE(result == EXPECTED);
    }
}
