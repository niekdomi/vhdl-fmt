#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("ConditionalAssign: Simple conditional assignment",
          "[statements_concurrent][conditional_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a, b : in std_logic; sel : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            y <= a when sel = '1' else b;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    REQUIRE(assign.conditional_waveforms.size() == 2);
    const auto &first_value = std::get<ast::TokenExpr>(assign.conditional_waveforms[0].value);
    REQUIRE(first_value.text == "a");
    REQUIRE(assign.conditional_waveforms[0].condition.has_value());
    const auto &condition
      = std::get<ast::BinaryExpr>(assign.conditional_waveforms[0].condition.value());
    REQUIRE(condition.op == "=");
    const auto &else_value = std::get<ast::TokenExpr>(assign.conditional_waveforms[1].value);
    REQUIRE(else_value.text == "b");
    REQUIRE_FALSE(assign.conditional_waveforms[1].condition.has_value());
}

TEST_CASE("ConditionalAssign: Multiple conditions with elsif",
          "[statements_concurrent][conditional_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (sel : in integer; y : out std_logic);
        end E;
        architecture A of E is
        begin
            y <= '0' when sel = 0 else
                 '1' when sel = 1 else
                 'X';
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    REQUIRE(assign.conditional_waveforms.size() == 3);
    REQUIRE(assign.conditional_waveforms[0].condition.has_value());
    const auto &first_cond
      = std::get<ast::BinaryExpr>(assign.conditional_waveforms[0].condition.value());
    REQUIRE(first_cond.op == "=");
    REQUIRE(assign.conditional_waveforms[1].condition.has_value());
    const auto &second_cond
      = std::get<ast::BinaryExpr>(assign.conditional_waveforms[1].condition.value());
    REQUIRE(second_cond.op == "=");
    REQUIRE_FALSE(assign.conditional_waveforms[2].condition.has_value());
}

TEST_CASE("ConditionalAssign: Conditional with complex expressions",
          "[statements_concurrent][conditional_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a, b, c : in std_logic; enable : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            y <= (a and b) when enable = '1' else
                 (b or c);
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    REQUIRE(assign.conditional_waveforms.size() == 2);
    const auto &value = std::get<ast::ParenExpr>(assign.conditional_waveforms[0].value);
    REQUIRE(value.inner != nullptr);
    REQUIRE(assign.conditional_waveforms[0].condition.has_value());
    const auto &condition
      = std::get<ast::BinaryExpr>(assign.conditional_waveforms[0].condition.value());
    REQUIRE(condition.op == "=");
}
