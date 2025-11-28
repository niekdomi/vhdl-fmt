#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("WaitStatement: Simple wait statement", "[statements_sequential][wait_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic);
        end E;
        architecture A of E is
        begin
            process
            begin
                wait;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &wait_stmt = std::get<ast::WaitStatement>(proc.body[0]);
    REQUIRE_FALSE(wait_stmt.condition.has_value());
    REQUIRE(wait_stmt.sensitivity_list.empty());
    REQUIRE_FALSE(wait_stmt.timeout.has_value());
}

TEST_CASE("WaitStatement: Wait until with condition", "[statements_sequential][wait_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic);
        end E;
        architecture A of E is
        begin
            process
            begin
                wait until clk = '1';
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &wait_stmt = std::get<ast::WaitStatement>(proc.body[0]);
    REQUIRE(wait_stmt.condition.has_value());
    const auto &cond = std::get<ast::BinaryExpr>(wait_stmt.condition.value());
    REQUIRE(cond.op == "=");
    REQUIRE(wait_stmt.sensitivity_list.empty());
    REQUIRE(std::get<ast::TokenExpr>(*cond.left).text == "clk");
    REQUIRE(std::get<ast::TokenExpr>(*cond.right).text == "'1'");
}

TEST_CASE("WaitStatement: Wait on sensitivity list", "[statements_sequential][wait_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk, reset : in std_logic);
        end E;
        architecture A of E is
        begin
            process
            begin
                wait on clk, reset;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &wait_stmt = std::get<ast::WaitStatement>(proc.body[0]);
    REQUIRE_FALSE(wait_stmt.condition.has_value());
    REQUIRE(wait_stmt.sensitivity_list.size() == 2);
    REQUIRE(wait_stmt.sensitivity_list[0] == "clk");
    REQUIRE(wait_stmt.sensitivity_list[1] == "reset");
}
