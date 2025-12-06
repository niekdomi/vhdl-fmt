#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

using namespace test_helpers;

TEST_CASE("QualifiedExpr: Verifies QualifiedExpr node creation", "[expressions][qualified]")
{
    SECTION("std_logic_vector'(x\"AB\")")
    {
        const auto *expr = parseExpr("std_logic_vector(7 downto 0)", "std_logic_vector'(x\"AB\")");
        const auto *qual = requireQualified(expr, "std_logic_vector");
        REQUIRE(qual->operand != nullptr);
    }

    SECTION("integer'(42)")
    {
        const auto *expr = parseExpr("integer", "integer'(42)");
        const auto *qual = requireQualified(expr, "integer");
        REQUIRE(qual->operand != nullptr);
    }

    SECTION("array_type'(1, 2, 3)")
    {
        const auto *expr = parseExpr("array_type", "array_type'(1, 2, 3)");
        const auto *qual = requireQualified(expr, "array_type");
        REQUIRE(qual->operand != nullptr);
    }

    SECTION("record_type'(field => value)")
    {
        const auto *expr = parseExpr("record_type", "record_type'(field => value)");
        const auto *qual = requireQualified(expr, "record_type");
        REQUIRE(qual->operand != nullptr);
    }
}

