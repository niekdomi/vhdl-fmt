#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("IndexConstraint: Single range constraint", "[constraints_ranges][index_constraint]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (data : in std_logic_vector(7 downto 0));
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.port_clause.ports.size() == 1);

    const auto &port = entity.port_clause.ports[0];
    REQUIRE(port.constraint.has_value());

    const auto &index_constraint = std::get<ast::IndexConstraint>(port.constraint.value());
    REQUIRE(index_constraint.ranges.children.size() == 1);

    REQUIRE_FALSE(index_constraint.ranges.children.empty());

    const auto &range_expr = std::get<ast::BinaryExpr>(index_constraint.ranges.children[0]);
    REQUIRE(range_expr.op == "downto");
    REQUIRE(range_expr.left != nullptr);
    REQUIRE(range_expr.right != nullptr);

    const auto &left_token = std::get<ast::TokenExpr>(*range_expr.left);
    const auto &right_token = std::get<ast::TokenExpr>(*range_expr.right);
    REQUIRE(left_token.text == "7");
    REQUIRE(right_token.text == "0");
}

TEST_CASE("IndexConstraint: Ascending range constraint", "[constraints_ranges][index_constraint]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (data : out std_logic_vector(0 to 15));
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.port_clause.ports.size() == 1);

    const auto &port = entity.port_clause.ports[0];
    REQUIRE(port.constraint.has_value());

    const auto &index_constraint = std::get<ast::IndexConstraint>(port.constraint.value());
    REQUIRE(index_constraint.ranges.children.size() == 1);

    REQUIRE_FALSE(index_constraint.ranges.children.empty());

    const auto &range_expr = std::get<ast::BinaryExpr>(index_constraint.ranges.children[0]);
    REQUIRE(range_expr.op == "to");
    REQUIRE(range_expr.left != nullptr);
    REQUIRE(range_expr.right != nullptr);

    const auto &left_token = std::get<ast::TokenExpr>(*range_expr.left);
    const auto &right_token = std::get<ast::TokenExpr>(*range_expr.right);
    REQUIRE(left_token.text == "0");
    REQUIRE(right_token.text == "15");
}

TEST_CASE("IndexConstraint: Multi-dimensional array constraint",
          "[constraints_ranges][index_constraint]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            type matrix_t is array (integer range <>, integer range <>) of std_logic;
            signal matrix : matrix_t(0 to 7, 0 to 3);
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 2);
    const auto &type_decl = std::get<ast::TypeDecl>(arch.decls[0]);
    (void)type_decl;
    const auto &signal = std::get<ast::SignalDecl>(arch.decls[1]);
    REQUIRE(signal.constraint.has_value());

    const auto &index_constraint = std::get<ast::IndexConstraint>(signal.constraint.value());
    REQUIRE(index_constraint.ranges.children.size() == 2);

    REQUIRE_FALSE(index_constraint.ranges.children.empty());

    const auto &first_range = std::get<ast::BinaryExpr>(index_constraint.ranges.children[0]);
    REQUIRE(first_range.op == "to");
    REQUIRE(first_range.left != nullptr);
    REQUIRE(first_range.right != nullptr);
    REQUIRE(std::get<ast::TokenExpr>(*first_range.left).text == "0");
    REQUIRE(std::get<ast::TokenExpr>(*first_range.right).text == "7");

    REQUIRE(index_constraint.ranges.children.size() > 1);
    const auto &second_range = std::get<ast::BinaryExpr>(index_constraint.ranges.children[1]);
    REQUIRE(second_range.op == "to");
    REQUIRE(second_range.left != nullptr);
    REQUIRE(second_range.right != nullptr);
    REQUIRE(std::get<ast::TokenExpr>(*second_range.left).text == "0");
    REQUIRE(std::get<ast::TokenExpr>(*second_range.right).text == "3");
}

TEST_CASE("Constraint: Range constraint in subtype", "[constraints_ranges][constraint]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            subtype small_int is integer range 0 to 100;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);
    const auto &subtype_decl = std::get<ast::SubtypeDecl>(arch.decls[0]);
    (void)subtype_decl;
}

TEST_CASE("DiscreteRange: Explicit range in for loop", "[constraints_ranges][discrete_range]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
        begin
            process
            begin
                for i in 0 to 10 loop
                    null;
                end loop;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &loop = std::get<ast::ForLoop>(proc.body[0]);
    REQUIRE(loop.iterator == "i");
    // Range is stored as generic Expr - verify it exists
    const auto &range_binary = std::get<ast::BinaryExpr>(loop.range);
    REQUIRE(range_binary.op == "to");
}

TEST_CASE("ExplicitRange: Range in array type", "[constraints_ranges][explicit_range]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            type arr_type is array (0 to 7) of std_logic;
        begin
        end A;
    )";

    // TypeDecl and ArrayType not yet implemented - just verify parsing succeeds
    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE_FALSE(arch.decls.empty());
}
