#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>

TEST_CASE("AttributeExpr Rendering", "[pretty_printer][expressions][attribute]")
{
    SECTION("Simple attribute")
    {
        ast::AttributeExpr attr{ .prefix{
                                   std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "data" }) },
                                 .attribute{ "length" } };

        REQUIRE(emit::test::render(attr) == "data'length");
    }

    SECTION("Attribute with parameter")
    {
        ast::AttributeExpr attr{
            .prefix{ std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "signal_name" } }) },
            .attribute{ "stable" },
            .arg{
              std::make_unique<ast::Expr>(ast::PhysicalLiteral{ .value{ "5" }, .unit{ "ns" } }) }
        };

        REQUIRE(emit::test::render(attr) == "signal_name'stable(5 ns)");
    }

    SECTION("Attribute on complex prefix")
    {
        ast::CallExpr call{ .callee{
                              std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "my_array" } }) },
                            .args{ std::make_unique<ast::GroupExpr>() } };

        call.args->children.emplace_back(ast::TokenExpr{ .text{ "i" } });

        ast::AttributeExpr attr{ .prefix{ std::make_unique<ast::Expr>(std::move(call)) },
                                 .attribute{ "length" } };

        REQUIRE(emit::test::render(attr) == "my_array(i)'length");
    }
}
