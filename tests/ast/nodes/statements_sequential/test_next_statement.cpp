#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("NextStatement: Simple next in for loop", "[statements_sequential][next_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
        begin
            process
            begin
                for i in 0 to 10 loop
                    next;
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
    const auto &next_stmt = std::get<ast::NextStatement>(loop.body[0]);
    REQUIRE_FALSE(next_stmt.loop_label.has_value());
    REQUIRE_FALSE(next_stmt.condition.has_value());
}

TEST_CASE("NextStatement: Next with condition", "[statements_sequential][next_statement]")
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
                    next when i mod 2 = 0;
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
    const auto &next_stmt = std::get<ast::NextStatement>(loop.body[0]);
    REQUIRE_FALSE(next_stmt.loop_label.has_value());
    const auto &cond = std::get<ast::BinaryExpr>(next_stmt.condition.value());
    REQUIRE(cond.op == "=");
    const auto &left = std::get<ast::BinaryExpr>(*cond.left);
    REQUIRE(left.op == "mod");
    REQUIRE(std::get<ast::TokenExpr>(*left.left).text == "i");
    REQUIRE(std::get<ast::TokenExpr>(*left.right).text == "2");
    REQUIRE(std::get<ast::TokenExpr>(*cond.right).text == "0");
}

TEST_CASE("NextStatement: Next with loop label", "[statements_sequential][next_statement]")
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
                        next outer when j = 3;
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
    const auto &next_stmt = std::get<ast::NextStatement>(inner_loop.body[0]);
    REQUIRE(next_stmt.loop_label.value() == "outer");
    const auto &cond = std::get<ast::BinaryExpr>(next_stmt.condition.value());
    REQUIRE(cond.op == "=");
    REQUIRE(std::get<ast::TokenExpr>(*cond.left).text == "j");
    REQUIRE(std::get<ast::TokenExpr>(*cond.right).text == "3");
}
