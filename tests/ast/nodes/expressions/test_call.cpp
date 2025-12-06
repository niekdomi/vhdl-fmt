#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

using namespace test_helpers;

TEST_CASE("CallExpr: Function calls", "[expressions][call][function]")
{
    SECTION("rising_edge(clk)")
    {
        const auto *expr = parseExpr("boolean", "rising_edge(clk)");
        const auto *call = requireCall(expr);

        requireToken(call->callee.get(), "rising_edge");
        requireToken(call->args.get(), "clk");
    }

    SECTION("to_integer(unsigned_val)")
    {
        const auto *expr = parseExpr("integer", "to_integer(unsigned_val)");
        const auto *call = requireCall(expr);

        requireToken(call->callee.get(), "to_integer");
        requireToken(call->args.get(), "unsigned_val");
    }

    SECTION("conv_integer(data)")
    {
        const auto *expr = parseExpr("integer", "conv_integer(data)");
        const auto *call = requireCall(expr);

        requireToken(call->callee.get(), "conv_integer");
        requireToken(call->args.get(), "data");
    }
}

TEST_CASE("CallExpr: Array indexing", "[expressions][call][index]")
{
    SECTION("data(0)")
    {
        const auto *expr = parseExpr("std_logic", "data(0)");
        const auto *call = requireCall(expr);

        requireToken(call->callee.get(), "data");
        requireToken(call->args.get(), "0");
    }

    SECTION("my_array(i)")
    {
        const auto *expr = parseExpr("integer", "my_array(i)");
        const auto *call = requireCall(expr);

        requireToken(call->callee.get(), "my_array");
        requireToken(call->args.get(), "i");
    }

    SECTION("matrix(row, col)")
    {
        const auto *expr = parseExpr("integer", "matrix(row, col)");
        const auto *call = requireCall(expr);

        requireToken(call->callee.get(), "matrix");

        // Args is a GroupExpr with 2 elements
        const auto *group = requireGroup(call->args.get(), 2);

        requireToken(&group->children[0], "row");
        requireToken(&group->children[1], "col");
    }
}

TEST_CASE("CallExpr: Slice notation", "[expressions][call][slice]")
{
    SECTION("data(7 downto 0)")
    {
        const auto *expr = parseExpr("std_logic_vector(7 downto 0)", "data(7 downto 0)");
        const auto *call = requireCall(expr);

        requireToken(call->callee.get(), "data");

        // Args is a BinaryExpr with op "downto"
        const auto *binary = requireBinary(call->args.get(), "downto");
        requireToken(binary->left.get(), "7");
        requireToken(binary->right.get(), "0");
    }

    SECTION("mem_data(0 to 15)")
    {
        const auto *expr = parseExpr("std_logic_vector(15 downto 0)", "mem_data(0 to 15)");
        const auto *call = requireCall(expr);

        requireToken(call->callee.get(), "mem_data");

        const auto *binary = requireBinary(call->args.get(), "to");
        requireToken(binary->left.get(), "0");
        requireToken(binary->right.get(), "15");
    }
}

TEST_CASE("CallExpr: Chained calls", "[expressions][call][chained]")
{
    SECTION("get_array(i)(j) - nested indexing")
    {
        const auto *expr = parseExpr("integer", "get_array(i)(j)");
        const auto *outer_call = requireCall(expr);

        // Callee is itself a CallExpr
        const auto *inner_call = requireCall(outer_call->callee.get());
        requireToken(inner_call->callee.get(), "get_array");
        requireToken(inner_call->args.get(), "i");

        // Outer call's argument
        requireToken(outer_call->args.get(), "j");
    }
}

TEST_CASE("CallExpr: Function calls with multiple arguments", "[expressions][call][multiarg]")
{
    SECTION("resize(data, 16)")
    {
        const auto *expr = parseExpr("unsigned(15 downto 0)", "resize(data, 16)");
        const auto *call = requireCall(expr);

        requireToken(call->callee.get(), "resize");

        // Args is a GroupExpr with 2 elements
        const auto *group = requireGroup(call->args.get(), 2);

        requireToken(&group->children[0], "data");
        requireToken(&group->children[1], "16");
    }

    SECTION("shift_left(value, count)")
    {
        const auto *expr = parseExpr("unsigned(7 downto 0)", "shift_left(value, count)");
        const auto *call = requireCall(expr);

        requireToken(call->callee.get(), "shift_left");

        const auto *group = requireGroup(call->args.get(), 2);

        requireToken(&group->children[0], "value");
        requireToken(&group->children[1], "count");
    }
}
