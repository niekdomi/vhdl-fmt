#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
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
            file.units.emplace_back(ast::DesignUnit{
              .unit = ast::Entity{
                                  .name = "test_entity",
                                  // Simulate default behavior where end label matches name if not explicitly cleared
                .end_label = "test_entity",
                                  .has_end_entity_keyword = true}
            });

            const std::string result = emit::test::render(file);
            const std::string_view expected = "entity test_entity is\n" "end entity test_entity;\n";
            REQUIRE(result == expected);
        }

        SECTION("Architecture only")
        {
            file.units.emplace_back(ast::DesignUnit{
              .unit = ast::Architecture{.name = "rtl",
                                        .entity_name = "processor",
                                        .end_label = "rtl",
                                        .has_end_architecture_keyword = true},
            });

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
            ast::Entity entity{.name = "counter"};
            entity.port_clause.ports.emplace_back(ast::Port{
              .names = {"clk"},
              .mode = "in",
              .subtype = ast::SubtypeIndication{.type_mark = "std_logic"},
            });
            entity.end_label = "counter";
            entity.has_end_entity_keyword = true;

            // 2. Architecture
            ast::Architecture arch{
              .name = "rtl",
              .entity_name = "counter",
              .end_label = "rtl",
              .has_end_architecture_keyword = true,
            };

            file.units.emplace_back(ast::DesignUnit{.unit = std::move(entity)});
            file.units.emplace_back(ast::DesignUnit{.unit = std::move(arch)});

            const std::string result = emit::test::render(file);
            const std::string_view expected =
              "entity counter is\n" "  port ( clk : in std_logic );\n" "end entity counter;\n" "architecture rtl of counter is\n" "begin\n" "end architecture rtl;\n";
            REQUIRE(result == expected);
        }

        SECTION("Multiple independent entities and architectures")
        {
            // Entity 1
            file.units.emplace_back(ast::DesignUnit{
              .unit = ast::Entity{
                                  .name = "entity1",
                                  .end_label = "entity1",
                                  .has_end_entity_keyword = true,
                                  }
            });

            // Entity 2
            file.units.emplace_back(ast::DesignUnit{
              .unit = ast::Entity{
                                  .name = "entity2",
                                  .end_label = "entity2",
                                  .has_end_entity_keyword = true,
                                  }
            });

            // Arch for Entity 1
            file.units.emplace_back(ast::DesignUnit{
              .unit = ast::Architecture{
                                        .name = "behavioral",
                                        .entity_name = "entity1",
                                        .end_label = "behavioral",
                                        .has_end_architecture_keyword = true,
                                        }
            });

            const std::string result = emit::test::render(file);
            const std::string_view expected =
              "entity entity1 is\n" "end entity entity1;\n" "entity entity2 is\n" "end entity entity2;\n" "architecture behavioral of entity1 is\n" "begin\n" "end architecture behavioral;\n";
            REQUIRE(result == expected);
        }
    }
}
