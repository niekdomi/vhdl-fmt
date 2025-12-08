#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Loop: Simple infinite loop", "[statements][loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                loop
                    wait until clk = '1';
                end loop;
            end process;
        end RTL;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);
    REQUIRE_FALSE(proc->body.empty());

    const auto *loop = std::get_if<ast::Loop>(proc->body.data());
    REQUIRE(loop != nullptr);
    REQUIRE_FALSE(loop->label.has_value());
}

TEST_CASE("Loop: Labeled infinite loop", "[statements][loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                main_loop: loop
                    count := count + 1;
                end loop;
            end process;
        end RTL;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);
    REQUIRE_FALSE(proc->body.empty());

    const auto *loop = std::get_if<ast::Loop>(proc->body.data());
    REQUIRE(loop != nullptr);
    REQUIRE(loop->label.has_value());
    REQUIRE(loop->label.value() == "main_loop");
}

TEST_CASE("Loop: Infinite loop with multiple statements", "[statements][loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                loop
                    data_out <= data_in;
                    count := count + 1;
                    status <= '1';
                end loop;
            end process;
        end RTL;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);
    REQUIRE_FALSE(proc->body.empty());

    const auto *loop = std::get_if<ast::Loop>(proc->body.data());
    REQUIRE(loop != nullptr);
    REQUIRE(loop->body.size() == 3);
}
