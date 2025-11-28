#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("CaseStatement: Simple case statement", "[statements_sequential][case_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (sel : in integer; y : out std_logic);
        end E;
        architecture A of E is
        begin
            process(sel)
            begin
                case sel is
                    when 0 =>
                        y <= '0';
                    when 1 =>
                        y <= '1';
                    when others =>
                        y <= 'X';
                end case;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &case_stmt = std::get<ast::CaseStatement>(proc.body[0]);
    const auto &selector = std::get<ast::TokenExpr>(case_stmt.selector);
    REQUIRE(selector.text == "sel");
    REQUIRE(case_stmt.when_clauses.size() == 3);
    REQUIRE(case_stmt.when_clauses[0].body.size() == 1);
    REQUIRE(case_stmt.when_clauses[1].body.size() == 1);
    REQUIRE(case_stmt.when_clauses[2].body.size() == 1);
    REQUIRE(std::get<ast::TokenExpr>(case_stmt.when_clauses[0].choices[0]).text == "0");
    REQUIRE(std::get<ast::TokenExpr>(case_stmt.when_clauses[1].choices[0]).text == "1");
    REQUIRE(std::get<ast::TokenExpr>(case_stmt.when_clauses[2].choices[0]).text == "others");
    const auto &assign0 = std::get<ast::SequentialAssign>(case_stmt.when_clauses[0].body[0]);
    REQUIRE(std::get<ast::TokenExpr>(assign0.target).text == "y");
    REQUIRE(std::get<ast::TokenExpr>(assign0.value).text == "'0'");
}

TEST_CASE("CaseStatement: Case with multiple choices", "[statements_sequential][case_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (sel : in integer; y : out std_logic);
        end E;
        architecture A of E is
        begin
            process(sel)
            begin
                case sel is
                    when 0 | 2 | 4 =>
                        y <= '0';
                    when 1 | 3 | 5 =>
                        y <= '1';
                    when others =>
                        y <= 'X';
                end case;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &case_stmt = std::get<ast::CaseStatement>(proc.body[0]);
    REQUIRE(std::get<ast::TokenExpr>(case_stmt.selector).text == "sel");
    REQUIRE(case_stmt.when_clauses.size() == 3);
    REQUIRE(case_stmt.when_clauses[0].choices.size() == 3);
    REQUIRE(case_stmt.when_clauses[1].choices.size() == 3);
    REQUIRE(std::get<ast::TokenExpr>(case_stmt.when_clauses[0].choices[0]).text == "0");
    REQUIRE(std::get<ast::TokenExpr>(case_stmt.when_clauses[0].choices[1]).text == "2");
    REQUIRE(std::get<ast::TokenExpr>(case_stmt.when_clauses[0].choices[2]).text == "4");
    REQUIRE(std::get<ast::TokenExpr>(case_stmt.when_clauses[1].choices[0]).text == "1");
}

TEST_CASE("CaseStatement: Case with multiple statements per when",
          "[statements_sequential][case_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (sel : in integer; x, y : out std_logic);
        end E;
        architecture A of E is
        begin
            process(sel)
            begin
                case sel is
                    when 0 =>
                        x <= '0';
                        y <= '0';
                    when 1 =>
                        x <= '1';
                        y <= '1';
                    when others =>
                        x <= 'X';
                        y <= 'X';
                end case;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &case_stmt = std::get<ast::CaseStatement>(proc.body[0]);
    REQUIRE(std::get<ast::TokenExpr>(case_stmt.selector).text == "sel");
    REQUIRE(case_stmt.when_clauses.size() == 3);
    REQUIRE(case_stmt.when_clauses[0].body.size() == 2);
    REQUIRE(case_stmt.when_clauses[1].body.size() == 2);
    REQUIRE(case_stmt.when_clauses[2].body.size() == 2);
    const auto &assign = std::get<ast::SequentialAssign>(case_stmt.when_clauses[1].body[0]);
    REQUIRE(std::get<ast::TokenExpr>(assign.target).text == "x");
    REQUIRE(std::get<ast::TokenExpr>(assign.value).text == "'1'");
}
