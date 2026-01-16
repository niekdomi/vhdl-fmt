#include "ast/nodes/design_units.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <optional>
#include <string>
#include <string_view>

TEST_CASE("Package Rendering", "[pretty_printer][design_units][package]")
{
    // Common setup for all sections
    ast::Package package{.name = "test_pkg"};

    SECTION("Minimal Package")
    {
        const std::string result = emit::test::render(package);
        const std::string_view expected = "package test_pkg is\nend;";
        REQUIRE(result == expected);
    }

    SECTION("End Syntax Variations")
    {
        SECTION("Minimal: end;")
        {
            package.has_end_package_keyword = false;
            package.end_label = std::nullopt;

            REQUIRE(emit::test::render(package) == "package test_pkg is\nend;");
        }

        SECTION("Keyword Only: end package;")
        {
            package.has_end_package_keyword = true;
            package.end_label = std::nullopt;

            REQUIRE(emit::test::render(package) == "package test_pkg is\nend package;");
        }

        SECTION("Label Only: end <name>;")
        {
            package.has_end_package_keyword = false;
            package.end_label = "test_pkg";

            REQUIRE(emit::test::render(package) == "package test_pkg is\nend test_pkg;");
        }

        SECTION("Full: end package <name>;")
        {
            package.has_end_package_keyword = true;
            package.end_label = "test_pkg";

            REQUIRE(emit::test::render(package) == "package test_pkg is\nend package test_pkg;");
        }
    }
}
