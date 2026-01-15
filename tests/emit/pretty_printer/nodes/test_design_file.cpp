#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

TEST_CASE("DesignFile Rendering", "[pretty_printer][design_file]")
{
    ast::DesignFile file{};

    SECTION("Empty File")
    {
        const auto result = emit::test::render(file);
        REQUIRE(result.empty());
    }

    SECTION("Single Unit")
    {
        SECTION("Entity only")
        {
            file.units.emplace_back(ast::Entity{
              .context = {},
              .name = "test_entity",
              .generic_clause = {},
              .port_clause = {},
              .decls = {},
              .stmts = {},
              // Simulate default behavior where end label matches name if not explicitly cleared
              .end_label = "test_entity",
              .has_end_entity_keyword = true});

            const std::string result = emit::test::render(file);
            const std::string_view expected = "entity test_entity is\n" "end entity test_entity;\n";
            REQUIRE(result == expected);
        }

        SECTION("Architecture only")
        {
            file.units.emplace_back(ast::Architecture{.context = {},
                                                      .name = "rtl",
                                                      .entity_name = "processor",
                                                      .decls = {},
                                                      .stmts = {},
                                                      .end_label = "rtl",
                                                      .has_end_architecture_keyword = true});

            const std::string result = emit::test::render(file);
            const std::string_view expected =
              "architecture rtl of processor is\n" "begin\n" "end architecture rtl;\n";
            REQUIRE(result == expected);
        }
    }

    SECTION("Multiple Units")
    {
        SECTION("Entity and corresponding Architecture")
        {
            // 1. Entity
            ast::Entity entity{.context = {},
                               .name = "counter",
                               .generic_clause = {},
                               .port_clause = {},
                               .decls = {},
                               .stmts = {},
                               .end_label = std::nullopt,
                               .has_end_entity_keyword = false};
            entity.port_clause.ports.emplace_back(ast::Port{
              .names = {"clk"},
              .mode = "in",
              .subtype = ast::SubtypeIndication{.resolution_func = std::nullopt,
                        .type_mark = "std_logic",
                        .constraint = std::nullopt},
              .default_expr = std::nullopt
            });
            entity.end_label = "counter";
            entity.has_end_entity_keyword = true;

            // 2. Architecture
            ast::Architecture arch{.context = {},
                                   .name = "rtl",
                                   .entity_name = "counter",
                                   .decls = {},
                                   .stmts = {},
                                   .end_label = "rtl",
                                   .has_end_architecture_keyword = true};

            file.units.emplace_back(std::move(entity));
            file.units.emplace_back(std::move(arch));

            const std::string result = emit::test::render(file);
            const std::string_view expected =
              "entity counter is\n" "  port ( clk : in std_logic );\n" "end entity counter;\n" "architecture rtl of counter is\n" "begin\n" "end architecture rtl;\n";
            REQUIRE(result == expected);
        }

        SECTION("Multiple independent entities and architectures")
        {
            // Entity 1
            file.units.emplace_back(ast::Entity{.context = {},
                                                .name = "entity1",
                                                .generic_clause = {},
                                                .port_clause = {},
                                                .decls = {},
                                                .stmts = {},
                                                .end_label = "entity1",
                                                .has_end_entity_keyword = true});

            // Entity 2
            file.units.emplace_back(ast::Entity{.context = {},
                                                .name = "entity2",
                                                .generic_clause = {},
                                                .port_clause = {},
                                                .decls = {},
                                                .stmts = {},
                                                .end_label = "entity2",
                                                .has_end_entity_keyword = true});

            // Arch for Entity 1
            file.units.emplace_back(ast::Architecture{.context = {},
                                                      .name = "behavioral",
                                                      .entity_name = "entity1",
                                                      .decls = {},
                                                      .stmts = {},
                                                      .end_label = "behavioral",
                                                      .has_end_architecture_keyword = true});

            const std::string result = emit::test::render(file);
            const std::string_view expected =
              "entity entity1 is\n" "end entity entity1;\n" "entity entity2 is\n" "end entity entity2;\n" "architecture behavioral of entity1 is\n" "begin\n" "end architecture behavioral;\n";
            REQUIRE(result == expected);
        }
    }
}
