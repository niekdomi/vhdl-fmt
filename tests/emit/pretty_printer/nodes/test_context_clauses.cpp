#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <optional>
#include <string>
#include <string_view>

TEST_CASE("LibraryClause: Single library", "[pretty_printer][context][library]")
{
    const ast::LibraryClause lib_clause{.logical_names = {"ieee"}};

    const std::string result = emit::test::render(lib_clause);
    const std::string_view expected = "library ieee;";
    REQUIRE(result == expected);
}

TEST_CASE("LibraryClause: Multiple libraries in one clause", "[pretty_printer][context][library]")
{
    const ast::LibraryClause lib_clause{
      .logical_names = {"ieee", "std", "work"}
    };

    const std::string result = emit::test::render(lib_clause);
    const std::string_view expected = "library ieee, std, work;";
    REQUIRE(result == expected);
}

TEST_CASE("UseClause: Single use statement", "[pretty_printer][context][use]")
{
    const ast::UseClause use_clause{.selected_names = {"ieee.std_logic_1164.all"}};

    const std::string result = emit::test::render(use_clause);
    const std::string_view expected = "use ieee.std_logic_1164.all;";
    REQUIRE(result == expected);
}

TEST_CASE("UseClause: Multiple use statements in one clause", "[pretty_printer][context][use]")
{
    const ast::UseClause use_clause{
      .selected_names = {"ieee.std_logic_1164.all", "ieee.numeric_std.all"}
    };

    const std::string result = emit::test::render(use_clause);
    const std::string_view expected = "use ieee.std_logic_1164.all, ieee.numeric_std.all;";
    REQUIRE(result == expected);
}

TEST_CASE("Entity: With library clause", "[pretty_printer][context][entity]")
{
    ast::Entity entity{.context = {},
                       .name = "test_entity",
                       .generic_clause = {},
                       .port_clause = {},
                       .decls = {},
                       .stmts = {},
                       .end_label = std::nullopt,
                       .has_end_entity_keyword = false};
    entity.context.emplace_back(ast::LibraryClause{.logical_names = {"ieee"}});

    const std::string result = emit::test::render(entity);
    const std::string_view expected = "library ieee;\n" "entity test_entity is\n" "end;";
    REQUIRE(result == expected);
}

TEST_CASE("Entity: With library and use clauses", "[pretty_printer][context][entity]")
{
    ast::Entity entity{.context = {},
                       .name = "my_design",
                       .generic_clause = {},
                       .port_clause = {},
                       .decls = {},
                       .stmts = {},
                       .end_label = std::nullopt,
                       .has_end_entity_keyword = false};
    entity.context.emplace_back(ast::LibraryClause{.logical_names = {"ieee"}});
    entity.context.emplace_back(ast::UseClause{.selected_names = {"ieee.std_logic_1164.all"}});
    entity.context.emplace_back(ast::UseClause{.selected_names = {"ieee.numeric_std.all"}});

    entity.port_clause.ports.emplace_back(ast::Port{
      .names = {"clk"},
      .mode = "in",
      .subtype = ast::SubtypeIndication{.resolution_func = std::nullopt,
                .type_mark = "std_logic",
                .constraint = std::nullopt},
      .default_expr = std::nullopt
    });

    const std::string result = emit::test::render(entity);
    const std::string_view expected =
      "library ieee;\n" "use ieee.std_logic_1164.all;\n" "use ieee.numeric_std.all;\n" "entity my_design is\n" "  port ( clk : in std_logic );\n" "end;";
    REQUIRE(result == expected);
}

TEST_CASE("Architecture: With library and use clauses", "[pretty_printer][context][architecture]")
{
    ast::Architecture arch{.context = {},
                           .name = "rtl",
                           .entity_name = "test_unit",
                           .decls = {},
                           .stmts = {},
                           .end_label = std::nullopt,
                           .has_end_architecture_keyword = false};
    arch.context.emplace_back(ast::LibraryClause{.logical_names = {"work"}});
    arch.context.emplace_back(ast::UseClause{.selected_names = {"work.my_package.all"}});

    const std::string result = emit::test::render(arch);
    const std::string_view expected =
      "library work;\n" "use work.my_package.all;\n" "architecture rtl of test_unit is\n" "begin\n" "end;";
    REQUIRE(result == expected);
}
