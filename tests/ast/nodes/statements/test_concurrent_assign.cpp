#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Concurrent Assignments", "[statements][concurrent_assign]")
{
    // A single VHDL string containing multiple concurrent assignment types
    constexpr std::string_view VHDL_FILE = "entity Test is end Test;\n"
                                           "architecture RTL of Test is\n"
                                           "    signal a, b, c, sel : bit;\n"
                                           "    signal result : bit;\n"
                                           "begin\n"
                                           "    -- [0] Simple Assignment (mapped to Conditional)\n"
                                           "    a <= '1';\n"
                                           "\n"
                                           "    -- [1] Conditional Assignment (when...else)\n"
                                           "    b <= '1' when sel = '1' else '0';\n"
                                           "\n"
                                           "    -- [2] Selected Assignment (with...select)\n"
                                           "    with sel select\n"
                                           "        result <= '1' when '0',\n"
                                           "                  '0' when others;\n"
                                           "end RTL;";

    const auto design = builder::buildFromString(VHDL_FILE);

    // Get Architecture
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->stmts.size() == 3);

    SECTION("Simple Assignment (as Conditional)")
    {
        // Statement [0]: a <= '1';
        // This is stored as a ConditionalConcurrentAssign with 1 unconditional waveform
        const auto *assign = std::get_if<ast::ConditionalConcurrentAssign>(arch->stmts.data());
        REQUIRE(assign != nullptr);

        // Check Target
        CHECK(std::get<ast::TokenExpr>(assign->target).text == "a");

        // Check Waveform
        REQUIRE(assign->waveforms.size() == 1);
        CHECK(std::get<ast::TokenExpr>(assign->waveforms[0].value).text == "'1'");
        CHECK_FALSE(assign->waveforms[0].condition.has_value());
    }

    SECTION("Conditional Assignment (when...else)")
    {
        // Statement [1]: b <= '1' when sel = '1' else '0';
        const auto *assign = std::get_if<ast::ConditionalConcurrentAssign>(&arch->stmts[1]);
        REQUIRE(assign != nullptr);

        CHECK(std::get<ast::TokenExpr>(assign->target).text == "b");

        REQUIRE(assign->waveforms.size() == 2);

        // Waveform 1: '1' when sel = '1'
        CHECK(std::get<ast::TokenExpr>(assign->waveforms[0].value).text == "'1'");
        REQUIRE(assign->waveforms[0].condition.has_value());
        // Verify condition structure (sel = '1')
        const auto *cond = std::get_if<ast::BinaryExpr>(&*assign->waveforms[0].condition);
        REQUIRE(cond != nullptr);
        CHECK(cond->op == "=");

        // Waveform 2: '0' (else)
        CHECK(std::get<ast::TokenExpr>(assign->waveforms[1].value).text == "'0'");
        CHECK_FALSE(assign->waveforms[1].condition.has_value());
    }

    SECTION("Selected Assignment (with...select)")
    {
        // Statement [2]: with sel select result <= ...
        const auto *assign = std::get_if<ast::SelectedConcurrentAssign>(&arch->stmts[2]);
        REQUIRE(assign != nullptr);

        // Check Selector (with sel ...)
        CHECK(std::get<ast::TokenExpr>(assign->selector).text == "sel");

        // Check Target (... select result <=)
        CHECK(std::get<ast::TokenExpr>(assign->target).text == "result");

        // Check Selections
        REQUIRE(assign->selections.size() == 2);

        // Selection 1: '1' when '0'
        CHECK(std::get<ast::TokenExpr>(assign->selections[0].value).text == "'1'");
        REQUIRE(assign->selections[0].choices.size() == 1);
        CHECK(std::get<ast::TokenExpr>(assign->selections[0].choices[0]).text == "'0'");

        // Selection 2: '0' when others
        CHECK(std::get<ast::TokenExpr>(assign->selections[1].value).text == "'0'");
        REQUIRE(assign->selections[1].choices.size() == 1);
        CHECK(std::get<ast::TokenExpr>(assign->selections[1].choices[0]).text == "others");
    }
}
