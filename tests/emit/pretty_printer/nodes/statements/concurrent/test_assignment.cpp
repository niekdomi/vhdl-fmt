#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/waveform.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <utility>

namespace {

auto token(std::string_view text) -> ast::TokenExpr
{
    ast::TokenExpr t{};
    t.text = text;
    return t;
}

auto binary(std::string_view lhs, std::string_view op, std::string_view rhs) -> ast::BinaryExpr
{
    ast::BinaryExpr bin{};
    bin.left = std::make_unique<ast::Expr>(token(lhs));
    bin.op = op;
    bin.right = std::make_unique<ast::Expr>(token(rhs));
    return bin;
}

// Helper to wrap a simple value into a Waveform
auto makeWave(ast::TokenExpr val) -> ast::Waveform
{
    ast::Waveform w{};
    ast::Waveform::Element el{};
    el.value = std::move(val);
    w.elements.emplace_back(std::move(el));
    return w;
}

} // namespace

TEST_CASE("Concurrent Assignments", "[pretty_printer][assignments]")
{
    SECTION("Conditional Assignment (When/Else)")
    {
        ast::ConditionalConcurrentAssign assign{};
        assign.target = token("data_out");

        // Waveform 1: '1' when en = '1'
        assign.waveforms.push_back({
          .waveform = makeWave(token("'1'")),
          .condition = binary("en", "=", "'1'"),
        });

        // Waveform 2: '0' (else)
        assign.waveforms.push_back({
          .waveform = makeWave(token("'0'")),
          .condition = std::nullopt,
        });

        SECTION("Fits on line (Flat)")
        {
            const std::string_view expected = "data_out <= '1' when en = '1' else '0';";
            REQUIRE(emit::test::render(assign) == expected);
        }

        SECTION("Forces Break (Hanging)")
        {
            auto config = emit::test::defaultConfig();
            config.line_config.line_length = 20;

            const std::string_view expected =
              "data_out <= '1' when en = '1' else\n" "            '0';";

            REQUIRE(emit::test::render(assign, config) == expected);
        }
    }

    SECTION("Selected Assignment (With/Select)")
    {
        ast::SelectedConcurrentAssign assign{};
        assign.selector = token("sel");
        assign.target = token("data_out");

        // Selection 1: '0' when "00"
        auto& sel1 = assign.selections.emplace_back();
        sel1.waveform = makeWave(token("'0'"));
        sel1.choices.emplace_back(token("\"00\""));

        // Selection 2: '1' when others
        auto& sel2 = assign.selections.emplace_back();
        sel2.waveform = makeWave(token("'1'"));
        sel2.choices.emplace_back(token("others"));

        SECTION("Fits on line (Flat)")
        {
            const std::string_view expected =
              "with sel select data_out <= '0' when \"00\", '1' when others;";
            REQUIRE(emit::test::render(assign) == expected);
        }

        SECTION("Forces Break (Hanging)")
        {
            auto config = emit::test::defaultConfig();
            config.line_config.line_length = 30;

            const std::string_view expected =
              "with sel select\n" "data_out <= '0' when \"00\",\n" "            '1' when others;";

            REQUIRE(emit::test::render(assign, config) == expected);
        }
    }

    SECTION("Conditional Assignment with Label")
    {
        // 1. Inner Logic
        ast::ConditionalConcurrentAssign assign{};
        assign.target = token("data_out");

        assign.waveforms.push_back({
          .waveform = makeWave(token("data_in")),
          .condition = binary("sel", "=", "'1'"),
        });

        assign.waveforms.push_back({
          .waveform = makeWave(token("'0'")),
          .condition = std::nullopt,
        });

        // 2. Wrapper
        ast::ConcurrentStatement wrapper{};
        wrapper.label = "mux_select";
        wrapper.kind = std::move(assign);

        const std::string_view expected =
          "mux_select: data_out <= data_in when sel = '1' else '0';";
        REQUIRE(emit::test::render(wrapper) == expected);
    }

    SECTION("Selected Assignment with Label")
    {
        // 1. Inner Logic
        ast::SelectedConcurrentAssign assign{};
        assign.selector = token("counter");
        assign.target = token("data_out");

        auto& s1 = assign.selections.emplace_back();
        s1.waveform = makeWave(token("x\"00\""));
        s1.choices.emplace_back(token("0"));

        auto& s2 = assign.selections.emplace_back();
        s2.waveform = makeWave(token("x\"FF\""));
        s2.choices.emplace_back(token("others"));

        // 2. Wrapper
        ast::ConcurrentStatement wrapper{};
        wrapper.label = "decoder";
        wrapper.kind = std::move(assign);

        const std::string_view expected =
          R"(decoder: with counter select data_out <= x"00" when 0, x"FF" when others;)";
        REQUIRE(emit::test::render(wrapper) == expected);
    }
}
