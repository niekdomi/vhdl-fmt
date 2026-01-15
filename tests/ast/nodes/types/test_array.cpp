#include "ast/nodes/declarations.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/types.hpp"
#include "type_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string>
#include <variant>

TEST_CASE("TypeDecl: Array", "[builder][type][array]")
{
    SECTION("Unconstrained array")
    {
        const auto* decl =
          type_utils::parseType("type mem_t is array(natural range <>) of std_logic;");
        REQUIRE(decl != nullptr);
        REQUIRE(decl->name == "mem_t");

        const auto* def = std::get_if<ast::ArrayTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);
        REQUIRE(def->subtype.type_mark == "std_logic");

        // Verify it is stored as the string variant
        REQUIRE(def->indices.size() == 1);
        const auto* idx_name = std::get_if<std::string>(def->indices.data());
        REQUIRE(idx_name != nullptr);
        REQUIRE(*idx_name == "natural");
    }

    SECTION("Constrained array (Discrete Range)")
    {
        const auto* decl = type_utils::parseType("type byte_t is array(7 downto 0) of bit;");
        REQUIRE(decl != nullptr);

        const auto* def = std::get_if<ast::ArrayTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);
        REQUIRE(def->subtype.type_mark == "bit");

        // Verify it is stored as the Expr variant
        REQUIRE(def->indices.size() == 1);
        const auto* idx_expr = std::get_if<ast::Expr>(def->indices.data());
        REQUIRE(idx_expr != nullptr);

        // Drill down to ensure it parsed the BinaryExpr correctly
        const auto* bin = std::get_if<ast::BinaryExpr>(idx_expr);
        REQUIRE(bin != nullptr);
        REQUIRE(bin->op == "downto");
    }

    SECTION("Multi-dimensional constrained")
    {
        // Changed from invalid mixed syntax to valid 2D constrained array
        const auto* decl =
          type_utils::parseType("type matrix_t is array(0 to 3, 0 to 15) of real;");
        REQUIRE(decl != nullptr);

        const auto* def = std::get_if<ast::ArrayTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);
        REQUIRE(def->subtype.type_mark == "real");

        // 1. 0 to 3 -> Expr
        REQUIRE(def->indices.size() == 2);
        const auto* idx1 = std::get_if<ast::Expr>(def->indices.data());
        REQUIRE(idx1 != nullptr);
        REQUIRE(std::holds_alternative<ast::BinaryExpr>(*idx1));

        // 2. 0 to 15 -> Expr
        const auto* idx2 = std::get_if<ast::Expr>(&def->indices[1]);
        REQUIRE(idx2 != nullptr);
        REQUIRE(std::holds_alternative<ast::BinaryExpr>(*idx2));
    }

    SECTION("Array with Element Constraint")
    {
        const auto* decl = type_utils::parseType(
          "type word_array is array(0 to 3) of std_logic_vector(31 downto 0);");
        REQUIRE(decl != nullptr);

        const auto* def = std::get_if<ast::ArrayTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);
        REQUIRE(def->subtype.type_mark == "std_logic_vector");

        REQUIRE(def->subtype.constraint.has_value());
        const auto* constr = std::get_if<ast::IndexConstraint>(&def->subtype.constraint.value());
        REQUIRE(constr != nullptr);

        REQUIRE(constr->ranges.children.size() == 1);
        const auto* range_expr = std::get_if<ast::BinaryExpr>(constr->ranges.children.data());
        REQUIRE(range_expr != nullptr);
        REQUIRE(range_expr->op == "downto");
    }
}
