#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("WhileLoop: Simple while loop", "[statements_sequential][while_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic);
        end E;
        architecture A of E is
        begin
            process(clk)
                variable counter : integer := 0;
            begin
                while counter < 10 loop
                end loop;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &while_loop = std::get<ast::WhileLoop>(proc.body[0]);
    const auto &condition = std::get<ast::BinaryExpr>(while_loop.condition);
    REQUIRE(condition.op == "<");
    REQUIRE(std::get<ast::TokenExpr>(*condition.left).text == "counter");
    REQUIRE(std::get<ast::TokenExpr>(*condition.right).text == "10");
    REQUIRE(while_loop.body.empty());
}

TEST_CASE("WhileLoop: While loop with boolean condition", "[statements_sequential][while_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic);
        end E;
        architecture A of E is
        begin
            process(clk)
                variable done : boolean := false;
            begin
                while not done loop
                end loop;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &while_loop = std::get<ast::WhileLoop>(proc.body[0]);
    const auto &condition = std::get<ast::UnaryExpr>(while_loop.condition);
    REQUIRE(condition.op == "not");
    REQUIRE(std::get<ast::TokenExpr>(*condition.value).text == "done");
}

TEST_CASE("WhileLoop: While loop with body statements", "[statements_sequential][while_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            process(clk)
                variable count : integer := 0;
            begin
                while count < 5 loop
                    y <= '1';
                end loop;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &while_loop = std::get<ast::WhileLoop>(proc.body[0]);
    REQUIRE(std::get<ast::BinaryExpr>(while_loop.condition).op == "<");
    REQUIRE(std::get<ast::TokenExpr>(*std::get<ast::BinaryExpr>(while_loop.condition).left).text
            == "count");
    REQUIRE(std::get<ast::TokenExpr>(*std::get<ast::BinaryExpr>(while_loop.condition).right).text
            == "5");
    REQUIRE(while_loop.body.size() == 1);

    const auto &assign = std::get<ast::SequentialAssign>(while_loop.body[0]);
    REQUIRE(std::get<ast::TokenExpr>(assign.value).text == "'1'");
}
