#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <utility>

TEST_CASE("ParenExpr Rendering", "[pretty_printer][expressions][paren]")
{
    SECTION("Simple parenthesized expression")
    {
        const ast::ParenExpr paren{.inner{std::make_unique<ast::Expr>(ast::TokenExpr{.text{"x"}})}};

        REQUIRE(emit::test::render(paren) == "(x)");
    }

    SECTION("Precedence override")
    {
        ast::BinaryExpr add{.left{std::make_unique<ast::Expr>(ast::TokenExpr{.text{"a"}})},
                            .op{"+"},
                            .right{std::make_unique<ast::Expr>(ast::TokenExpr{.text{"b"}})}};

        ast::ParenExpr paren{.inner{std::make_unique<ast::Expr>(std::move(add))}};

        const ast::BinaryExpr mult{.left{std::make_unique<ast::Expr>(std::move(paren))},
                                   .op{"*"},
                                   .right{std::make_unique<ast::Expr>(ast::TokenExpr{.text{"c"}})}};

        REQUIRE(emit::test::render(mult) == "(a + b) * c");
    }

    SECTION("Nested parentheses")
    {
        ast::ParenExpr inner{.inner{std::make_unique<ast::Expr>(ast::TokenExpr{.text{"x"}})}};

        const ast::ParenExpr outer{.inner{std::make_unique<ast::Expr>(std::move(inner))}};

        REQUIRE(emit::test::render(outer) == "((x))");
    }
}
