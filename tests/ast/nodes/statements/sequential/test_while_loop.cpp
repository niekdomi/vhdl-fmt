#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("WhileLoop: Simple while loop", "[statements][while_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                while count < 10 loop
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

    const auto *while_loop = std::get_if<ast::WhileLoop>(proc->body.data());
    REQUIRE(while_loop != nullptr);
}

TEST_CASE("WhileLoop: While loop with comparison condition", "[statements][while_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                while index <= max_value loop
                    data(index) := '0';
                    index := index + 1;
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

    const auto *while_loop = std::get_if<ast::WhileLoop>(proc->body.data());
    REQUIRE(while_loop != nullptr);
}

TEST_CASE("WhileLoop: While loop with boolean condition", "[statements][while_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                while not done loop
                    process_data;
                    check_status;
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

    const auto *while_loop = std::get_if<ast::WhileLoop>(proc->body.data());
    REQUIRE(while_loop != nullptr);
}

TEST_CASE("WhileLoop: While loop with logical operators", "[statements][while_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                while enable = '1' and ready = '1' loop
                    transfer_data;
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

    const auto *while_loop = std::get_if<ast::WhileLoop>(proc->body.data());
    REQUIRE(while_loop != nullptr);
}

/*
TEST_CASE("WhileLoop: While loop with multiple statements", "[statements][while_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                while counter < limit loop
                    temp := data_in;
                    result := temp + offset;
                    counter := counter + 1;
                    valid := '1';
                end loop;
            end process;
        end RTL;
    )";

    auto design = builder::buildFromString(VHDL_FILE);
    auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);
    REQUIRE_FALSE(proc->body.empty());

    auto *while_loop = std::get_if<ast::WhileLoop>(proc->body.data());
    REQUIRE(while_loop != nullptr);
    REQUIRE_FALSE(while_loop->body.empty());
}
*/
