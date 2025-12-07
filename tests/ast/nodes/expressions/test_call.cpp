#include "expr_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("CallExpr", "[expressions][call]")
{
    SECTION("Simple function call")
    {
        const auto *expr = expr_utils::parseExpr("rising_edge(clk)");
        const auto *call = std::get_if<ast::CallExpr>(expr);
        REQUIRE(call != nullptr);

        const auto *callee = std::get_if<ast::TokenExpr>(call->callee.get());
        REQUIRE(callee != nullptr);
        REQUIRE(callee->text == "rising_edge");

        REQUIRE(call->args->children.size() == 1);

        const auto *arg = std::get_if<ast::TokenExpr>(call->args->children.data());
        REQUIRE(arg != nullptr);
        REQUIRE(arg->text == "clk");
    }

    SECTION("Multiple arguments")
    {
        const auto *expr = expr_utils::parseExpr("resize(data, 16)");
        const auto *call = std::get_if<ast::CallExpr>(expr);
        REQUIRE(call != nullptr);

        const auto *callee = std::get_if<ast::TokenExpr>(call->callee.get());
        REQUIRE(callee != nullptr);
        REQUIRE(callee->text == "resize");

        REQUIRE(call->args->children.size() == 2);

        const auto *arg1 = std::get_if<ast::TokenExpr>(call->args->children.data());
        REQUIRE(arg1 != nullptr);
        REQUIRE(arg1->text == "data");

        const auto *arg2 = std::get_if<ast::TokenExpr>(&call->args->children[1]);
        REQUIRE(arg2 != nullptr);
        REQUIRE(arg2->text == "16");
    }

    SECTION("Chained calls")
    {
        const auto *expr = expr_utils::parseExpr("get_array(i)(j)");
        const auto *outer_call = std::get_if<ast::CallExpr>(expr);
        REQUIRE(outer_call != nullptr);

        const auto *inner_call = std::get_if<ast::CallExpr>(outer_call->callee.get());
        REQUIRE(inner_call != nullptr);

        const auto *inner_callee = std::get_if<ast::TokenExpr>(inner_call->callee.get());
        REQUIRE(inner_callee != nullptr);
        REQUIRE(inner_callee->text == "get_array");

        REQUIRE(inner_call->args->children.size() == 1);

        const auto *inner_arg = std::get_if<ast::TokenExpr>(inner_call->args->children.data());
        REQUIRE(inner_arg != nullptr);
        REQUIRE(inner_arg->text == "i");

        REQUIRE(outer_call->args->children.size() == 1);

        const auto *outer_arg = std::get_if<ast::TokenExpr>(outer_call->args->children.data());
        REQUIRE(outer_arg != nullptr);
        REQUIRE(outer_arg->text == "j");
    }
}
