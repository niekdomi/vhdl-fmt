#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

using namespace test_helpers;

TEST_CASE("AttributeExpr: Simple attributes", "[expressions][attribute]")
{
    SECTION("data'length")
    {
        const auto *expr = parseExpr("integer", "data'length");
        const auto *attr = requireAttribute(expr, "length");
        REQUIRE(!attr->arg.has_value());
        requireToken(attr->prefix.get(), "data");
    }

    SECTION("clk'event")
    {
        const auto *expr = parseExpr("boolean", "clk'event");
        const auto *attr = requireAttribute(expr, "event");
        REQUIRE(!attr->arg.has_value());
        requireToken(attr->prefix.get(), "clk");
    }

    SECTION("signal_name'stable")
    {
        const auto *expr = parseExpr("boolean", "signal_name'stable");
        const auto *attr = requireAttribute(expr, "stable");
        REQUIRE(!attr->arg.has_value());
        requireToken(attr->prefix.get(), "signal_name");
    }
}

TEST_CASE("AttributeExpr: Attributes with parameters", "[expressions][attribute][parameterized]")
{
    SECTION("signal_name'stable(5 ns)")
    {
        const auto *expr = parseExpr("boolean", "signal_name'stable(5 ns)");
        const auto *attr = requireAttribute(expr, "stable");
        REQUIRE(attr->arg.has_value());
        requireToken(attr->prefix.get(), "signal_name");

        // The parameter is a PhysicalLiteral
        const auto *param = std::get_if<ast::PhysicalLiteral>(attr->arg.value().get());
        REQUIRE(param != nullptr);
        REQUIRE(param->value == "5");
        REQUIRE(param->unit == "ns");
    }

    SECTION("data'delayed(2 ns)")
    {
        const auto *expr = parseExpr("std_logic", "data'delayed(2 ns)");
        const auto *attr = requireAttribute(expr, "delayed");
        REQUIRE(attr->arg.has_value());
        requireToken(attr->prefix.get(), "data");

        const auto *param = std::get_if<ast::PhysicalLiteral>(attr->arg.value().get());
        REQUIRE(param != nullptr);
        REQUIRE(param->value == "2");
        REQUIRE(param->unit == "ns");
    }
}

TEST_CASE("AttributeExpr: Attributes on complex prefixes", "[expressions][attribute][complex]")
{
    SECTION("my_array(i)'length - attribute on indexed name")
    {
        const auto *expr = parseExpr("integer", "my_array(i)'length");
        const auto *attr = requireAttribute(expr, "length");
        REQUIRE(!attr->arg.has_value());

        // Prefix is a CallExpr (indexed name)
        const auto *call = std::get_if<ast::CallExpr>(attr->prefix.get());
        REQUIRE(call != nullptr);
        requireToken(call->callee.get(), "my_array");
        requireToken(call->args.get(), "i");
    }
}
