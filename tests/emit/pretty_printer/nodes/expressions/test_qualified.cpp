#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <optional>
#include <utility>

TEST_CASE("QualifiedExpr Rendering", "[pretty_printer][expressions][qualified]")
{
    SECTION("Simple qualified expression")
    {
        ast::ParenExpr inner{.inner{std::make_unique<ast::Expr>(ast::TokenExpr{.text{"42"}})}};

        // CHANGE: Initialize the SubtypeIndication struct instead of a raw string
        const ast::QualifiedExpr qual{
          .type_mark{
                     .resolution_func = std::nullopt,
                     .type_mark = "integer",
                     .constraint = std::nullopt,
                     },
          .operand{std::make_unique<ast::Expr>(std::move(inner))},
        };

        REQUIRE(emit::test::render(qual) == "integer'(42)");
    }

    SECTION("Qualified aggregate")
    {
        ast::GroupExpr group{};
        group.children.emplace_back(ast::TokenExpr{.text{"'1'"}});
        group.children.emplace_back(ast::TokenExpr{.text{"'0'"}});

        const ast::QualifiedExpr qual{
          .type_mark{
                     .resolution_func = std::nullopt,
                     .type_mark = "std_logic_vector",
                     .constraint = std::nullopt,
                     },
          .operand{std::make_unique<ast::Expr>(std::move(group))},
        };

        REQUIRE(emit::test::render(qual) == "std_logic_vector'('1', '0')");
    }

    SECTION("Qualified with named association")
    {
        ast::BinaryExpr assoc{
          .left{std::make_unique<ast::Expr>(ast::TokenExpr{.text{"others"}})},
          .op{"=>"},
          .right{std::make_unique<ast::Expr>(ast::TokenExpr{.text{"'0'"}})},
        };

        ast::GroupExpr group{};
        group.children.emplace_back(std::move(assoc));

        const ast::QualifiedExpr qual{
          .type_mark{
                     .resolution_func = std::nullopt,
                     .type_mark = "std_logic_vector",
                     .constraint = std::nullopt,
                     },
          .operand{std::make_unique<ast::Expr>(std::move(group))},
        };

        REQUIRE(emit::test::render(qual) == "std_logic_vector'(others => '0')");
    }

    SECTION("Qualified with constraint")
    {
        ast::GroupExpr group{};
        group.children.emplace_back(ast::TokenExpr{.text{"others"}});
        // (Simplified for brevity, usually others => '0')

        // Create constraint: (7 downto 0)
        auto left = std::make_unique<ast::Expr>(ast::TokenExpr{.text = "7"});
        auto right = std::make_unique<ast::Expr>(ast::TokenExpr{.text = "0"});
        ast::BinaryExpr range{
          .left = std::move(left),
          .op = "downto",
          .right = std::move(right),
        };

        ast::IndexConstraint constr;
        constr.ranges.children.emplace_back(std::move(range));

        const ast::QualifiedExpr qual{
          .type_mark{
                     .resolution_func = std::nullopt,
                     .type_mark = "std_logic_vector",
                     .constraint = std::move(constr),
                     },
          .operand{std::make_unique<ast::Expr>(std::move(group))},
        };

        // This ensures the constraint is printed before the tick '
        REQUIRE(emit::test::render(qual) == "std_logic_vector(7 downto 0)'(others)");
    }
}
