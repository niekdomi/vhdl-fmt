#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Process: Simple process with sensitivity list", "[statements_concurrent][process]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic);
        end E;
        architecture A of E is
        begin
            process(clk)
            begin
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.sensitivity_list.size() == 1);
    REQUIRE(proc.sensitivity_list[0] == "clk");
    REQUIRE(proc.body.empty());
}

TEST_CASE("Process: Process with multiple signals in sensitivity list",
          "[statements_concurrent][process]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk, reset : in std_logic);
        end E;
        architecture A of E is
        begin
            process(clk, reset)
            begin
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.sensitivity_list.size() == 2);
    REQUIRE(proc.sensitivity_list[0] == "clk");
    REQUIRE(proc.sensitivity_list[1] == "reset");
}

TEST_CASE("Process: Process with sequential statements", "[statements_concurrent][process]")
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
    REQUIRE(proc.sensitivity_list.size() == 1);
    REQUIRE(proc.body.size() == 1);
}
