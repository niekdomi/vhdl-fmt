#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("UnaryExpr: Logical not operator", "[expressions][unary_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            y <= not a;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    const auto &unary = std::get<ast::UnaryExpr>(assign.value);
    REQUIRE(unary.op == "not");
    REQUIRE(unary.value != nullptr);
    const auto &operand = std::get<ast::TokenExpr>(*unary.value);
    REQUIRE(operand.text == "a");
}

TEST_CASE("UnaryExpr: Unary minus operator", "[expressions][unary_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            constant NEG_VALUE : integer := -42;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &constant = std::get<ast::ConstantDecl>(arch.decls[0]);
    REQUIRE(constant.init_expr.has_value());

    const auto &unary = std::get<ast::UnaryExpr>(constant.init_expr.value());
    REQUIRE(unary.op == "-");
    REQUIRE(unary.value != nullptr);
    const auto &operand = std::get<ast::TokenExpr>(*unary.value);
    REQUIRE(operand.text == "42");
}
