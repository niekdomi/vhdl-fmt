#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("ForLoop: Simple for loop with to range", "[statements][for_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                for i in 0 to 10 loop
                    sum := sum + i;
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

    const auto *for_loop = std::get_if<ast::ForLoop>(proc->body.data());
    REQUIRE(for_loop != nullptr);
    REQUIRE(for_loop->iterator == "i");
}

TEST_CASE("ForLoop: For loop with downto range", "[statements][for_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                for i in 10 downto 0 loop
                    data(i) := '0';
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

    const auto *for_loop = std::get_if<ast::ForLoop>(proc->body.data());
    REQUIRE(for_loop != nullptr);
    REQUIRE(for_loop->iterator == "i");
}

TEST_CASE("ForLoop: For loop with attribute range", "[statements][for_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                for i in data'range loop
                    result(i) := data(i);
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

    const auto *for_loop = std::get_if<ast::ForLoop>(proc->body.data());
    REQUIRE(for_loop != nullptr);
    REQUIRE(for_loop->iterator == "i");
}

TEST_CASE("ForLoop: For loop with multiple statements", "[statements][for_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                for i in 0 to 7 loop
                    temp := data(i);
                    result(i) := temp xor key;
                    valid(i) := '1';
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

    const auto *for_loop = std::get_if<ast::ForLoop>(proc->body.data());
    REQUIRE(for_loop != nullptr);
    REQUIRE(for_loop->iterator == "i");
    REQUIRE_FALSE(for_loop->body.empty());
}

TEST_CASE("ForLoop: Nested for loops", "[statements][for_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                for i in 0 to 3 loop
                    for j in 0 to 3 loop
                        matrix(i, j) := i * j;
                    end loop;
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

    const auto *outer_loop = std::get_if<ast::ForLoop>(proc->body.data());
    REQUIRE(outer_loop != nullptr);
    REQUIRE(outer_loop->iterator == "i");
    REQUIRE_FALSE(outer_loop->body.empty());

    const auto *inner_loop = std::get_if<ast::ForLoop>(outer_loop->body.data());
    REQUIRE(inner_loop != nullptr);
    REQUIRE(inner_loop->iterator == "j");
}

TEST_CASE("ForLoop: For loop with larger range", "[statements][for_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                for idx in 0 to 255 loop
                    memory(idx) := (others => '0');
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

    const auto *for_loop = std::get_if<ast::ForLoop>(proc->body.data());
    REQUIRE(for_loop != nullptr);
    REQUIRE(for_loop->iterator == "idx");
}

TEST_CASE("ForLoop: For loop with if statement inside", "[statements][for_loop]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
        begin
            process
            begin
                for i in 0 to 10 loop
                    if i mod 2 = 0 then
                        even_sum := even_sum + i;
                    else
                        odd_sum := odd_sum + i;
                    end if;
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

    const auto *for_loop = std::get_if<ast::ForLoop>(proc->body.data());
    REQUIRE(for_loop != nullptr);
    REQUIRE(for_loop->iterator == "i");
    REQUIRE_FALSE(for_loop->body.empty());

    const auto *if_stmt = std::get_if<ast::IfStatement>(for_loop->body.data());
    REQUIRE(if_stmt != nullptr);
}
