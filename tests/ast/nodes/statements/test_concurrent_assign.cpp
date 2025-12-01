#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Concurrent Assignments", "[statements][concurrent_assign]")
{
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

    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->stmts.size() == 3);

    SECTION("Simple Assignment (as Conditional)")
    {
        const auto *assign = std::get_if<ast::ConditionalConcurrentAssign>(arch->stmts.data());
        REQUIRE(assign != nullptr);

        CHECK(std::get<ast::TokenExpr>(assign->target).text == "a");

        REQUIRE(assign->waveforms.size() == 1);

        // New AST Access: waveform -> elements[0] -> value
        REQUIRE(assign->waveforms[0].waveform.elements.size() == 1);
        CHECK(std::get<ast::TokenExpr>(assign->waveforms[0].waveform.elements[0].value).text
              == "'1'");
        CHECK_FALSE(assign->waveforms[0].condition.has_value());
    }

    SECTION("Conditional Assignment (when...else)")
    {
        const auto *assign = std::get_if<ast::ConditionalConcurrentAssign>(&arch->stmts[1]);
        REQUIRE(assign != nullptr);

        CHECK(std::get<ast::TokenExpr>(assign->target).text == "b");

        REQUIRE(assign->waveforms.size() == 2);

        // Waveform 1: '1' when sel = '1'
        {
            const auto &item = assign->waveforms[0];
            REQUIRE(item.waveform.elements.size() == 1);
            CHECK(std::get<ast::TokenExpr>(item.waveform.elements[0].value).text == "'1'");
            REQUIRE(item.condition.has_value());

            const auto *cond = std::get_if<ast::BinaryExpr>(&*item.condition);
            REQUIRE(cond != nullptr);
            CHECK(cond->op == "=");
        }

        // Waveform 2: '0' (else)
        {
            const auto &item = assign->waveforms[1];
            REQUIRE(item.waveform.elements.size() == 1);
            CHECK(std::get<ast::TokenExpr>(item.waveform.elements[0].value).text == "'0'");
            CHECK_FALSE(item.condition.has_value());
        }
    }

    SECTION("Selected Assignment (with...select)")
    {
        const auto *assign = std::get_if<ast::SelectedConcurrentAssign>(&arch->stmts[2]);
        REQUIRE(assign != nullptr);

        CHECK(std::get<ast::TokenExpr>(assign->selector).text == "sel");
        CHECK(std::get<ast::TokenExpr>(assign->target).text == "result");

        REQUIRE(assign->selections.size() == 2);

        // Selection 1: '1' when '0'
        {
            const auto &sel = assign->selections[0];
            REQUIRE(sel.waveform.elements.size() == 1);
            CHECK(std::get<ast::TokenExpr>(sel.waveform.elements[0].value).text == "'1'");
            REQUIRE(sel.choices.size() == 1);
            CHECK(std::get<ast::TokenExpr>(sel.choices[0]).text == "'0'");
        }

        // Selection 2: '0' when others
        {
            const auto &sel = assign->selections[1];
            REQUIRE(sel.waveform.elements.size() == 1);
            CHECK(std::get<ast::TokenExpr>(sel.waveform.elements[0].value).text == "'0'");
            REQUIRE(sel.choices.size() == 1);
            CHECK(std::get<ast::TokenExpr>(sel.choices[0]).text == "others");
        }
    }
}
