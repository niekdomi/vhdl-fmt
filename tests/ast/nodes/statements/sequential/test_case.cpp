#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("CaseStatement", "[statements][case]")
{
    auto parse_case = test_helpers::parseSequentialStmt<ast::CaseStatement>;

    SECTION("Simple case with when clauses")
    {
        const auto *case_stmt = parse_case("case state is\n"
                                           "    when IDLE => next_state := RUNNING;\n"
                                           "    when RUNNING => next_state := DONE;\n"
                                           "    when others => next_state := IDLE;\n"
                                           "end case;");
        REQUIRE(case_stmt != nullptr);

        // Verify Selector
        CHECK(std::get<ast::TokenExpr>(case_stmt->selector).text == "state");
        REQUIRE(case_stmt->when_clauses.size() == 3);

        // Verify IDLE Clause
        const auto &idle = case_stmt->when_clauses[0];
        REQUIRE(idle.choices.size() == 1);
        CHECK(std::get<ast::TokenExpr>(idle.choices[0]).text == "IDLE");
        REQUIRE(idle.body.size() == 1);
        const auto *assign1 = std::get_if<ast::VariableAssign>(idle.body.data());
        CHECK(std::get<ast::TokenExpr>(assign1->value).text == "RUNNING");

        // Verify others Clause
        const auto &others = case_stmt->when_clauses[2];
        REQUIRE(others.choices.size() == 1);
        CHECK(std::get<ast::TokenExpr>(others.choices[0]).text == "others");
    }

    SECTION("Case with integer values")
    {
        const auto *case_stmt = parse_case("case selector is\n"
                                           "    when 0 => result := \"000\";\n"
                                           "    when 1 => result := \"001\";\n"
                                           "    when 2 => result := \"010\";\n"
                                           "    when 3 => result := \"011\";\n"
                                           "    when others => result := \"111\";\n"
                                           "end case;");
        REQUIRE(case_stmt != nullptr);
        REQUIRE(case_stmt->when_clauses.size() == 5);
    }

    SECTION("Case with bit patterns")
    {
        const auto *case_stmt = parse_case("case opcode is\n"
                                           "    when \"00\" => operation := ADD;\n"
                                           "    when \"01\" => operation := SUB;\n"
                                           "    when \"10\" => operation := MUL;\n"
                                           "    when \"11\" => operation := DIV;\n"
                                           "end case;");
        REQUIRE(case_stmt != nullptr);
        CHECK(std::get<ast::TokenExpr>(case_stmt->selector).text == "opcode");
        REQUIRE(case_stmt->when_clauses.size() == 4);

        // Check first pattern
        CHECK(std::get<ast::TokenExpr>(case_stmt->when_clauses[0].choices[0]).text == "\"00\"");
        const auto *body0
          = std::get_if<ast::VariableAssign>(case_stmt->when_clauses[0].body.data());
        CHECK(std::get<ast::TokenExpr>(body0->value).text == "ADD");
    }

    SECTION("Case with multiple statements per branch")
    {
        const auto *case_stmt = parse_case("case mode is\n"
                                           "    when INIT =>\n"
                                           "        counter := 0;\n"
                                           "        valid := '0';\n"
                                           "        ready := '0';\n"
                                           "    when RUN =>\n"
                                           "        counter := counter + 1;\n"
                                           "        valid := '1';\n"
                                           "    when STOP =>\n"
                                           "        valid := '0';\n"
                                           "end case;");
        REQUIRE(case_stmt != nullptr);
        REQUIRE(case_stmt->when_clauses.size() == 3);
    }

    SECTION("Nested case statements")
    {
        const auto *case_stmt = parse_case("case outer_sel is\n"
                                           "    when A =>\n"
                                           "        case inner_sel is\n"
                                           "            when 0 => result := X;\n"
                                           "            when 1 => result := Y;\n"
                                           "        end case;\n"
                                           "    when B =>\n"
                                           "        result := Z;\n"
                                           "end case;");
        REQUIRE(case_stmt != nullptr);
        REQUIRE(case_stmt->when_clauses.size() == 2);
    }

    SECTION("Case with null statement")
    {
        const auto *case_stmt = parse_case("case sel is\n"
                                           "    when 0 => data := input;\n"
                                           "    when 1 => null;\n"
                                           "    when others => data := default_val;\n"
                                           "end case;");
        REQUIRE(case_stmt != nullptr);
        REQUIRE(case_stmt->when_clauses.size() == 3);
    }
}
