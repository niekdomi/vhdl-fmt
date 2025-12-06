#include "ast/nodes/design_units.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string>
#include <string_view>

TEST_CASE("LibraryClause: Single library", "[pretty_printer][context][library]")
{
    ast::LibraryClause lib_clause{ .logical_names = { "ieee" } };

    const std::string result = emit::test::render(lib_clause);
    constexpr std::string_view EXPECTED = "library ieee;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("LibraryClause: Multiple libraries in one clause", "[pretty_printer][context][library]")
{
    ast::LibraryClause lib_clause{
        .logical_names = { "ieee", "std", "work" }
    };

    const std::string result = emit::test::render(lib_clause);
    constexpr std::string_view EXPECTED = "library ieee, std, work;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("UseClause: Single use statement", "[pretty_printer][context][use]")
{
    ast::UseClause use_clause{ .selected_names = { "ieee.std_logic_1164.all" } };

    const std::string result = emit::test::render(use_clause);
    constexpr std::string_view EXPECTED = "use ieee.std_logic_1164.all;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("UseClause: Multiple use statements in one clause", "[pretty_printer][context][use]")
{
    ast::UseClause use_clause{
        .selected_names = { "ieee.std_logic_1164.all", "ieee.numeric_std.all" }
    };

    const std::string result = emit::test::render(use_clause);
    constexpr std::string_view EXPECTED = "use ieee.std_logic_1164.all, ieee.numeric_std.all;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("Entity: With library clause", "[pretty_printer][context][entity]")
{
    ast::Entity entity{ .name = "test_entity" };
    entity.context.emplace_back(ast::LibraryClause{ .logical_names = { "ieee" } });

    const std::string result = emit::test::render(entity);
    constexpr std::string_view EXPECTED = "library ieee;\n"
                                          "entity test_entity is\n"
                                          "end;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("Entity: With library and use clauses", "[pretty_printer][context][entity]")
{
    ast::Entity entity{ .name = "my_design" };
    entity.context.emplace_back(ast::LibraryClause{ .logical_names = { "ieee" } });
    entity.context.emplace_back(ast::UseClause{ .selected_names = { "ieee.std_logic_1164.all" } });
    entity.context.emplace_back(ast::UseClause{ .selected_names = { "ieee.numeric_std.all" } });

    entity.port_clause.ports.emplace_back(
      ast::Port{ .names = { "clk" }, .mode = "in", .type_name = "std_logic" });

    const std::string result = emit::test::render(entity);
    constexpr std::string_view EXPECTED = "library ieee;\n"
                                          "use ieee.std_logic_1164.all;\n"
                                          "use ieee.numeric_std.all;\n"
                                          "entity my_design is\n"
                                          "  port ( clk : in std_logic );\n"
                                          "end;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("Architecture: With library and use clauses", "[pretty_printer][context][architecture]")
{
    ast::Architecture arch{ .name = "rtl", .entity_name = "test_unit" };
    arch.context.emplace_back(ast::LibraryClause{ .logical_names = { "work" } });
    arch.context.emplace_back(ast::UseClause{ .selected_names = { "work.my_package.all" } });

    const std::string result = emit::test::render(arch);
    constexpr std::string_view EXPECTED = "library work;\n"
                                          "use work.my_package.all;\n"
                                          "architecture rtl of test_unit is\n"
                                          "begin\n"
                                          "end;";
    REQUIRE(result == EXPECTED);
}
