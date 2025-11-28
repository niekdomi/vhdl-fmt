#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("NullStatement: Simple null statement", "[statements_sequential][null_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
        begin
            process
            begin
                null;
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
    REQUIRE(std::holds_alternative<ast::NullStatement>(proc.body[0]));
    REQUIRE(std::holds_alternative<ast::WaitStatement>(proc.body[1]));
}

TEST_CASE("NullStatement: Null in case branch", "[statements_sequential][null_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (sel : in integer);
        end E;
        architecture A of E is
        begin
            process(sel)
            begin
                case sel is
                    when 0 =>
                        null;
                    when others =>
                        null;
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
    REQUIRE(case_stmt.when_clauses.size() == 2);
    REQUIRE(case_stmt.when_clauses[0].body.size() == 1);
    REQUIRE(std::holds_alternative<ast::NullStatement>(case_stmt.when_clauses[0].body[0]));
    REQUIRE(std::holds_alternative<ast::NullStatement>(case_stmt.when_clauses[1].body[0]));
}

TEST_CASE("NullStatement: Null in if branch", "[statements_sequential][null_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (enable : in std_logic);
        end E;
        architecture A of E is
        begin
            process(enable)
            begin
                if enable = '1' then
                    null;
                else
                    null;
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
    REQUIRE(std::holds_alternative<ast::NullStatement>(if_stmt.if_branch.body[0]));
    REQUIRE(std::holds_alternative<ast::NullStatement>(if_stmt.else_branch->body[0]));
}
