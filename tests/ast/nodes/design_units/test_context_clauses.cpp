#include "ast/nodes/design_units.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("Context Clauses", "[design_units][context]")
{
    auto parse_context = [](std::string_view context_code) -> const ast::Entity * {
        std::string full_code = std::string(context_code) + "\nentity E is end;";
        return test_helpers::parseDesignUnit<ast::Entity>(full_code);
    };

    SECTION("Library Clauses")
    {
        SECTION("Single library")
        {
            const auto *unit = parse_context("library ieee;");
            REQUIRE(unit != nullptr);
            REQUIRE(unit->context.size() == 1);
            
            const auto *lib = std::get_if<ast::LibraryClause>(unit->context.data());
            REQUIRE(lib != nullptr);
            REQUIRE(lib->logical_names.size() == 1);
            CHECK(lib->logical_names[0] == "ieee");
        }

        SECTION("Multiple libraries")
        {
            const auto *unit = parse_context(R"(
                library ieee;
                library work;
            )");
            REQUIRE(unit != nullptr);
            REQUIRE(unit->context.size() == 2);
            
            CHECK(std::get<ast::LibraryClause>(unit->context[0]).logical_names[0] == "ieee");
            CHECK(std::get<ast::LibraryClause>(unit->context[1]).logical_names[0] == "work");
        }

        SECTION("Multiple names in one clause")
        {
            const auto *unit = parse_context("library ieee, std, work;");
            REQUIRE(unit != nullptr);
            REQUIRE(unit->context.size() == 1);
            
            const auto *lib = std::get_if<ast::LibraryClause>(unit->context.data());
            REQUIRE(lib != nullptr);
            REQUIRE(lib->logical_names.size() == 3);
            CHECK(lib->logical_names[0] == "ieee");
            CHECK(lib->logical_names[1] == "std");
            CHECK(lib->logical_names[2] == "work");
        }
    }

    SECTION("Use Clauses")
    {
        SECTION("Single use")
        {
            const auto *unit = parse_context("use ieee.std_logic_1164.all;");
            REQUIRE(unit != nullptr);
            REQUIRE(unit->context.size() == 1);
            
            const auto *use = std::get_if<ast::UseClause>(unit->context.data());
            REQUIRE(use != nullptr);
            REQUIRE(use->selected_names.size() == 1);
            CHECK(use->selected_names[0] == "ieee.std_logic_1164.all");
        }

        SECTION("Multiple use names")
        {
            const auto *unit = parse_context("use ieee.std_logic_1164.all, ieee.numeric_std.all;");
            REQUIRE(unit != nullptr);
            REQUIRE(unit->context.size() == 1);
            
            const auto *use = std::get_if<ast::UseClause>(unit->context.data());
            REQUIRE(use != nullptr);
            REQUIRE(use->selected_names.size() == 2);
            CHECK(use->selected_names[0] == "ieee.std_logic_1164.all");
            CHECK(use->selected_names[1] == "ieee.numeric_std.all");
        }
    }

    SECTION("Mixed Context")
    {
        const auto *unit = parse_context(R"(
            library ieee;
            use ieee.std_logic_1164.all;
        )");
        REQUIRE(unit != nullptr);
        REQUIRE(unit->context.size() == 2);
        
        CHECK(std::holds_alternative<ast::LibraryClause>(unit->context[0]));
        CHECK(std::holds_alternative<ast::UseClause>(unit->context[1]));
    }
}
