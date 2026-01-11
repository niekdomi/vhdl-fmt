#include "ast/nodes/expressions.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("QualifiedExpr", "[expressions][qualified]")
{
    SECTION("Simple type qualification")
    {
        const auto *expr = test_helpers::parseExpr("integer'(42)");
        const auto *qual = std::get_if<ast::QualifiedExpr>(expr);
        REQUIRE(qual != nullptr);
        REQUIRE(qual->type_mark.type_mark == "integer");
        REQUIRE(qual->operand != nullptr);

        const ast::GroupExpr *group = qual->operand.get();
        REQUIRE(group != nullptr);

        const auto *operand = std::get_if<ast::TokenExpr>(group->children.data());
        REQUIRE(operand != nullptr);
        REQUIRE(operand->text == "42");
    }

    SECTION("Type qualification with aggregate")
    {
        const auto *expr = test_helpers::parseExpr("array_type'(1, 2, 3)");
        const auto *qual = std::get_if<ast::QualifiedExpr>(expr);
        REQUIRE(qual != nullptr);
        REQUIRE(qual->type_mark.type_mark == "array_type");
        REQUIRE(qual->operand != nullptr);

        const ast::GroupExpr *group = qual->operand.get();
        REQUIRE(group != nullptr);
        REQUIRE(group->children.size() == 3);
    }

    SECTION("Type qualification with named association")
    {
        const auto *expr = test_helpers::parseExpr("record_type'(field => value)");
        const auto *qual = std::get_if<ast::QualifiedExpr>(expr);
        REQUIRE(qual != nullptr);
        REQUIRE(qual->type_mark.type_mark == "record_type");
        REQUIRE(qual->operand != nullptr);

        const ast::GroupExpr *group = qual->operand.get();
        REQUIRE(group != nullptr);

        const auto *binary = std::get_if<ast::BinaryExpr>(group->children.data());
        REQUIRE(binary != nullptr);
        REQUIRE(binary->op == "=>");
    }

    SECTION("Qualified expression with subtype constraint")
    {
        // Example: vector(7 downto 0)'(others => '0')
        const auto *expr = test_helpers::parseExpr("vector(7 downto 0)'(others => '0')");
        const auto *qual = std::get_if<ast::QualifiedExpr>(expr);

        REQUIRE(qual != nullptr);
        REQUIRE(qual->type_mark.type_mark == "vector");

        // Check that the constraint was captured
        REQUIRE(qual->type_mark.constraint.has_value());

        // Verify it is an index constraint (parens)
        const auto *idx_constr
          = std::get_if<ast::IndexConstraint>(&qual->type_mark.constraint.value());
        REQUIRE(idx_constr != nullptr);
    }
}
