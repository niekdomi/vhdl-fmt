#include "ast/nodes/design_units.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
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
