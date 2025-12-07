#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>

TEST_CASE("CallExpr Rendering", "[pretty_printer][expressions][call]")
{
    SECTION("Simple function call")
    {
        ast::CallExpr call{ .callee{ std::make_unique<ast::Expr>(
                              ast::TokenExpr{ .text{ "rising_edge" } }) },
                            .args{ std::make_unique<ast::GroupExpr>() } };
        call.args->children.push_back(ast::TokenExpr{ .text{ "clk" } });

        REQUIRE(emit::test::render(call) == "rising_edge(clk)");
    }

    SECTION("Multiple arguments")
    {
        ast::CallExpr call{ .callee{
                              std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "resize" } }) },
                            .args{ std::make_unique<ast::GroupExpr>() } };
        call.args->children.push_back(ast::TokenExpr{ .text{ "data" } });
        call.args->children.push_back(ast::TokenExpr{ .text{ "16" } });

        REQUIRE(emit::test::render(call) == "resize(data, 16)");
    }

    SECTION("Chained calls")
    {
        ast::CallExpr inner{ .callee{ std::make_unique<ast::Expr>(
                               ast::TokenExpr{ .text{ "get_array" } }) },
                             .args{ std::make_unique<ast::GroupExpr>() } };
        inner.args->children.push_back(ast::TokenExpr{ .text{ "i" } });

        ast::CallExpr outer{ .callee{ std::make_unique<ast::Expr>(std::move(inner)) },
                             .args{ std::make_unique<ast::GroupExpr>() } };
        outer.args->children.push_back(ast::TokenExpr{ .text{ "j" } });

        REQUIRE(emit::test::render(outer) == "get_array(i)(j)");
    }
}
