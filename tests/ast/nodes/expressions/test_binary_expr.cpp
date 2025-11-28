#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("BinaryExpr: Simple binary expression with logical operator",
          "[expressions][binary_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a, b : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            y <= a and b;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    const auto &binary = std::get<ast::BinaryExpr>(assign.value);
    REQUIRE(binary.op == "and");
}

TEST_CASE("BinaryExpr: Range expression with downto", "[expressions][binary_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (data : out std_logic_vector(7 downto 0));
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

    const auto &range_expr = std::get<ast::BinaryExpr>(index_constraint.ranges.children[0]);
    REQUIRE(range_expr.op == "downto");
    REQUIRE(range_expr.left != nullptr);
    REQUIRE(range_expr.right != nullptr);
    const auto &left_token = std::get<ast::TokenExpr>(*range_expr.left);
    const auto &right_token = std::get<ast::TokenExpr>(*range_expr.right);
    REQUIRE(left_token.text == "7");
    REQUIRE(right_token.text == "0");
}

TEST_CASE("BinaryExpr: Arithmetic expression with multiple operators", "[expressions][binary_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            constant RESULT : integer := 10 + 5;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &constant = std::get<ast::ConstantDecl>(arch.decls[0]);
    REQUIRE(constant.init_expr.has_value());

    const auto &binary = std::get<ast::BinaryExpr>(constant.init_expr.value());
    REQUIRE(binary.op == "+");
}
