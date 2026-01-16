#include "ast/nodes/design_units.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <optional>
#include <string>
#include <string_view>

TEST_CASE("PackageBody Rendering", "[pretty_printer][design_units][package_body]")
{
    // Common setup for all sections
    ast::PackageBody package_body{.name = "test_pkg"};

    SECTION("Minimal Package Body")
    {
        const std::string result = emit::test::render(package_body);
        const std::string_view expected = "package body test_pkg is\nend;";
        REQUIRE(result == expected);
    }

    SECTION("End Syntax Variations")
    {
        SECTION("Minimal: end;")
        {
            package_body.has_end_package_body_keyword = false;
            package_body.end_label = std::nullopt;

            REQUIRE(emit::test::render(package_body) == "package body test_pkg is\nend;");
        }

        SECTION("Keyword Only: end package body;")
        {
            package_body.has_end_package_body_keyword = true;
            package_body.end_label = std::nullopt;

            REQUIRE(emit::test::render(package_body)
                    == "package body test_pkg is\nend package body;");
        }

        SECTION("Label Only: end <name>;")
        {
            package_body.has_end_package_body_keyword = false;
            package_body.end_label = "test_pkg";

            REQUIRE(emit::test::render(package_body) == "package body test_pkg is\nend test_pkg;");
        }

        SECTION("Full: end package body <name>;")
        {
            package_body.has_end_package_body_keyword = true;
            package_body.end_label = "test_pkg";

            REQUIRE(emit::test::render(package_body)
                    == "package body test_pkg is\nend package body test_pkg;");
        }
    }
}
