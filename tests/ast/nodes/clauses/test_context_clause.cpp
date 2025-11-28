#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("ContextDeclaration: Simple context with library clause", "[clauses][context_clause]")
{
    constexpr std::string_view VHDL_FILE = R"(
        context my_context is
            library ieee;
        end context my_context;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &context = std::get<ast::ContextDeclaration>(design.units[0]);
    REQUIRE(context.name == "my_context");
    REQUIRE(context.items.size() == 1);

    const auto &lib_clause = std::get<ast::LibraryClause>(context.items[0]);
    REQUIRE(lib_clause.logical_names.size() == 1);
    REQUIRE(lib_clause.logical_names[0] == "ieee");
}

TEST_CASE("ContextDeclaration: Context with library and use clauses", "[clauses][context_clause]")
{
    constexpr std::string_view VHDL_FILE = R"(
        context my_context is
            library ieee;
            use ieee.std_logic_1164.all;
        end context my_context;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &context = std::get<ast::ContextDeclaration>(design.units[0]);
    REQUIRE(context.name == "my_context");
    REQUIRE(context.items.size() == 2);

    const auto &lib_clause = std::get<ast::LibraryClause>(context.items[0]);
    REQUIRE(lib_clause.logical_names.size() == 1);
    REQUIRE(lib_clause.logical_names[0] == "ieee");

    const auto &use_clause = std::get<ast::UseClause>(context.items[1]);
    REQUIRE(use_clause.selected_names.size() == 1);
    REQUIRE(use_clause.selected_names[0] == "ieee.std_logic_1164.all");
}

TEST_CASE("ContextDeclaration: Complex context with multiple clauses", "[clauses][context_clause]")
{
    constexpr std::string_view VHDL_FILE = R"(
        context complex_context is
            library ieee, std;
            use ieee.std_logic_1164.all;
            use std.textio.all;
        end context complex_context;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &context = std::get<ast::ContextDeclaration>(design.units[0]);
    REQUIRE(context.name == "complex_context");
    REQUIRE(context.items.size() == 3);

    const auto &lib_clause = std::get<ast::LibraryClause>(context.items[0]);
    REQUIRE(lib_clause.logical_names.size() == 2);
    REQUIRE(lib_clause.logical_names[0] == "ieee");
    REQUIRE(lib_clause.logical_names[1] == "std");

    const auto &use_clause1 = std::get<ast::UseClause>(context.items[1]);
    REQUIRE(use_clause1.selected_names.size() == 1);
    REQUIRE(use_clause1.selected_names[0] == "ieee.std_logic_1164.all");

    const auto &use_clause2 = std::get<ast::UseClause>(context.items[2]);
    REQUIRE(use_clause2.selected_names.size() == 1);
    REQUIRE(use_clause2.selected_names[0] == "std.textio.all");
}

TEST_CASE("ContextDeclaration: Context with multiple use clauses in single statement",
          "[clauses][context_clause]")
{
    constexpr std::string_view VHDL_FILE = R"(
        context multi_use_context is
            library ieee;
            use ieee.std_logic_1164.all, ieee.numeric_std.all;
        end context multi_use_context;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &context = std::get<ast::ContextDeclaration>(design.units[0]);
    REQUIRE(context.name == "multi_use_context");
    REQUIRE(context.items.size() == 2);

    const auto &lib_clause = std::get<ast::LibraryClause>(context.items[0]);
    REQUIRE(lib_clause.logical_names.size() == 1);
    REQUIRE(lib_clause.logical_names[0] == "ieee");

    const auto &use_clause = std::get<ast::UseClause>(context.items[1]);
    REQUIRE(use_clause.selected_names.size() == 2);
    REQUIRE(use_clause.selected_names[0] == "ieee.std_logic_1164.all");
    REQUIRE(use_clause.selected_names[1] == "ieee.numeric_std.all");
}

TEST_CASE("ContextDeclaration: Context with multiple libraries and multiple uses",
          "[clauses][context_clause]")
{
    constexpr std::string_view VHDL_FILE = R"(
        context comprehensive_context is
            library ieee, std, work;
            use ieee.std_logic_1164.all, ieee.numeric_std.all;
            use std.textio.all;
            use work.my_package.all;
        end context comprehensive_context;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &context = std::get<ast::ContextDeclaration>(design.units[0]);
    REQUIRE(context.name == "comprehensive_context");
    REQUIRE(context.items.size() == 4);

    const auto &lib_clause = std::get<ast::LibraryClause>(context.items[0]);
    REQUIRE(lib_clause.logical_names.size() == 3);
    REQUIRE(lib_clause.logical_names[0] == "ieee");
    REQUIRE(lib_clause.logical_names[1] == "std");
    REQUIRE(lib_clause.logical_names[2] == "work");

    const auto &use_clause1 = std::get<ast::UseClause>(context.items[1]);
    REQUIRE(use_clause1.selected_names.size() == 2);
    REQUIRE(use_clause1.selected_names[0] == "ieee.std_logic_1164.all");
    REQUIRE(use_clause1.selected_names[1] == "ieee.numeric_std.all");

    const auto &use_clause2 = std::get<ast::UseClause>(context.items[2]);
    REQUIRE(use_clause2.selected_names.size() == 1);
    REQUIRE(use_clause2.selected_names[0] == "std.textio.all");

    const auto &use_clause3 = std::get<ast::UseClause>(context.items[3]);
    REQUIRE(use_clause3.selected_names.size() == 1);
    REQUIRE(use_clause3.selected_names[0] == "work.my_package.all");
}
