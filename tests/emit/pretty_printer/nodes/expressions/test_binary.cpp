#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <utility>

TEST_CASE("BinaryExpr Rendering", "[pretty_printer][expressions][binary]")
{
    SECTION("Simple addition")
    {
        const ast::BinaryExpr binary{
            .left{ std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "a" } }) },
            .op{ "+" },
            .right{ std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "b" } }) }
        };

        REQUIRE(emit::test::render(binary) == "a + b");
    }

    SECTION("Left-associative operations")
    {
        ast::BinaryExpr inner{
            .left{ std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "a" } }) },
            .op{ "+" },
            .right{ std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "b" } }) },
        };

        const ast::BinaryExpr outer{
            .left{ std::make_unique<ast::Expr>(std::move(inner)) },
            .op{ "+" },
            .right{ std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "c" } }) },
        };

        REQUIRE(emit::test::render(outer) == "a + b + c");
    }

    SECTION("Operator precedence")
    {
        ast::BinaryExpr mult{
            .left{ std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "b" } }) },
            .op{ "*" },
            .right{ std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "c" } }) },
        };

        const ast::BinaryExpr add{
            .left{ std::make_unique<ast::Expr>(ast::TokenExpr{
              .text{ "a" },
            }) },
            .op{ "+" },
            .right{ std::make_unique<ast::Expr>(std::move(mult)) },
        };

        REQUIRE(emit::test::render(add) == "a + b * c");
    }
}
