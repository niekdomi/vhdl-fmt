#include "ast/nodes/design_units.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("Package", "[design_units][package]")
{
    auto parse_package = test_helpers::parseDesignUnit<ast::Package>;

    SECTION("Minimal Package (Structure)")
    {
        const auto* pkg = parse_package("package Minimal is end Minimal;");
        REQUIRE(pkg != nullptr);

        CHECK(pkg->name == "Minimal");
        CHECK_FALSE(pkg->has_end_package_keyword);
        CHECK(pkg->end_label.value_or("") == "Minimal");
        CHECK(pkg->decls.empty());
    }

    SECTION("Package with 'end package' keyword")
    {
        const auto* pkg = parse_package("package KW_Test is end package;");
        REQUIRE(pkg != nullptr);

        CHECK(pkg->name == "KW_Test");
        CHECK(pkg->has_end_package_keyword);
        CHECK_FALSE(pkg->end_label.has_value());
    }

    SECTION("Package with 'end package' and label")
    {
        const auto* pkg = parse_package("package TestPkg is end package TestPkg;");
        REQUIRE(pkg != nullptr);

        CHECK(pkg->name == "TestPkg");
        CHECK(pkg->has_end_package_keyword);
        CHECK(pkg->end_label.value_or("") == "TestPkg");
    }

    SECTION("Package without end label")
    {
        const auto* pkg = parse_package("package NoLabel is end;");
        REQUIRE(pkg != nullptr);

        CHECK(pkg->name == "NoLabel");
        CHECK_FALSE(pkg->has_end_package_keyword);
        CHECK_FALSE(pkg->end_label.has_value());
    }
}
