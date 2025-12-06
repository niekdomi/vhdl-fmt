#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

using namespace test_helpers;TEST_CASE("PhysicalLiteral: Time literals", "[expressions][physical][time]")
{
    SECTION("10 ns")
    {
        const auto *expr = parseExpr("time", "10 ns");
        requirePhysical(expr, "10", "ns");
    }

    SECTION("5 us")
    {
        const auto *expr = parseExpr("time", "5 us");
        requirePhysical(expr, "5", "us");
    }

    SECTION("1 ms")
    {
        const auto *expr = parseExpr("time", "1 ms");
        requirePhysical(expr, "1", "ms");
    }

    SECTION("100 ps")
    {
        const auto *expr = parseExpr("time", "100 ps");
        requirePhysical(expr, "100", "ps");
    }

    SECTION("2 sec")
    {
        const auto *expr = parseExpr("time", "2 sec");
        requirePhysical(expr, "2", "sec");
    }
}

TEST_CASE("PhysicalLiteral: Decimal values", "[expressions][physical][decimal]")
{
    SECTION("1.5 ns")
    {
        const auto *expr = parseExpr("time", "1.5 ns");
        requirePhysical(expr, "1.5", "ns");
    }

    SECTION("10.25 us")
    {
        const auto *expr = parseExpr("time", "10.25 us");
        requirePhysical(expr, "10.25", "us");
    }

    SECTION("0.1 ms")
    {
        const auto *expr = parseExpr("time", "0.1 ms");
        requirePhysical(expr, "0.1", "ms");
    }
}

TEST_CASE("PhysicalLiteral: Frequency units", "[expressions][physical][frequency]")
{
    SECTION("50 MHz")
    {
        const auto *expr = parseExpr("frequency", "50 MHz");
        requirePhysical(expr, "50", "MHz");
    }

    SECTION("1 kHz")
    {
        const auto *expr = parseExpr("frequency", "1 kHz");
        requirePhysical(expr, "1", "kHz");
    }

    SECTION("100 Hz")
    {
        const auto *expr = parseExpr("frequency", "100 Hz");
        requirePhysical(expr, "100", "Hz");
    }
}

TEST_CASE("PhysicalLiteral: Custom physical types", "[expressions][physical][custom]")
{
    SECTION("10 mm - length units")
    {
        const auto *expr = parseExpr("length", "10 mm");
        requirePhysical(expr, "10", "mm");
    }

    SECTION("5 kg - mass units")
    {
        const auto *expr = parseExpr("mass", "5 kg");
        requirePhysical(expr, "5", "kg");
    }

    SECTION("100 V - voltage units")
    {
        const auto *expr = parseExpr("voltage", "100 V");
        requirePhysical(expr, "100", "V");
    }
}

TEST_CASE("PhysicalLiteral: Edge cases", "[expressions][physical][edge]")
{
    SECTION("0 ns - zero value")
    {
        const auto *expr = parseExpr("time", "0 ns");
        requirePhysical(expr, "0", "ns");
    }

    SECTION("1 fs - femtosecond")
    {
        const auto *expr = parseExpr("time", "1 fs");
        requirePhysical(expr, "1", "fs");
    }

    SECTION("999999 ns - large value")
    {
        const auto *expr = parseExpr("time", "999999 ns");
        requirePhysical(expr, "999999", "ns");
    }
}
