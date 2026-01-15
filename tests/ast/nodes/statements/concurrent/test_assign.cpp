#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Concurrent Assignment: Conditional", "[statements][concurrent_assign]")
{
    // [0] Simple Assignment (a <= '1')
    SECTION("Simple Assignment (Unconditional)")
    {
        const std::string_view code = "a <= '1';";
        const auto* assign =
          test_helpers::parseConcurrentStmt<ast::ConditionalConcurrentAssign>(code);
        REQUIRE(assign != nullptr);

        CHECK(std::get_if<ast::TokenExpr>(&assign->target)->text == "a");

        REQUIRE(assign->waveforms.size() == 1);
        CHECK_FALSE(assign->waveforms.at(0).condition.has_value());

        const auto& wave = assign->waveforms.at(0).waveform;
        CHECK(wave.elements.size() == 1);
        CHECK(std::get_if<ast::TokenExpr>(&wave.elements.at(0).value)->text == "'1'");
    }

    // [1] Conditional Assignment (b <= '1' when sel = '1' else '0')
    SECTION("When-Else Logic")
    {
        const std::string_view code = "b <= '1' when sel = '1' else '0';";
        const auto* assign =
          test_helpers::parseConcurrentStmt<ast::ConditionalConcurrentAssign>(code);
        REQUIRE(assign != nullptr);

        CHECK(std::get_if<ast::TokenExpr>(&assign->target)->text == "b");
        REQUIRE(assign->waveforms.size() == 2);

        // Waveform 1: '1' when sel = '1'
        const auto& w1 = assign->waveforms.at(0);
        REQUIRE(w1.condition.has_value());
        CHECK(std::get_if<ast::BinaryExpr>(&w1.condition.value())->op == "=");
        CHECK(std::get_if<ast::TokenExpr>(&w1.waveform.elements.at(0).value)->text == "'1'");

        // Waveform 2: '0' (else)
        const auto& w2 = assign->waveforms.at(1);
        CHECK_FALSE(w2.condition.has_value());
        CHECK(std::get_if<ast::TokenExpr>(&w2.waveform.elements.at(0).value)->text == "'0'");
    }

    // Label Check (Verified on the Wrapper)
    SECTION("Labeled Conditional Assignment")
    {
        const std::string_view code = "mux_select: data_out <= data_in when sel = '1' else '0';";

        const auto* arch = test_helpers::parseArchitectureWithStmt(code);
        REQUIRE(arch != nullptr);
        REQUIRE(arch->stmts.size() == 1);

        const auto& wrapper = arch->stmts.at(0);

        // 1. Verify Label on Wrapper
        REQUIRE(wrapper.label.has_value());
        CHECK(wrapper.label.value() == "mux_select");

        // 2. Verify Kind
        CHECK(std::holds_alternative<ast::ConditionalConcurrentAssign>(wrapper.kind));

        const auto& assign = std::get<ast::ConditionalConcurrentAssign>(wrapper.kind);
        CHECK(std::get_if<ast::TokenExpr>(&assign.target)->text == "data_out");
    }
}

TEST_CASE("Concurrent Assignment: Selected", "[statements][selected_assign]")
{
    // Simple Selected Assignment: result <= "00" when '0', "11" when others
    SECTION("Basic Selection (Bits)")
    {
        const std::string_view code = "with sel select result <= '1' when '0', '0' when others;";
        const auto* assign = test_helpers::parseConcurrentStmt<ast::SelectedConcurrentAssign>(code);
        REQUIRE(assign != nullptr);

        CHECK(std::get_if<ast::TokenExpr>(&assign->selector)->text == "sel");
        CHECK(std::get_if<ast::TokenExpr>(&assign->target)->text == "result");
        REQUIRE(assign->selections.size() == 2);

        // Selection 1: '1' when '0'
        const auto& s1 = assign->selections.at(0);
        CHECK(std::get_if<ast::TokenExpr>(&s1.waveform.elements.at(0).value)->text == "'1'");
        CHECK(std::get_if<ast::TokenExpr>(s1.choices.data())->text == "'0'");

        // Selection 2: '0' when others
        const auto& s2 = assign->selections.at(1);
        CHECK(std::get_if<ast::TokenExpr>(&s2.waveform.elements.at(0).value)->text == "'0'");
        CHECK(std::get_if<ast::TokenExpr>(s2.choices.data())->text == "others");
    }

    // Selected Assignment with Ranges and Multiple Choices
    SECTION("Selections with Ranges and Multiple Choices")
    {
        const std::string_view code =
          "with selector select output <=" " \"0000\" when 0 to 3," " \"1111\" when 4 | 5," " \"ZZZZ\" when others;";

        const auto* assign = test_helpers::parseConcurrentStmt<ast::SelectedConcurrentAssign>(code);
        REQUIRE(assign != nullptr);
        REQUIRE(assign->selections.size() == 3);

        // Selection 1: "0000" when 0 to 3
        const auto& s1 = assign->selections.at(0);
        REQUIRE(s1.choices.size() == 1);
        CHECK(std::get_if<ast::BinaryExpr>(s1.choices.data())->op == "to");

        // Selection 2: "1111" when 4 | 5
        const auto& s2 = assign->selections.at(1);
        REQUIRE(s2.choices.size() == 2);
        CHECK(std::get_if<ast::TokenExpr>(s2.choices.data())->text == "4");
        CHECK(std::get_if<ast::TokenExpr>(&s2.choices.at(1))->text == "5");
    }

    // Label Check (Verified on the Wrapper)
    SECTION("Labeled Selected Assignment")
    {
        const std::string_view code =
          "decoder: with counter select data_out <= '0' when '0', '1' when others;";

        const auto* arch = test_helpers::parseArchitectureWithStmt(code);
        REQUIRE(arch != nullptr);
        REQUIRE(arch->stmts.size() == 1);

        const auto& wrapper = arch->stmts.at(0);

        // 1. Verify Label on Wrapper
        REQUIRE(wrapper.label.has_value());
        CHECK(wrapper.label.value() == "decoder");

        // 2. Verify Kind
        CHECK(std::holds_alternative<ast::SelectedConcurrentAssign>(wrapper.kind));
    }
}
