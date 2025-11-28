#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("ForLoop: Simple for loop with range", "[statements_sequential][for_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic);
        end E;
        architecture A of E is
        begin
            process(clk)
            begin
                for i in 0 to 7 loop
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

    const auto &for_loop = std::get<ast::ForLoop>(proc.body[0]);
    REQUIRE(for_loop.iterator == "i");
    const auto &range = std::get<ast::BinaryExpr>(for_loop.range);
    REQUIRE(range.op == "to");
    REQUIRE(std::get<ast::TokenExpr>(*range.left).text == "0");
    REQUIRE(std::get<ast::TokenExpr>(*range.right).text == "7");
    REQUIRE(for_loop.body.empty());
}

TEST_CASE("ForLoop: For loop with downto range", "[statements_sequential][for_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic);
        end E;
        architecture A of E is
        begin
            process(clk)
            begin
                for j in 15 downto 0 loop
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

    const auto &for_loop = std::get<ast::ForLoop>(proc.body[0]);
    REQUIRE(for_loop.iterator == "j");
    const auto &range = std::get<ast::BinaryExpr>(for_loop.range);
    REQUIRE(range.op == "downto");
    REQUIRE(std::get<ast::TokenExpr>(*range.left).text == "15");
    REQUIRE(std::get<ast::TokenExpr>(*range.right).text == "0");
}

TEST_CASE("ForLoop: For loop with body statements", "[statements_sequential][for_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            process(clk)
            begin
                for k in 0 to 3 loop
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

    const auto &for_loop = std::get<ast::ForLoop>(proc.body[0]);
    REQUIRE(for_loop.iterator == "k");
    const auto &range = std::get<ast::BinaryExpr>(for_loop.range);
    REQUIRE(range.op == "to");
    REQUIRE(std::get<ast::TokenExpr>(*range.left).text == "0");
    REQUIRE(std::get<ast::TokenExpr>(*range.right).text == "3");
    REQUIRE(for_loop.body.size() == 1);

    const auto &assign = std::get<ast::SequentialAssign>(for_loop.body[0]);
    REQUIRE(std::get<ast::TokenExpr>(assign.value).text == "'1'");
}
