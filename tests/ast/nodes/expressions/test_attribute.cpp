#include "ast/nodes/expressions.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("AttributeExpr", "[expressions][attribute]")
{
    SECTION("Simple attribute")
    {
        const auto *expr = test_helpers::parseExpr("data'length");
        const auto *attr = std::get_if<ast::AttributeExpr>(expr);
        REQUIRE(attr != nullptr);
        REQUIRE(attr->attribute == "length");
        REQUIRE(!attr->arg.has_value());

        const auto *prefix = std::get_if<ast::TokenExpr>(attr->prefix.get());
        REQUIRE(prefix != nullptr);
        REQUIRE(prefix->text == "data");
    }

    SECTION("With parameter")
    {
        const auto *expr = test_helpers::parseExpr("signal_name'stable(5 ns)");
        const auto *attr = std::get_if<ast::AttributeExpr>(expr);
        REQUIRE(attr != nullptr);
        REQUIRE(attr->attribute == "stable");
        REQUIRE(attr->arg.has_value());

        const auto *prefix = std::get_if<ast::TokenExpr>(attr->prefix.get());
        REQUIRE(prefix != nullptr);
        REQUIRE(prefix->text == "signal_name");

        const auto *param = std::get_if<ast::PhysicalLiteral>(attr->arg.value().get());
        REQUIRE(param != nullptr);
        REQUIRE(param->value == "5");
        REQUIRE(param->unit == "ns");
    }

    SECTION("On complex prefix")
    {
        const auto *expr = test_helpers::parseExpr("my_array(i)'length");
        const auto *attr = std::get_if<ast::AttributeExpr>(expr);
        REQUIRE(attr != nullptr);
        REQUIRE(attr->attribute == "length");
        REQUIRE(!attr->arg.has_value());

        const auto *call = std::get_if<ast::CallExpr>(attr->prefix.get());
        REQUIRE(call != nullptr);

        const auto *callee = std::get_if<ast::TokenExpr>(call->callee.get());
        REQUIRE(callee != nullptr);
        REQUIRE(callee->text == "my_array");

        REQUIRE(call->args->children.size() == 1);

        const auto *arg = std::get_if<ast::TokenExpr>(call->args->children.data());
        REQUIRE(arg != nullptr);
        REQUIRE(arg->text == "i");
    }
}
