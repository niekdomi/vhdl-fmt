#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("TokenExpr: Simple identifier token", "[expressions][token_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a : in std_logic; b : out std_logic);
        end E;
        architecture A of E is
        begin
            b <= a;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    const auto &token_target = std::get<ast::TokenExpr>(assign.target);
    REQUIRE(token_target.text == "b");

    const auto &token_value = std::get<ast::TokenExpr>(assign.value);
    REQUIRE(token_value.text == "a");
}

TEST_CASE("TokenExpr: Numeric literal token", "[expressions][token_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            constant WIDTH : integer := 8;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &constant = std::get<ast::ConstantDecl>(arch.decls[0]);
    REQUIRE(constant.init_expr.has_value());

    const auto &token = std::get<ast::TokenExpr>(constant.init_expr.value());
    REQUIRE(token.text == "8");
}

TEST_CASE("TokenExpr: Character literal token", "[expressions][token_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a : in std_logic; b : out std_logic);
        end E;
        architecture A of E is
        begin
            process(a)
            begin
                if a = '1' then
                    b <= '0';
                end if;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &if_stmt = std::get<ast::IfStatement>(proc.body[0]);
    REQUIRE(if_stmt.if_branch.body.size() == 1);

    const auto &condition = std::get<ast::BinaryExpr>(if_stmt.if_branch.condition);
    REQUIRE(condition.op == "=");
    REQUIRE(condition.left != nullptr);
    REQUIRE(condition.right != nullptr);
    const auto &left_token = std::get<ast::TokenExpr>(*condition.left);
    const auto &right_token = std::get<ast::TokenExpr>(*condition.right);
    REQUIRE(left_token.text == "a");
    REQUIRE(right_token.text == "'1'");

    const auto &assign_stmt = std::get<ast::SequentialAssign>(if_stmt.if_branch.body[0]);
    const auto &value_token = std::get<ast::TokenExpr>(assign_stmt.value);
    REQUIRE(value_token.text == "'0'");
}
