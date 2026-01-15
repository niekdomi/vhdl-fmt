#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/stmt_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

namespace {

/// @brief Parses a concurrent conditional signal assignment (<= when/else).
auto parseConditionalAssign(std::string_view stmt) -> const ast::ConditionalConcurrentAssign*
{
    return stmt_utils::parseConcurrent<ast::ConditionalConcurrentAssign>(stmt);
}

/// @brief Parses a concurrent selected signal assignment (with/select).
auto parseSelectedAssign(std::string_view stmt) -> const ast::SelectedConcurrentAssign*
{
    return stmt_utils::parseConcurrent<ast::SelectedConcurrentAssign>(stmt);
}

// Helper to safely cast a generic expression variant to a concrete node type
template<typename T>
[[nodiscard]]
auto getExpr(const ast::Expr& expr) -> const T*
{
    return std::get_if<T>(&expr);
}

} // namespace

// === Conditional Assignments (when/else) ===

TEST_CASE("Concurrent Assignment: Conditional", "[statements][concurrent_assign]")
{
    // [0] Simple Assignment (a <= '1')
    SECTION("Simple Assignment (Unconditional)")
    {
        const auto* assign = parseConditionalAssign("a <= '1';");
        REQUIRE(assign != nullptr);

        CHECK(getExpr<ast::TokenExpr>(assign->target)->text == "a");

        REQUIRE(assign->waveforms.size() == 1);
        CHECK_FALSE(assign->waveforms[0].condition.has_value());
        CHECK(assign->waveforms[0].waveform.elements.size() == 1);
        CHECK(getExpr<ast::TokenExpr>(assign->waveforms[0].waveform.elements[0].value)->text
              == "'1'");
    }

    // [1] Conditional Assignment (b <= '1' when sel = '1' else '0')
    SECTION("When-Else Logic")
    {
        const auto* assign = parseConditionalAssign("b <= '1' when sel = '1' else '0';");
        REQUIRE(assign != nullptr);

        CHECK(getExpr<ast::TokenExpr>(assign->target)->text == "b");
        REQUIRE(assign->waveforms.size() == 2);

        // Waveform 1: '1' when sel = '1'
        const auto& w1 = assign->waveforms[0];
        REQUIRE(w1.condition.has_value());
        CHECK(getExpr<ast::BinaryExpr>(*w1.condition)->op == "=");
        CHECK(getExpr<ast::TokenExpr>(w1.waveform.elements[0].value)->text == "'1'");

        // Waveform 2: '0' (else)
        const auto& w2 = assign->waveforms[1];
        CHECK_FALSE(w2.condition.has_value());
        CHECK(getExpr<ast::TokenExpr>(w2.waveform.elements[0].value)->text == "'0'");
    }

    // Conditional assignment with label
    SECTION("Labeled Conditional Assignment")
    {
        const auto* assign =
          parseConditionalAssign("mux_select: data_out <= data_in when sel = '1' else '0';");
        REQUIRE(assign != nullptr);

        REQUIRE(assign->label.has_value());
        CHECK(assign->label.value() == "mux_select");
        CHECK(getExpr<ast::TokenExpr>(assign->target)->text == "data_out");
    }

    // Assignment without explicit label
    SECTION("Assignment without label")
    {
        const auto* assign = parseConditionalAssign("a <= b;");
        REQUIRE(assign != nullptr);
        CHECK_FALSE(assign->label.has_value());
    }
}

// === Selected Assignments (with/select) ===

TEST_CASE("Concurrent Assignment: Selected", "[statements][selected_assign]")
{
    // Simple Selected Assignment: result <= "00" when '0', "11" when others
    SECTION("Basic Selection (Bits)")
    {
        const auto* assign =
          parseSelectedAssign("with sel select result <= '1' when '0', '0' when others;");
        REQUIRE(assign != nullptr);

        CHECK(getExpr<ast::TokenExpr>(assign->selector)->text == "sel");
        CHECK(getExpr<ast::TokenExpr>(assign->target)->text == "result");
        REQUIRE(assign->selections.size() == 2);

        // Selection 1: '1' when '0'
        const auto& s1 = assign->selections[0];
        CHECK(getExpr<ast::TokenExpr>(s1.waveform.elements[0].value)->text == "'1'");
        CHECK(getExpr<ast::TokenExpr>(s1.choices[0])->text == "'0'");

        // Selection 2: '0' when others
        const auto& s2 = assign->selections[1];
        CHECK(getExpr<ast::TokenExpr>(s2.waveform.elements[0].value)->text == "'0'");
        CHECK(getExpr<ast::TokenExpr>(s2.choices[0])->text == "others");
    }

    // Selected Assignment with Ranges and Multiple Choices
    SECTION("Selections with Ranges and Multiple Choices")
    {
        const auto* assign = parseSelectedAssign(
          R"(with selector select output <= "0000" when 0 to 3, "1111" when 4 | 5, "ZZZZ" when others;)");
        REQUIRE(assign != nullptr);
        REQUIRE(assign->selections.size() == 3);

        // Selection 1: "0000" when 0 to 3
        const auto& s1 = assign->selections[0];
        REQUIRE(s1.choices.size() == 1);
        CHECK(getExpr<ast::BinaryExpr>(s1.choices[0])->op == "to");

        // Selection 2: "1111" when 4 | 5
        const auto& s2 = assign->selections[1];
        REQUIRE(s2.choices.size() == 2);
        CHECK(getExpr<ast::TokenExpr>(s2.choices[0])->text == "4");
        CHECK(getExpr<ast::TokenExpr>(s2.choices[1])->text == "5");
    }

    // Selected assignment with label
    SECTION("Labeled Selected Assignment")
    {
        const auto* assign = parseSelectedAssign(
          "decoder: with counter select data_out <= '0' when '0', '1' when others;");
        REQUIRE(assign != nullptr);

        REQUIRE(assign->label.has_value());
        CHECK(assign->label.value() == "decoder");
        CHECK(getExpr<ast::TokenExpr>(assign->selector)->text == "counter");
        CHECK(getExpr<ast::TokenExpr>(assign->target)->text == "data_out");
    }
}
