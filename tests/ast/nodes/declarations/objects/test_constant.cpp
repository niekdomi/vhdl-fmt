#include "ast/nodes/declarations/objects.hpp"
#include "ast/nodes/expressions.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("Declaration: Constant", "[builder][decl][constant]")
{
    auto parse_decl = test_helpers::parseDecl<ast::ConstantDecl>;

    SECTION("Simple integer constant")
    {
        const auto *decl = parse_decl("constant WIDTH : integer := 8;");
        REQUIRE(decl != nullptr);

        REQUIRE(decl->names.size() == 1);
        REQUIRE(decl->names[0] == "WIDTH");

        // Check Subtype
        REQUIRE(decl->subtype.type_mark == "integer");
        REQUIRE_FALSE(decl->subtype.constraint.has_value());

        // Check Init Expr
        REQUIRE(decl->init_expr.has_value());
        const auto *lit = std::get_if<ast::TokenExpr>(&decl->init_expr.value());
        REQUIRE(lit != nullptr);
        REQUIRE(lit->text == "8");
    }

    SECTION("Constant with Range Constraint")
    {
        const auto *decl = parse_decl("constant VAL : integer range 0 to 255 := 10;");
        REQUIRE(decl != nullptr);

        REQUIRE(decl->subtype.type_mark == "integer");
        REQUIRE(decl->subtype.constraint.has_value());

        const auto *rc = std::get_if<ast::RangeConstraint>(&decl->subtype.constraint.value());
        REQUIRE(rc != nullptr);
        REQUIRE(rc->range.op == "to");
    }

    SECTION("Multiple constants in one line")
    {
        const auto *decl = parse_decl("constant A, B : std_logic := '0';");
        REQUIRE(decl != nullptr);

        REQUIRE(decl->names.size() == 2);
        REQUIRE(decl->names[0] == "A");
        REQUIRE(decl->names[1] == "B");
        REQUIRE(decl->subtype.type_mark == "std_logic");
    }
}
