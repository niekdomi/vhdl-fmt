#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("ConcurrentAssign: Simple signal assignment",
          "[statements_concurrent][concurrent_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a, b : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            y <= a;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    const auto &target = std::get<ast::TokenExpr>(assign.target);
    REQUIRE(target.text == "y");
    REQUIRE(assign.conditional_waveforms.size() == 1);
    REQUIRE_FALSE(assign.conditional_waveforms[0].condition.has_value());
    const auto &value = std::get<ast::TokenExpr>(assign.value);
    REQUIRE(value.text == "a");
}

TEST_CASE("ConcurrentAssign: Assignment with logical expression",
          "[statements_concurrent][concurrent_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a, b : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            y <= a and b;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    REQUIRE(assign.conditional_waveforms.size() == 1);
    REQUIRE_FALSE(assign.conditional_waveforms[0].condition.has_value());
    const auto &binary = std::get<ast::BinaryExpr>(assign.value);
    REQUIRE(binary.op == "and");
}

TEST_CASE("ConcurrentAssign: Multiple concurrent assignments",
          "[statements_concurrent][concurrent_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a, b : in std_logic; x, y : out std_logic);
        end E;
        architecture A of E is
        begin
            x <= a or b;
            y <= a and b;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 2);

    const auto &assign1 = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    const auto &target1 = std::get<ast::TokenExpr>(assign1.target);
    REQUIRE(target1.text == "x");
    REQUIRE(assign1.conditional_waveforms.size() == 1);
    REQUIRE_FALSE(assign1.conditional_waveforms[0].condition.has_value());
    const auto &value1 = std::get<ast::BinaryExpr>(assign1.value);
    REQUIRE(value1.op == "or");

    const auto &assign2 = std::get<ast::ConcurrentAssign>(arch.stmts[1]);
    const auto &target2 = std::get<ast::TokenExpr>(assign2.target);
    REQUIRE(target2.text == "y");
    REQUIRE(assign2.conditional_waveforms.size() == 1);
    REQUIRE_FALSE(assign2.conditional_waveforms[0].condition.has_value());
    const auto &value2 = std::get<ast::BinaryExpr>(assign2.value);
    REQUIRE(value2.op == "and");
}

TEST_CASE("ConcurrentAssign: Assignment with waveform delay",
          "[statements_concurrent][concurrent_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            y <= a after 10 ns;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    // Waveform details (after clause) are simplified in our AST
    // We just verify the assignment exists and has target/value
    const auto &target = std::get<ast::TokenExpr>(assign.target);
    REQUIRE(target.text == "y");
    const auto &value = std::get<ast::TokenExpr>(assign.value);
    REQUIRE(value.text == "a");
    REQUIRE(assign.conditional_waveforms.size() == 1);
    REQUIRE_FALSE(assign.conditional_waveforms[0].condition.has_value());
}

TEST_CASE("ConcurrentAssign: Assignment with multiple waveform elements",
          "[statements_concurrent][concurrent_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            y <= '0', a after 5 ns, '1' after 10 ns;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    // Multiple waveform elements are simplified in our AST
    // We just verify the assignment parses correctly
    const auto &target = std::get<ast::TokenExpr>(assign.target);
    REQUIRE(target.text == "y");
    const auto &value = std::get<ast::TokenExpr>(assign.value);
    REQUIRE(value.text == "'0'");
    REQUIRE(assign.conditional_waveforms.size() == 1);
    REQUIRE_FALSE(assign.conditional_waveforms[0].condition.has_value());
}

TEST_CASE("ConcurrentAssign: Assignment with transport delay",
          "[statements_concurrent][concurrent_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a : in std_logic; y : out std_logic);
        end E;
        architecture A of E is
        begin
            y <= transport a after 10 ns;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    // Delay mechanisms and waveforms are simplified in our AST
    // We just verify the assignment parses correctly
    const auto &target = std::get<ast::TokenExpr>(assign.target);
    REQUIRE(target.text == "y");
    const auto &value = std::get<ast::TokenExpr>(assign.value);
    REQUIRE(value.text == "a");
    REQUIRE(assign.conditional_waveforms.size() == 1);
    REQUIRE_FALSE(assign.conditional_waveforms[0].condition.has_value());
}

TEST_CASE("ConcurrentAssign: Conditional assignment", "[statements_concurrent][concurrent_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a, b : in std_logic; sel : in boolean; y : out std_logic);
        end E;
        architecture A of E is
        begin
            y <= a when sel else b;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);
    REQUIRE(assign.conditional_waveforms.size() == 2);
    const auto &first_wave = assign.conditional_waveforms[0];
    const auto &first_value = std::get<ast::TokenExpr>(first_wave.value);
    REQUIRE(first_value.text == "a");
    REQUIRE(first_wave.condition.has_value());
    const auto &cond = std::get<ast::TokenExpr>(first_wave.condition.value());
    REQUIRE(cond.text == "sel");
    const auto &else_wave = assign.conditional_waveforms[1];
    REQUIRE_FALSE(else_wave.condition.has_value());
    const auto &else_value = std::get<ast::TokenExpr>(else_wave.value);
    REQUIRE(else_value.text == "b");
}

TEST_CASE("ConcurrentAssign: Selected assignment", "[statements_concurrent][concurrent_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a, b, c : in std_logic; sel : in std_logic_vector(1 downto 0); y : out std_logic);
        end E;
        architecture A of E is
        begin
            with sel select
                y <= a when "00",
                     b when "01",
                     c when others;
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
    const auto &first_wave = assign.selected_waveforms[0];
    REQUIRE(first_wave.choices.size() == 1);
    const auto &choice = std::get<ast::TokenExpr>(first_wave.choices[0]);
    REQUIRE(choice.text == "\"00\"");
    const auto &first_value = std::get<ast::TokenExpr>(first_wave.value);
    REQUIRE(first_value.text == "a");
    REQUIRE(assign.selected_waveforms[1].choices.size() == 1);
    REQUIRE(std::get<ast::TokenExpr>(assign.selected_waveforms[1].choices[0]).text == "\"01\"");
    REQUIRE(std::get<ast::TokenExpr>(assign.selected_waveforms[1].value).text == "b");
    REQUIRE(assign.selected_waveforms[2].choices.size() == 1);
    REQUIRE(std::get<ast::TokenExpr>(assign.selected_waveforms[2].choices[0]).text == "others");
    REQUIRE(std::get<ast::TokenExpr>(assign.selected_waveforms[2].value).text == "c");
}
