#include "ast/nodes/expressions.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("PhysicalLiteral", "[expressions][physical]")
{
    SECTION("Integer value with unit")
    {
        const auto* expr = test_helpers::parseExpr("10 ns");
        const auto* physical = std::get_if<ast::PhysicalLiteral>(expr);
        REQUIRE(physical != nullptr);
        REQUIRE(physical->value == "10");
        REQUIRE(physical->unit == "ns");
    }

    SECTION("Decimal value with unit")
    {
        const auto* expr = test_helpers::parseExpr("1.5 ns");
        const auto* physical = std::get_if<ast::PhysicalLiteral>(expr);
        REQUIRE(physical != nullptr);
        REQUIRE(physical->value == "1.5");
        REQUIRE(physical->unit == "ns");
    }

    SECTION("Different unit types")
    {
        const auto* expr = test_helpers::parseExpr("50 MHz");
        const auto* physical = std::get_if<ast::PhysicalLiteral>(expr);
        REQUIRE(physical != nullptr);
        REQUIRE(physical->value == "50");
        REQUIRE(physical->unit == "MHz");
    }
}
