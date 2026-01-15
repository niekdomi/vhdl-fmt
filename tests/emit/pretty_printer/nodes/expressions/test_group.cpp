#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <utility>

TEST_CASE("GroupExpr Rendering", "[pretty_printer][expressions][group]")
{
    SECTION("Positional association")
    {
        ast::GroupExpr group{};
        group.children.emplace_back(ast::TokenExpr{.text = "'1'"});
        group.children.emplace_back(ast::TokenExpr{.text = "'0'"});
        group.children.emplace_back(ast::TokenExpr{.text = "'1'"});

        REQUIRE(emit::test::render(group) == "('1', '0', '1')");
    }

    SECTION("Named association")
    {
        ast::BinaryExpr assoc{.left = std::make_unique<ast::Expr>(ast::TokenExpr{.text = "addr"}),
                              .op = "=>",
                              .right =
                                std::make_unique<ast::Expr>(ast::TokenExpr{.text = R"(x\"AB\")"})};

        ast::GroupExpr group{};
        group.children.emplace_back(std::move(assoc));

        REQUIRE(emit::test::render(group) == "(addr => x\\\"AB\\\")");
    }

    SECTION("Others association")
    {
        ast::BinaryExpr assoc{
          .left = std::make_unique<ast::Expr>(ast::TokenExpr{.text = "others"}),
          .op = "=>",
          .right = std::make_unique<ast::Expr>(ast::TokenExpr{.text = "'0'"}),
        };

        ast::GroupExpr group{};
        group.children.emplace_back(std::move(assoc));

        REQUIRE(emit::test::render(group) == "(others => '0')");
    }

    SECTION("Nested aggregates")
    {
        ast::GroupExpr inner{};
        inner.children.emplace_back(ast::TokenExpr{.text = "'1'"});
        inner.children.emplace_back(ast::TokenExpr{.text = "'0'"});

        ast::GroupExpr outer{};
        outer.children.emplace_back(std::move(inner));

        REQUIRE(emit::test::render(outer) == "(('1', '0'))");
    }
}
