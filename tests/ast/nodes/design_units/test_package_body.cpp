#include "ast/nodes/design_units.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("PackageBody", "[design_units][package_body]")
{
    auto parse_package_body = test_helpers::parseDesignUnit<ast::PackageBody>;

    SECTION("Minimal Package Body (Structure)")
    {
        const auto* pkg_body = parse_package_body("package body Minimal is end Minimal;");
        REQUIRE(pkg_body != nullptr);

        CHECK(pkg_body->name == "Minimal");
        CHECK_FALSE(pkg_body->has_end_package_body_keyword);
        CHECK(pkg_body->end_label.value_or("") == "Minimal");
        CHECK(pkg_body->decls.empty());
    }

    SECTION("Package Body with 'end package body' keyword")
    {
        const auto* pkg_body = parse_package_body("package body KW_Test is end package body;");
        REQUIRE(pkg_body != nullptr);

        CHECK(pkg_body->name == "KW_Test");
        CHECK(pkg_body->has_end_package_body_keyword);
        CHECK_FALSE(pkg_body->end_label.has_value());
    }

    SECTION("Package Body with 'end package body' and label")
    {
        const auto* pkg_body =
          parse_package_body("package body TestPkg is end package body TestPkg;");
        REQUIRE(pkg_body != nullptr);

        CHECK(pkg_body->name == "TestPkg");
        CHECK(pkg_body->has_end_package_body_keyword);
        CHECK(pkg_body->end_label.value_or("") == "TestPkg");
    }

    SECTION("Package Body without end label")
    {
        const auto* pkg_body = parse_package_body("package body NoLabel is end;");
        REQUIRE(pkg_body != nullptr);

        CHECK(pkg_body->name == "NoLabel");
        CHECK_FALSE(pkg_body->has_end_package_body_keyword);
        CHECK_FALSE(pkg_body->end_label.has_value());
    }
}
