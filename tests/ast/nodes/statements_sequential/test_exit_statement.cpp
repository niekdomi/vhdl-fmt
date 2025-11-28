#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("ExitStatement: Simple exit in for loop", "[statements_sequential][exit_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
        begin
            process
            begin
                for i in 0 to 10 loop
                    exit;
                end loop;
                wait;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 2);
    const auto &loop = std::get<ast::ForLoop>(proc.body[0]);
    REQUIRE(loop.body.size() == 1);
    const auto &exit_stmt = std::get<ast::ExitStatement>(loop.body[0]);
    REQUIRE_FALSE(exit_stmt.loop_label.has_value());
    REQUIRE_FALSE(exit_stmt.condition.has_value());
    REQUIRE(std::holds_alternative<ast::WaitStatement>(proc.body[1]));
}

TEST_CASE("ExitStatement: Exit with condition", "[statements_sequential][exit_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            signal counter : integer := 0;
        begin
            process
            begin
                for i in 0 to 100 loop
                    exit when i = 50;
                    counter <= counter + 1;
                end loop;
                wait;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 2);
    const auto &loop = std::get<ast::ForLoop>(proc.body[0]);
    REQUIRE(loop.body.size() == 2);
    const auto &exit_stmt = std::get<ast::ExitStatement>(loop.body[0]);
    REQUIRE_FALSE(exit_stmt.loop_label.has_value());
    const auto &cond = std::get<ast::BinaryExpr>(exit_stmt.condition.value());
    REQUIRE(cond.op == "=");
    REQUIRE(std::get<ast::TokenExpr>(*cond.left).text == "i");
    REQUIRE(std::get<ast::TokenExpr>(*cond.right).text == "50");
}

TEST_CASE("ExitStatement: Exit with loop label", "[statements_sequential][exit_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
        begin
            process
            begin
                outer: for i in 0 to 5 loop
                    for j in 0 to 5 loop
                        exit outer when j = 3;
                    end loop;
                end loop outer;
                wait;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 2);
    const auto &outer_loop = std::get<ast::ForLoop>(proc.body[0]);
    REQUIRE(outer_loop.body.size() == 1);
    const auto &inner_loop = std::get<ast::ForLoop>(outer_loop.body[0]);
    REQUIRE(inner_loop.body.size() == 1);
    const auto &exit_stmt = std::get<ast::ExitStatement>(inner_loop.body[0]);
    REQUIRE(exit_stmt.loop_label.value() == "outer");
    const auto &cond = std::get<ast::BinaryExpr>(exit_stmt.condition.value());
    REQUIRE(cond.op == "=");
    REQUIRE(std::get<ast::TokenExpr>(*cond.left).text == "j");
    REQUIRE(std::get<ast::TokenExpr>(*cond.right).text == "3");
}
