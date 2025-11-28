#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("CallExpr: Function call expression", "[expressions][call_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic; q : out std_logic);
        end E;
        architecture A of E is
        begin
            process(clk)
            begin
                if rising_edge(clk) then
                    q <= '1';
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

    const auto &call = std::get<ast::CallExpr>(if_stmt.if_branch.condition);
    REQUIRE(call.callee != nullptr);
    const auto &callee_token = std::get<ast::TokenExpr>(*call.callee);
    REQUIRE(callee_token.text == "rising_edge");
    REQUIRE(call.args != nullptr);
    const auto &arg_token = std::get<ast::TokenExpr>(*call.args);
    REQUIRE(arg_token.text == "clk");
}

TEST_CASE("CallExpr: Array indexing as call expression", "[expressions][call_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (data : in std_logic_vector(7 downto 0); bit_out : out std_logic);
        end E;
        architecture A of E is
        begin
            bit_out <= data(3);
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    const auto &call = std::get<ast::CallExpr>(assign.value);
    REQUIRE(call.callee != nullptr);
    const auto &callee_token = std::get<ast::TokenExpr>(*call.callee);
    REQUIRE(callee_token.text == "data");
    REQUIRE(call.args != nullptr);
    const auto &arg_token = std::get<ast::TokenExpr>(*call.args);
    REQUIRE(arg_token.text == "3");
}
