#include "expr_utils.hpp"
#include "nodes/expressions.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("QualifiedExpr", "[expressions][qualified]")
{
    SECTION("Simple type qualification")
    {
        const auto *expr = expr_utils::parseExpr("integer'(42)");
        const auto *qual = std::get_if<ast::QualifiedExpr>(expr);
        REQUIRE(qual != nullptr);
        REQUIRE(qual->type_mark == "integer");
        REQUIRE(qual->operand != nullptr);

        const auto *group = std::get_if<ast::GroupExpr>(qual->operand.get());
        REQUIRE(group != nullptr);

        const auto *operand = std::get_if<ast::TokenExpr>(group->children.data());
        REQUIRE(operand != nullptr);
        REQUIRE(operand->text == "42");
    }

    SECTION("Type qualification with aggregate")
    {
        const auto *expr = expr_utils::parseExpr("array_type'(1, 2, 3)");
        const auto *qual = std::get_if<ast::QualifiedExpr>(expr);
        REQUIRE(qual != nullptr);
        REQUIRE(qual->type_mark == "array_type");
        REQUIRE(qual->operand != nullptr);

        const auto *group = std::get_if<ast::GroupExpr>(qual->operand.get());
        REQUIRE(group != nullptr);
        REQUIRE(group->children.size() == 3);
    }

    SECTION("Type qualification with named association")
    {
        const auto *expr = expr_utils::parseExpr("record_type'(field => value)");
        const auto *qual = std::get_if<ast::QualifiedExpr>(expr);
        REQUIRE(qual != nullptr);
        REQUIRE(qual->type_mark == "record_type");
        REQUIRE(qual->operand != nullptr);

        const auto *group = std::get_if<ast::GroupExpr>(qual->operand.get());
        REQUIRE(group != nullptr);

        const auto *binary = std::get_if<ast::BinaryExpr>(group->children.data());
        REQUIRE(binary != nullptr);
        REQUIRE(binary->op == "=>");
    }
}
