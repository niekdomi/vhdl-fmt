#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "ast/nodes/statements/waveform.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string>
#include <string_view>
#include <utility>

namespace {

auto token(std::string_view text) -> ast::TokenExpr
{
    ast::TokenExpr t;
    t.text = text;
    return t;
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
