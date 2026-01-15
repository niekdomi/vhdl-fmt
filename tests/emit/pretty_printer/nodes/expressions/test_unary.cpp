#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>

TEST_CASE("UnaryExpr Rendering", "[pretty_printer][expressions][unary]")
{
    SECTION("Negation")
    {
        const ast::UnaryExpr unary{
          .op{"-"},
          .value{std::make_unique<ast::Expr>(ast::TokenExpr{.text{"x"}})},
        };

        REQUIRE(emit::test::render(unary) == "-x");
    }

    SECTION("Unary plus")
    {
        const ast::UnaryExpr unary{
          .op{"+"},
          .value{std::make_unique<ast::Expr>(ast::TokenExpr{.text{"42"}})},
        };

        REQUIRE(emit::test::render(unary) == "+42");
    }

    SECTION("Logical not")
    {
        const ast::UnaryExpr unary{
          .op{"not"},
          .value{std::make_unique<ast::Expr>(ast::TokenExpr{.text{"ready"}})},
        };

        REQUIRE(emit::test::render(unary) == "not ready");
    }
}
