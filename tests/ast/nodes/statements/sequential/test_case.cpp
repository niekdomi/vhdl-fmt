#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("CaseStatement", "[statements][case]")
{
    auto parse_case = test_helpers::parseSequentialStmt<ast::CaseStatement>;

    SECTION("Simple case with when clauses")
    {
        constexpr std::string_view CODE = R"(
            case state is
                when IDLE => next_state := RUNNING;
                when RUNNING => next_state := DONE;
                when others => next_state := IDLE;
            end case;
        )";

        const auto *case_stmt = parse_case(CODE);
        REQUIRE(case_stmt != nullptr);

        // Verify Selector
        CHECK(std::get<ast::TokenExpr>(case_stmt->selector).text == "state");
        REQUIRE(case_stmt->when_clauses.size() == 3);

        // 1. Verify IDLE Clause
        const auto &idle = case_stmt->when_clauses[0];
        REQUIRE(idle.choices.size() == 1);
        CHECK(std::get<ast::TokenExpr>(idle.choices[0]).text == "IDLE");

        REQUIRE(idle.body.size() == 1);
        // Access Wrapper -> Kind
        CHECK(std::holds_alternative<ast::VariableAssign>(idle.body[0].kind));
        const auto &assign = std::get<ast::VariableAssign>(idle.body[0].kind);
        CHECK(std::get<ast::TokenExpr>(assign.value).text == "RUNNING");

        // 2. Verify others Clause
        const auto &others = case_stmt->when_clauses[2];
        REQUIRE(others.choices.size() == 1);
        CHECK(std::get<ast::TokenExpr>(others.choices[0]).text == "others");
    }

    SECTION("Case with different literal choices")
    {
        constexpr std::string_view CODE = R"(
            case val is
                when 0 => null;      -- Integer
                when "00" => null;   -- Bit String
                when '1' => null;    -- Character
                when others => null;
            end case;
        )";

        const auto *case_stmt = parse_case(CODE);
        REQUIRE(case_stmt != nullptr);
        REQUIRE(case_stmt->when_clauses.size() == 4);

        CHECK(std::get<ast::TokenExpr>(case_stmt->when_clauses[0].choices[0]).text == "0");
        CHECK(std::get<ast::TokenExpr>(case_stmt->when_clauses[1].choices[0]).text == "\"00\"");
        CHECK(std::get<ast::TokenExpr>(case_stmt->when_clauses[2].choices[0]).text == "'1'");
    }

    SECTION("Nested case statements")
    {
        constexpr std::string_view CODE = R"(
            case outer_sel is
                when A =>
                    case inner_sel is
                        when 0 => res := '0';
                    end case;
            end case;
        )";

        const auto *outer = parse_case(CODE);
        REQUIRE(outer != nullptr);

        const auto &outer_body = outer->when_clauses[0].body;
        REQUIRE(outer_body.size() == 1);

        // Verify inner is a CaseStatement
        CHECK(std::holds_alternative<ast::CaseStatement>(outer_body[0].kind));

        const auto &inner = std::get<ast::CaseStatement>(outer_body[0].kind);
        CHECK(std::get<ast::TokenExpr>(inner.selector).text == "inner_sel");
    }
}