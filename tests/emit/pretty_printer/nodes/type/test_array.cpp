#include "ast/nodes/declarations.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/types.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <string>
#include <utility>

TEST_CASE("TypeDecl: Array", "[pretty_printer][type][array]")
{
    ast::TypeDecl type_decl{};
    type_decl.name = "mem_t";

    SECTION("Unconstrained array")
    {
        ast::ArrayTypeDef array_def{};
        array_def.subtype.type_mark = "std_logic";
        // indices = "natural" (string variant) -> renders as "natural range <>"
        array_def.indices.emplace_back("natural");
        type_decl.type_def = std::move(array_def);

        REQUIRE(emit::test::render(type_decl)
                == "type mem_t is array(natural range <>) of std_logic;");
    }

    SECTION("Constrained array (range expression)")
    {
        ast::ArrayTypeDef array_def{};
        array_def.subtype.type_mark = "std_logic";
        // indices = Expr (0 to 1023)
        auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });
        auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "1023" });

        ast::BinaryExpr range_expr{};
        range_expr.left = std::move(left);
        range_expr.op = "to";
        range_expr.right = std::move(right);

        array_def.indices.emplace_back(ast::Expr(std::move(range_expr)));
        type_decl.type_def = std::move(array_def);

        REQUIRE(emit::test::render(type_decl) == "type mem_t is array(0 to 1023) of std_logic;");
    }

    SECTION("Multi-dimensional mixed array")
    {
        ast::ArrayTypeDef array_def{};
        array_def.subtype.type_mark = "std_logic";
        // indices = ["integer", Expr(0 to 3)]
        array_def.indices.emplace_back("integer"); // Unconstrained

        auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });
        auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "3" });

        ast::BinaryExpr range_expr{};
        range_expr.left = std::move(left);
        range_expr.op = "to";
        range_expr.right = std::move(right);

        array_def.indices.emplace_back(ast::Expr(std::move(range_expr))); // Constrained

        type_decl.type_def = std::move(array_def);

        REQUIRE(emit::test::render(type_decl)
                == "type mem_t is array(integer range <>, 0 to 3) of std_logic;");
    }

    SECTION("Array with element constraint")
    {
        ast::ArrayTypeDef array_def{};
        // type ram_t is array (0 to 63) of std_logic_vector(7 downto 0);
        array_def.subtype.type_mark = "std_logic_vector";

        // Add index constraint for the array itself
        auto arr_left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });
        auto arr_right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "63" });
        ast::BinaryExpr arr_range{ .left = std::move(arr_left),
                                   .op = "to",
                                   .right = std::move(arr_right) };
        array_def.indices.emplace_back(ast::Expr(std::move(arr_range)));

        // Add constraint for the element type
        auto elem_left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "7" });
        auto elem_right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });
        ast::BinaryExpr elem_range{ .left = std::move(elem_left),
                                    .op = "downto",
                                    .right = std::move(elem_right) };

        ast::IndexConstraint constr{};
        constr.ranges.children.emplace_back(std::move(elem_range));
        array_def.subtype.constraint = std::move(constr);

        type_decl.type_def = std::move(array_def);

        REQUIRE(emit::test::render(type_decl)
                == "type mem_t is array(0 to 63) of std_logic_vector(7 downto 0);");
    }
}
