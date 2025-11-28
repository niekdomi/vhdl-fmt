#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("ProcedureCallStatement: Simple procedure call without parameters",
          "[statements_sequential][procedure_call_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            procedure reset_counter is
            begin
            end procedure;
        begin
            process
            begin
                reset_counter;
                wait;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    const auto &call = std::get<ast::ProcedureCall>(proc.body[0]);
    const auto &callee = std::get<ast::TokenExpr>(call.call);
    REQUIRE(callee.text == "reset_counter");
}

TEST_CASE("ProcedureCallStatement: Procedure call with parameters",
          "[statements_sequential][procedure_call_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            procedure increment(signal counter : inout integer) is
            begin
                counter <= counter + 1;
            end procedure;
            signal count : integer := 0;
        begin
            process
            begin
                increment(count);
                wait;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    const auto &call = std::get<ast::ProcedureCall>(proc.body[0]);
    const auto &call_expr = std::get<ast::CallExpr>(call.call);
    const auto &callee = std::get<ast::TokenExpr>(*call_expr.callee);
    REQUIRE(callee.text == "increment");
    const auto &arg = std::get<ast::TokenExpr>(*call_expr.args);
    REQUIRE(arg.text == "count");
}

TEST_CASE("ProcedureCallStatement: Built-in procedure call",
          "[statements_sequential][procedure_call_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
        begin
            process
                variable line_buf : line;
            begin
                write(line_buf, "Test message");
                wait;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    const auto &call = std::get<ast::ProcedureCall>(proc.body[0]);
    const auto &call_expr = std::get<ast::CallExpr>(call.call);
    const auto &callee = std::get<ast::TokenExpr>(*call_expr.callee);
    REQUIRE(callee.text == "write");
    const auto &args = std::get<ast::GroupExpr>(*call_expr.args);
    REQUIRE(args.children.size() == 2);
    REQUIRE(std::get<ast::TokenExpr>(args.children[0]).text == "line_buf");
    REQUIRE(std::get<ast::TokenExpr>(args.children[1]).text == "\"Test message\"");
}
