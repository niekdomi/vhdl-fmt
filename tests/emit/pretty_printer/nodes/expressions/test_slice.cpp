#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <utility>

TEST_CASE("SliceExpr Rendering", "[pretty_printer][expressions][slice]")
{
    SECTION("Simple slice with downto")
    {
        ast::BinaryExpr range{ .left{ std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "7" } }) },
                               .op{ "downto" },
                               .right{
                                 std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "0" } }) } };

        const ast::SliceExpr slice{ .prefix{ std::make_unique<ast::Expr>(
                                      ast::TokenExpr{ .text{ "data" } }) },
                                    .range{ std::make_unique<ast::Expr>(std::move(range)) } };

        REQUIRE(emit::test::render(slice) == "data(7 downto 0)");
    }

    SECTION("Slice with to direction")
    {
        ast::BinaryExpr range{ .left{ std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "0" } }) },
                               .op{ "to" },
                               .right{
                                 std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "7" } }) } };

        const ast::SliceExpr slice{ .prefix{ std::make_unique<ast::Expr>(
                                      ast::TokenExpr{ .text{ "data" } }) },
                                    .range{ std::make_unique<ast::Expr>(std::move(range)) } };

        REQUIRE(emit::test::render(slice) == "data(0 to 7)");
    }
}
