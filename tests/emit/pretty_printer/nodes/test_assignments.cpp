#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace {

auto token(std::string_view text) -> ast::TokenExpr
{
    ast::TokenExpr t;
    t.text = text;
    return t;
}

auto binary(std::string_view lhs, std::string_view op, std::string_view rhs) -> ast::BinaryExpr
{
    ast::BinaryExpr bin;
    bin.left = std::make_unique<ast::Expr>(token(lhs));
    bin.op = op;
    bin.right = std::make_unique<ast::Expr>(token(rhs));
    return bin;
}

// Helper to wrap a simple value into a Waveform
auto makeWave(ast::TokenExpr val) -> ast::Waveform
{
    ast::Waveform w;
    ast::Waveform::Element el;
    el.value = std::move(val);
    w.elements.emplace_back(std::move(el));
    return w;
}

} // namespace

TEST_CASE("Sequential Assignments", "[pretty_printer][assignments]")
{
    SECTION("Variable Assignment (:=)")
    {
        ast::VariableAssign assign;
        assign.target = token("cnt");
        assign.value = token("0");

        // Short enough to fit on one line
        REQUIRE(emit::test::render(assign) == "cnt := 0;");
    }

    SECTION("Signal Assignment (<=)")
    {
        ast::SignalAssign assign;
        assign.target = token("cnt");
        // Update: use waveform helper
        assign.waveform = makeWave(token("0"));

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
        ast::ConditionalConcurrentAssign::ConditionalWaveform w1;
        w1.waveform = makeWave(token("'1'"));
        w1.condition = binary("en", "=", "'1'");
        assign.waveforms.emplace_back(std::move(w1));

        // Waveform 2: '0' (else)
        ast::ConditionalConcurrentAssign::ConditionalWaveform w2;
        w2.waveform = makeWave(token("'0'"));
        w2.condition = std::nullopt;
        assign.waveforms.emplace_back(std::move(w2));

        SECTION("Fits on line (Flat)")
        {
            // Default config width is 80, this string is ~45 chars.
            constexpr std::string_view EXPECTED = "data_out <= '1' when en = '1' else '0';";
            REQUIRE(emit::test::render(assign) == EXPECTED);
        }

        SECTION("Forces Break (Hanging)")
        {
            // Constrain width to force the hanging behavior
            auto config = emit::test::defaultConfig();
            config.line_config.line_length = 20;

            // "data_out <= " is 12 chars.
            // The hang establishes indentation at column 12 for subsequent lines.
            constexpr std::string_view EXPECTED = "data_out <= '1' when en = '1' else\n"
                                                  "            '0';";

            REQUIRE(emit::test::render(assign, config) == EXPECTED);
        }
    }

    SECTION("Selected Assignment (With/Select)")
    {
        // with sel select data_out <= ...
        ast::SelectedConcurrentAssign assign;
        assign.selector = token("sel");
        assign.target = token("data_out");

        // Selection 1: '0' when "00"
        ast::SelectedConcurrentAssign::Selection sel1;
        sel1.waveform = makeWave(token("'0'"));
        sel1.choices.emplace_back(token("\"00\""));
        assign.selections.emplace_back(std::move(sel1));

        // Selection 2: '1' when others
        ast::SelectedConcurrentAssign::Selection sel2;
        sel2.waveform = makeWave(token("'1'"));
        sel2.choices.emplace_back(token("others"));
        assign.selections.emplace_back(std::move(sel2));

        SECTION("Fits on line (Flat)")
        {
            constexpr std::string_view EXPECTED
              = "with sel select data_out <= '0' when \"00\", '1' when others;";
            REQUIRE(emit::test::render(assign) == EXPECTED);
        }

        SECTION("Forces Break (Hanging)")
        {
            auto config = emit::test::defaultConfig();
            config.line_config.line_length = 30;

            // The header "with sel select" and target likely force a break.
            // "data_out <= " sets the hang anchor.
            constexpr std::string_view EXPECTED = "with sel select\n"
                                                  "data_out <= '0' when \"00\",\n"
                                                  "            '1' when others;";

            REQUIRE(emit::test::render(assign, config) == EXPECTED);
        }
    }

    SECTION("Conditional Assignment with Label")
    {
        // mux_select: data_out <= data_in when sel = '1' else '0';
        ast::ConditionalConcurrentAssign assign;
        assign.label = "mux_select";
        assign.target = token("data_out");

        // Waveform 1: data_in when sel = '1'
        ast::ConditionalConcurrentAssign::ConditionalWaveform w1;
        w1.waveform = makeWave(token("data_in"));
        w1.condition = binary("sel", "=", "'1'");
        assign.waveforms.emplace_back(std::move(w1));

        // Waveform 2: '0' (else)
        ast::ConditionalConcurrentAssign::ConditionalWaveform w2;
        w2.waveform = makeWave(token("'0'"));
        w2.condition = std::nullopt;
        assign.waveforms.emplace_back(std::move(w2));

        constexpr std::string_view EXPECTED
          = "mux_select: data_out <= data_in when sel = '1' else '0';";
        REQUIRE(emit::test::render(assign) == EXPECTED);
    }

    SECTION("Selected Assignment with Label")
    {
        // decoder: with counter select data_out <= ...
        ast::SelectedConcurrentAssign assign;
        assign.label = "decoder";
        assign.selector = token("counter");
        assign.target = token("data_out");

        // Selection 1: x"00" when 0
        ast::SelectedConcurrentAssign::Selection sel1;
        sel1.waveform = makeWave(token("x\"00\""));
        sel1.choices.emplace_back(token("0"));
        assign.selections.emplace_back(std::move(sel1));

        // Selection 2: x"FF" when others
        ast::SelectedConcurrentAssign::Selection sel2;
        sel2.waveform = makeWave(token("x\"FF\""));
        sel2.choices.emplace_back(token("others"));
        assign.selections.emplace_back(std::move(sel2));

        constexpr std::string_view EXPECTED
          = R"(decoder: with counter select data_out <= x"00" when 0, x"FF" when others;)";
        REQUIRE(emit::test::render(assign) == EXPECTED);
    }
}
