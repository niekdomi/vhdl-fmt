#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Context: Entity with library clause", "[design_units][context]")
{
    const std::string_view file = R"(
        library ieee;
        entity MyEntity is
            port (clk : in std_logic);
        end MyEntity;
    )";

    const auto design = builder::buildFromString(file);
    REQUIRE(design.units.size() == 1);

    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->name == "MyEntity");
    REQUIRE(entity->context.size() == 1);

    const auto* lib_clause = std::get_if<ast::LibraryClause>(entity->context.data());
    REQUIRE(lib_clause != nullptr);
    REQUIRE(lib_clause->logical_names.size() == 1);
    REQUIRE(lib_clause->logical_names[0] == "ieee");
}

TEST_CASE("Context: Entity with multiple library clauses", "[design_units][context]")
{
    const std::string_view file = R"(
        library ieee;
        library work;
        library std;
        entity MyEntity is
        end MyEntity;
    )";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->context.size() == 3);

    const auto* lib1 = std::get_if<ast::LibraryClause>(entity->context.data());
    const auto* lib2 = std::get_if<ast::LibraryClause>(&entity->context[1]);
    const auto* lib3 = std::get_if<ast::LibraryClause>(&entity->context[2]);

    REQUIRE(lib1 != nullptr);
    REQUIRE(lib2 != nullptr);
    REQUIRE(lib3 != nullptr);

    REQUIRE(lib1->logical_names[0] == "ieee");
    REQUIRE(lib2->logical_names[0] == "work");
    REQUIRE(lib3->logical_names[0] == "std");
}

TEST_CASE("Context: Library clause with multiple names", "[design_units][context]")
{
    const std::string_view file = R"(
        library ieee, std, work;
        entity MyEntity is
        end MyEntity;
    )";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->context.size() == 1);

    const auto* lib_clause = std::get_if<ast::LibraryClause>(entity->context.data());
    REQUIRE(lib_clause != nullptr);
    REQUIRE(lib_clause->logical_names.size() == 3);
    REQUIRE(lib_clause->logical_names[0] == "ieee");
    REQUIRE(lib_clause->logical_names[1] == "std");
    REQUIRE(lib_clause->logical_names[2] == "work");
}

TEST_CASE("Context: Entity with use clause", "[design_units][context]")
{
    const std::string_view file = R"(
        use ieee.std_logic_1164.all;
        entity MyEntity is
        end MyEntity;
    )";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->context.size() == 1);

    const auto* use_clause = std::get_if<ast::UseClause>(entity->context.data());
    REQUIRE(use_clause != nullptr);
    REQUIRE(use_clause->selected_names.size() == 1);
    REQUIRE(use_clause->selected_names[0] == "ieee.std_logic_1164.all");
}

TEST_CASE("Context: Entity with library and use clauses", "[design_units][context]")
{
    const std::string_view file = R"(
        library ieee;
        use ieee.std_logic_1164.all;
        use ieee.numeric_std.all;
        entity MyEntity is
            port (clk : in std_logic);
        end MyEntity;
    )";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->context.size() == 3);

    const auto* lib_clause = std::get_if<ast::LibraryClause>(entity->context.data());
    const auto* use_clause1 = std::get_if<ast::UseClause>(&entity->context[1]);
    const auto* use_clause2 = std::get_if<ast::UseClause>(&entity->context[2]);

    REQUIRE(lib_clause != nullptr);
    REQUIRE(use_clause1 != nullptr);
    REQUIRE(use_clause2 != nullptr);

    REQUIRE(lib_clause->logical_names[0] == "ieee");
    REQUIRE(use_clause1->selected_names[0] == "ieee.std_logic_1164.all");
    REQUIRE(use_clause2->selected_names[0] == "ieee.numeric_std.all");
}

TEST_CASE("Context: Use clause with multiple names", "[design_units][context]")
{
    const std::string_view file = R"(
        use ieee.std_logic_1164.all, ieee.numeric_std.all;
        entity MyEntity is
        end MyEntity;
    )";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->context.size() == 1);

    const auto* use_clause = std::get_if<ast::UseClause>(entity->context.data());
    REQUIRE(use_clause != nullptr);
    REQUIRE(use_clause->selected_names.size() == 2);
    REQUIRE(use_clause->selected_names[0] == "ieee.std_logic_1164.all");
    REQUIRE(use_clause->selected_names[1] == "ieee.numeric_std.all");
}
