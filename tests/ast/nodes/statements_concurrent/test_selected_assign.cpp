#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("SelectedAssign: Simple with statement", "[statements_concurrent][selected_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (sel : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            with sel select
                y <= '0' when '0',
                     '1' when '1',
                     'X' when others;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    REQUIRE(assign.select.has_value());
    const auto &selector = std::get<ast::TokenExpr>(assign.select.value());
    REQUIRE(selector.text == "sel");
    REQUIRE(assign.selected_waveforms.size() == 3);
    const auto &first_value = std::get<ast::TokenExpr>(assign.selected_waveforms[0].value);
    REQUIRE(first_value.text == "'0'");
    REQUIRE(assign.selected_waveforms[0].choices.size() == 1);
    REQUIRE(std::get<ast::TokenExpr>(assign.selected_waveforms[0].choices[0]).text == "'0'");
    REQUIRE(std::get<ast::TokenExpr>(assign.selected_waveforms[1].value).text == "'1'");
    REQUIRE(std::get<ast::TokenExpr>(assign.selected_waveforms[2].choices[0]).text == "others");
}

TEST_CASE("SelectedAssign: With statement using integer selector",
          "[statements_concurrent][selected_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (sel : in integer; y : out std_logic_vector(1 downto 0));
        end E;
        architecture A of E is
        begin
            with sel select
                y <= "00" when 0,
                     "01" when 1,
                     "10" when 2,
                     "11" when 3,
                     "XX" when others;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    REQUIRE(assign.select.has_value());
    const auto &selector = std::get<ast::TokenExpr>(assign.select.value());
    REQUIRE(selector.text == "sel");
    REQUIRE(assign.selected_waveforms.size() == 5);
    const auto &second_value = std::get<ast::TokenExpr>(assign.selected_waveforms[1].value);
    REQUIRE(second_value.text == "\"01\"");
    REQUIRE(std::get<ast::TokenExpr>(assign.selected_waveforms.back().choices[0]).text == "others");
}

TEST_CASE("SelectedAssign: With statement using range", "[statements_concurrent][selected_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (sel : in integer; y : out std_logic);
        end E;
        architecture A of E is
        begin
            with sel select
                y <= '0' when 0 to 5,
                     '1' when 6 to 10,
                     'X' when others;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    REQUIRE(assign.select.has_value());
    REQUIRE(assign.selected_waveforms.size() == 3);
    const auto &range_choice = assign.selected_waveforms[0].choices[0];
    const auto &range = std::get<ast::BinaryExpr>(range_choice);
    REQUIRE(range.op == "to");
}
