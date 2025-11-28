#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("SequentialAssign: Simple signal assignment in process",
          "[statements_sequential][sequential_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a : in std_logic; b : out std_logic);
        end E;
        architecture A of E is
        begin
            process(a)
            begin
                b <= a;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &assign = std::get<ast::SequentialAssign>(proc.body[0]);
    const auto &target = std::get<ast::TokenExpr>(assign.target);
    REQUIRE(target.text == "b");
    const auto &value = std::get<ast::TokenExpr>(assign.value);
    REQUIRE(value.text == "a");
}

TEST_CASE("SequentialAssign: Variable assignment with expression",
          "[statements_sequential][sequential_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic);
        end E;
        architecture A of E is
        begin
            process(clk)
                variable temp : integer;
            begin
                temp := 42;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &assign = std::get<ast::SequentialAssign>(proc.body[0]);
    const auto &target = std::get<ast::TokenExpr>(assign.target);
    REQUIRE(target.text == "temp");
    const auto &value = std::get<ast::TokenExpr>(assign.value);
    REQUIRE(value.text == "42");
}

TEST_CASE("SequentialAssign: Multiple sequential assignments",
          "[statements_sequential][sequential_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a, b : in std_logic; x, y : out std_logic);
        end E;
        architecture A of E is
        begin
            process(a, b)
            begin
                x <= a;
                y <= b;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 2);

    const auto &assign1 = std::get<ast::SequentialAssign>(proc.body[0]);
    const auto &target1 = std::get<ast::TokenExpr>(assign1.target);
    REQUIRE(target1.text == "x");
    const auto &value1 = std::get<ast::TokenExpr>(assign1.value);
    REQUIRE(value1.text == "a");

    const auto &assign2 = std::get<ast::SequentialAssign>(proc.body[1]);
    const auto &target2 = std::get<ast::TokenExpr>(assign2.target);
    REQUIRE(target2.text == "y");
    const auto &value2 = std::get<ast::TokenExpr>(assign2.value);
    REQUIRE(value2.text == "b");
}
