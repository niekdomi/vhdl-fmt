#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <string>
#include <string_view>
#include <vector>

namespace {

// Helper to create a TokenExpr
auto token(std::string_view text) -> ast::TokenExpr
{
    ast::TokenExpr t;
    t.text = text;
    return t;
}

// Helper to create a BinaryExpr
auto binary(std::string_view lhs, std::string_view op, std::string_view rhs) -> ast::BinaryExpr
{
    ast::BinaryExpr bin;
    bin.left = std::make_unique<ast::Expr>(token(lhs));
    bin.op = op;
    bin.right = std::make_unique<ast::Expr>(token(rhs));
    return bin;
}

} // namespace

TEST_CASE("Sequential Assignments", "[pretty_printer][assignments]")
{
    SECTION("Variable Assignment (:=)")
    {
        ast::VariableAssign assign;
        assign.target = token("cnt");
        assign.value = token("0");

        REQUIRE(emit::test::render(assign) == "cnt := 0;");
    }

    SECTION("Signal Assignment (<=)")
    {
        ast::SignalAssign assign;
        assign.target = token("cnt");
        assign.value = token("0");

        REQUIRE(emit::test::render(assign) == "cnt <= 0;");
    }
}

TEST_CASE("Concurrent Assignments", "[pretty_printer][assignments]")
{
    SECTION("Conditional Assignment (When/Else)")
    {
        // data_out <= '1' when en = '1' else '0';
        ast::ConditionalConcurrentAssign assign;
        assign.target = token("data_out");

        // Waveform 1: '1' when en = '1'
        assign.waveforms.emplace_back(ast::ConditionalConcurrentAssign::Waveform{
          .value = token("'1'"),
          .condition = binary("en", "=", "'1'") // Implicit move into optional<Expr>
        });

        // Waveform 2: '0' (else)
        assign.waveforms.emplace_back(ast::ConditionalConcurrentAssign::Waveform{
          .value = token("'0'"), .condition = std::nullopt });

        const auto result = emit::test::render(assign);
        constexpr std::string_view EXPECTED = "data_out <= '1' when en = '1' else\n"
                                              "            '0';";

        REQUIRE(result == EXPECTED);
    }

    SECTION("Selected Assignment (With/Select)")
    {
        // with sel select data_out <= ...
        ast::SelectedConcurrentAssign assign;
        assign.selector = token("sel");
        assign.target = token("data_out");

        // Selection 1: '0' when "00"
        ast::SelectedConcurrentAssign::Selection sel1;
        sel1.value = token("'0'");
        sel1.choices.emplace_back(token("\"00\""));
        assign.selections.emplace_back(std::move(sel1));

        // Selection 2: '1' when others
        ast::SelectedConcurrentAssign::Selection sel2;
        sel2.value = token("'1'");
        sel2.choices.emplace_back(token("others"));
        assign.selections.emplace_back(std::move(sel2));

        const auto result = emit::test::render(assign);
        constexpr std::string_view EXPECTED = "with sel select\n"
                                              "  data_out <= '0' when \"00\",\n"
                                              "              '1' when others;";

        REQUIRE(result == EXPECTED);
    }
}
