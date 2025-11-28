#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("RangeConstraint: Range constraint with integer subtype",
          "[constraints_ranges][range_constraint]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            subtype byte_range is integer range 0 to 255;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &subtype = std::get<ast::SubtypeDecl>(arch.decls[0]);
    REQUIRE(subtype.constraint.has_value());

    const auto &range_constraint = std::get<ast::RangeConstraint>(subtype.constraint.value());
    const auto &range = range_constraint.range;
    REQUIRE(range.op == "to");
    REQUIRE(range.left != nullptr);
    REQUIRE(range.right != nullptr);

    const auto &left_token = std::get<ast::TokenExpr>(*range.left);
    const auto &right_token = std::get<ast::TokenExpr>(*range.right);
    REQUIRE(left_token.text == "0");
    REQUIRE(right_token.text == "255");
}

TEST_CASE("RangeConstraint: Range constraint with downto direction",
          "[constraints_ranges][range_constraint]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            subtype countdown is integer range 100 downto 0;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &subtype = std::get<ast::SubtypeDecl>(arch.decls[0]);
    REQUIRE(subtype.constraint.has_value());
    const auto &range_constraint = std::get<ast::RangeConstraint>(subtype.constraint.value());
    const auto &range = range_constraint.range;
    REQUIRE(range.op == "downto");
    REQUIRE(range.left != nullptr);
    REQUIRE(range.right != nullptr);
    const auto &left_token = std::get<ast::TokenExpr>(*range.left);
    const auto &right_token = std::get<ast::TokenExpr>(*range.right);
    REQUIRE(left_token.text == "100");
    REQUIRE(right_token.text == "0");
}
