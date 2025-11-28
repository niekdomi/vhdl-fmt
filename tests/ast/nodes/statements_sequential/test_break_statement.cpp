#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("BreakStatement: Simple break statement", "[statements_sequential][break_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
        begin
            process
            begin
                break when true;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &break_stmt = std::get<ast::BreakStatement>(proc.body[0]);
    REQUIRE(break_stmt.break_elements.empty());
    // Simple break with when condition
    REQUIRE(std::get<ast::TokenExpr>(break_stmt.condition.value()).text == "true");
}

TEST_CASE("BreakStatement: Break with elements", "[statements_sequential][break_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            quantity q1, q2 : real;
        begin
            process
            begin
                break q1 => 1.0, q2 => 2.0 when clk = '1';
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &break_stmt = std::get<ast::BreakStatement>(proc.body[0]);
    REQUIRE(break_stmt.break_elements.size() == 2);
    const auto &first = std::get<ast::BinaryExpr>(break_stmt.break_elements[0]);
    REQUIRE(first.op == "=>");
    REQUIRE(std::get<ast::TokenExpr>(*first.left).text == "q1");
    REQUIRE(std::get<ast::TokenExpr>(*first.right).text == "1.0");
    const auto &second = std::get<ast::BinaryExpr>(break_stmt.break_elements[1]);
    REQUIRE(second.op == "=>");
    REQUIRE(std::get<ast::TokenExpr>(*second.left).text == "q2");
    REQUIRE(std::get<ast::TokenExpr>(*second.right).text == "2.0");
    const auto &cond = std::get<ast::BinaryExpr>(break_stmt.condition.value());
    REQUIRE(cond.op == "=");
    REQUIRE(std::get<ast::TokenExpr>(*cond.left).text == "clk");
    REQUIRE(std::get<ast::TokenExpr>(*cond.right).text == "'1'");
}
