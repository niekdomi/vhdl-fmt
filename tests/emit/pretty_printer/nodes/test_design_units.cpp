#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"
#include "nodes/declarations.hpp"

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
                                     .type_name = "positive",
                                     .default_expr = ast::TokenExpr{ .text = "8" },
                                     .is_last = true };
            entity.generic_clause.generics.emplace_back(std::move(param));

            const std::string result = emit::test::render(entity);
            constexpr std::string_view EXPECTED = "entity test_unit is\n"
                                                  "  generic ( WIDTH : positive := 8 );\n"
                                                  "end;";
            REQUIRE(result == EXPECTED);
        }

        SECTION("Ports Only")
        {
            entity.port_clause.ports.emplace_back(ast::Port{
              .names = { "clk" }, .mode = "in", .type_name = "std_logic", .is_last = false });
            entity.port_clause.ports.emplace_back(ast::Port{
              .names = { "count" }, .mode = "out", .type_name = "natural", .is_last = true });

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
                                 .type_name = "positive",
                                 .default_expr = ast::TokenExpr{ .text = "16" },
                                 .is_last = true });

            // Port Constraint Construction
            auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "7" });
            auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });
            ast::IndexConstraint idx_constraint;
            idx_constraint.ranges.children.emplace_back(ast::BinaryExpr{
              .left = std::move(left), .op = "downto", .right = std::move(right) });

            // Port
            entity.port_clause.ports.emplace_back(
              ast::Port{ .names = { "data_in" },
                         .mode = "in",
                         .type_name = "std_logic_vector",
                         .constraint = ast::Constraint(std::move(idx_constraint)),
                         .is_last = true });

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

TEST_CASE("Architecture Rendering", "[pretty_printer][design_units][architecture]")
{
    // Common setup
    ast::Architecture arch{ .name = "rtl", .entity_name = "test_unit" };

    SECTION("Basic Structure")
    {
        const std::string result = emit::test::render(arch);
        constexpr std::string_view EXPECTED = "architecture rtl of test_unit is\n"
                                              "begin\n"
                                              "end;";
        REQUIRE(result == EXPECTED);
    }

    SECTION("End Syntax Variations")
    {
        SECTION("Minimal: end;")
        {
            arch.has_end_architecture_keyword = false;
            arch.end_label = std::nullopt;

            REQUIRE(emit::test::render(arch) == "architecture rtl of test_unit is\nbegin\nend;");
        }

        SECTION("Keyword Only: end architecture;")
        {
            arch.has_end_architecture_keyword = true;
            arch.end_label = std::nullopt;

            REQUIRE(emit::test::render(arch)
                    == "architecture rtl of test_unit is\nbegin\nend architecture;");
        }

        SECTION("Label Only: end <name>;")
        {
            arch.has_end_architecture_keyword = false;
            arch.end_label = "rtl";

            REQUIRE(emit::test::render(arch)
                    == "architecture rtl of test_unit is\nbegin\nend rtl;");
        }

        SECTION("Full: end architecture <name>;")
        {
            arch.has_end_architecture_keyword = true;
            arch.end_label = "rtl";

            REQUIRE(emit::test::render(arch)
                    == "architecture rtl of test_unit is\nbegin\nend architecture rtl;");
        }
    }
}
