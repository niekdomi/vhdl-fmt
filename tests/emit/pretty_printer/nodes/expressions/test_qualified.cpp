#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>

TEST_CASE("QualifiedExpr Rendering", "[pretty_printer][expressions][qualified]")
{
    SECTION("Simple qualified expression")
    {
        ast::QualifiedExpr qual{ .type_mark{ "integer" },
                                 .operand{
                                   std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "42" } }) } };

        REQUIRE(emit::test::render(qual) == "integer'42");
    }

    SECTION("Qualified aggregate")
    {
        ast::GroupExpr group;
        group.children.push_back(ast::TokenExpr{ .text{ "'1'" } });
        group.children.push_back(ast::TokenExpr{ .text{ "'0'" } });

        ast::QualifiedExpr qual{ .type_mark{ "std_logic_vector" },
                                 .operand{ std::make_unique<ast::Expr>(std::move(group)) } };

        REQUIRE(emit::test::render(qual) == "std_logic_vector'('1', '0')");
    }

    SECTION("Qualified with named association")
    {
        ast::BinaryExpr assoc{
            .left{ std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "others" } }) },
            .op{ "=>" },
            .right{ std::make_unique<ast::Expr>(ast::TokenExpr{ .text{ "'0'" } }) }
        };

        ast::GroupExpr group;
        group.children.push_back(std::move(assoc));

        ast::QualifiedExpr qual{ .type_mark{ "std_logic_vector" },
                                 .operand{ std::make_unique<ast::Expr>(std::move(group)) } };

        REQUIRE(emit::test::render(qual) == "std_logic_vector'(others => '0')");
    }
}
