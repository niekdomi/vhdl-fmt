#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("ParenExpr: Parenthesized expression for precedence", "[expressions][paren_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a, b, c : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            y <= (a and b) or c;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    const auto &binary = std::get<ast::BinaryExpr>(assign.value);
    REQUIRE(binary.op == "or");
    REQUIRE(binary.left != nullptr);
    REQUIRE(binary.right != nullptr);

    const auto &left_paren = std::get<ast::ParenExpr>(*binary.left);
    REQUIRE(left_paren.inner != nullptr);
    const auto &inner_binary = std::get<ast::BinaryExpr>(*left_paren.inner);
    REQUIRE(inner_binary.op == "and");

    const auto &right_token = std::get<ast::TokenExpr>(*binary.right);
    REQUIRE(right_token.text == "c");
}

TEST_CASE("ParenExpr: Nested parentheses", "[expressions][paren_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            constant RESULT : integer := ((5 + 3) * 2);
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &constant = std::get<ast::ConstantDecl>(arch.decls[0]);
    REQUIRE(constant.init_expr.has_value());

    const auto &outer_paren = std::get<ast::ParenExpr>(constant.init_expr.value());
    REQUIRE(outer_paren.inner != nullptr);

    const auto &mul_expr = std::get<ast::BinaryExpr>(*outer_paren.inner);
    REQUIRE(mul_expr.op == "*");
    REQUIRE(mul_expr.left != nullptr);
    REQUIRE(mul_expr.right != nullptr);

    const auto &inner_paren = std::get<ast::ParenExpr>(*mul_expr.left);
    REQUIRE(inner_paren.inner != nullptr);
    const auto &add_expr = std::get<ast::BinaryExpr>(*inner_paren.inner);
    REQUIRE(add_expr.op == "+");
}
