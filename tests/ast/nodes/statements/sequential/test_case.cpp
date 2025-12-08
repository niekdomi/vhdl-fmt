#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("CaseStatement: Simple case with when clauses", "[statements][case]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                case state is
                    when IDLE =>
                        next_state := RUNNING;
                    when RUNNING =>
                        next_state := DONE;
                    when others =>
                        next_state := IDLE;
                end case;
            end process;
        end RTL;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);
    REQUIRE_FALSE(proc->body.empty());

    const auto *case_stmt = std::get_if<ast::CaseStatement>(proc->body.data());
    REQUIRE(case_stmt != nullptr);
    REQUIRE(case_stmt->when_clauses.size() == 3);
}

TEST_CASE("CaseStatement: Case with integer values", "[statements][case]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                case selector is
                    when 0 =>
                        result := "000";
                    when 1 =>
                        result := "001";
                    when 2 =>
                        result := "010";
                    when 3 =>
                        result := "011";
                    when others =>
                        result := "111";
                end case;
            end process;
        end RTL;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);
    REQUIRE_FALSE(proc->body.empty());

    const auto *case_stmt = std::get_if<ast::CaseStatement>(proc->body.data());
    REQUIRE(case_stmt != nullptr);
    REQUIRE(case_stmt->when_clauses.size() == 5);
}

TEST_CASE("CaseStatement: Case with bit patterns", "[statements][case]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                case opcode is
                    when "00" =>
                        operation := ADD;
                    when "01" =>
                        operation := SUB;
                    when "10" =>
                        operation := MUL;
                    when "11" =>
                        operation := DIV;
                end case;
            end process;
        end RTL;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);
    REQUIRE_FALSE(proc->body.empty());

    const auto *case_stmt = std::get_if<ast::CaseStatement>(proc->body.data());
    REQUIRE(case_stmt != nullptr);
    REQUIRE(case_stmt->when_clauses.size() == 4);
}

TEST_CASE("CaseStatement: Case with multiple statements per branch", "[statements][case]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                case mode is
                    when INIT =>
                        counter := 0;
                        valid := '0';
                        ready := '0';
                    when RUN =>
                        counter := counter + 1;
                        valid := '1';
                    when STOP =>
                        valid := '0';
                end case;
            end process;
        end RTL;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);
    REQUIRE_FALSE(proc->body.empty());

    const auto *case_stmt = std::get_if<ast::CaseStatement>(proc->body.data());
    REQUIRE(case_stmt != nullptr);
    REQUIRE(case_stmt->when_clauses.size() == 3);
}

TEST_CASE("CaseStatement: Nested case statements", "[statements][case]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                case outer_sel is
                    when A =>
                        case inner_sel is
                            when 0 =>
                                result := X;
                            when 1 =>
                                result := Y;
                        end case;
                    when B =>
                        result := Z;
                end case;
            end process;
        end RTL;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);
    REQUIRE_FALSE(proc->body.empty());

    const auto *case_stmt = std::get_if<ast::CaseStatement>(proc->body.data());
    REQUIRE(case_stmt != nullptr);
    REQUIRE(case_stmt->when_clauses.size() == 2);
}

TEST_CASE("CaseStatement: Case with null statement", "[statements][case]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                case sel is
                    when 0 =>
                        data := input;
                    when 1 =>
                        null;
                    when others =>
                        data := default_val;
                end case;
            end process;
        end RTL;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);
    REQUIRE_FALSE(proc->body.empty());

    const auto *case_stmt = std::get_if<ast::CaseStatement>(proc->body.data());
    REQUIRE(case_stmt != nullptr);
    REQUIRE(case_stmt->when_clauses.size() == 3);
}
