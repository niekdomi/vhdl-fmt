#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("IfStatement: Simple if statement", "[statements_sequential][if_statement]")
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
                    b <= '1';
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
    const auto &condition = std::get<ast::BinaryExpr>(if_stmt.if_branch.condition);
    REQUIRE(condition.op == "=");
    REQUIRE(std::get<ast::TokenExpr>(*condition.left).text == "a");
    REQUIRE(std::get<ast::TokenExpr>(*condition.right).text == "'1'");
    REQUIRE(if_stmt.if_branch.body.size() == 1);
    REQUIRE(if_stmt.elsif_branches.empty());
    REQUIRE_FALSE(if_stmt.else_branch.has_value());
}

TEST_CASE("IfStatement: If-elsif-else statement", "[statements_sequential][if_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (sel : in integer; y : out std_logic);
        end E;
        architecture A of E is
        begin
            process(sel)
            begin
                if sel = 0 then
                    y <= '0';
                elsif sel = 1 then
                    y <= '1';
                else
                    y <= 'X';
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
    REQUIRE(std::get<ast::BinaryExpr>(if_stmt.if_branch.condition).op == "=");
    REQUIRE(
      std::get<ast::TokenExpr>(*std::get<ast::BinaryExpr>(if_stmt.if_branch.condition).left).text
      == "sel");
    REQUIRE(
      std::get<ast::TokenExpr>(*std::get<ast::BinaryExpr>(if_stmt.if_branch.condition).right).text
      == "0");
    REQUIRE(if_stmt.if_branch.body.size() == 1);
    REQUIRE(if_stmt.elsif_branches.size() == 1);
    REQUIRE(std::get<ast::BinaryExpr>(if_stmt.elsif_branches[0].condition).op == "=");
    REQUIRE(std::get<ast::TokenExpr>(
              *std::get<ast::BinaryExpr>(if_stmt.elsif_branches[0].condition).right)
              .text
            == "1");
    REQUIRE(if_stmt.elsif_branches[0].body.size() == 1);
    REQUIRE(if_stmt.else_branch.has_value());
    REQUIRE(if_stmt.else_branch->body.size() == 1);
}

TEST_CASE("IfStatement: Nested if statements", "[statements_sequential][if_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a, b : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            process(a, b)
            begin
                if a = '1' then
                    if b = '1' then
                        y <= '1';
                    end if;
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

    const auto &outer_if = std::get<ast::IfStatement>(proc.body[0]);
    REQUIRE(std::get<ast::BinaryExpr>(outer_if.if_branch.condition).op == "=");
    REQUIRE(
      std::get<ast::TokenExpr>(*std::get<ast::BinaryExpr>(outer_if.if_branch.condition).left).text
      == "a");
    REQUIRE(
      std::get<ast::TokenExpr>(*std::get<ast::BinaryExpr>(outer_if.if_branch.condition).right).text
      == "'1'");
    REQUIRE(outer_if.if_branch.body.size() == 1);

    const auto &inner_if = std::get<ast::IfStatement>(outer_if.if_branch.body[0]);
    REQUIRE(std::get<ast::BinaryExpr>(inner_if.if_branch.condition).op == "=");
    REQUIRE(
      std::get<ast::TokenExpr>(*std::get<ast::BinaryExpr>(inner_if.if_branch.condition).left).text
      == "b");
    REQUIRE(
      std::get<ast::TokenExpr>(*std::get<ast::BinaryExpr>(inner_if.if_branch.condition).right).text
      == "'1'");
    REQUIRE(inner_if.if_branch.body.size() == 1);
}
