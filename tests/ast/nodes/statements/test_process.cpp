#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Process Translator", "[builder][process]")
{
    constexpr std::string_view VHDL_FILE
      = "entity E is end E;\n"
        "architecture A of E is\n"
        "begin\n"
        "    process(clk, rst)\n"
        "        -- [0] Variable Declaration\n"
        "        variable counter : integer := 0;\n"
        "        \n"
        "        -- [1] Constant Declaration\n"
        "        constant MAX_VAL : integer := 255;\n"
        "        \n"
        "        -- [2] Shared Variable Declaration\n"
        "        shared variable flags : bit_vector(7 downto 0);\n"
        "    begin\n"
        "        null;\n"
        "    end process;\n"
        "end A;";

    const auto design = builder::buildFromString(VHDL_FILE);

    // Navigate to the Process node
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE_FALSE(arch->stmts.empty());

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);

    SECTION("Sensitivity List")
    {
        REQUIRE(proc->sensitivity_list.size() == 2);
        CHECK(proc->sensitivity_list[0] == "clk");
        CHECK(proc->sensitivity_list[1] == "rst");
    }

    SECTION("Process Declarations")
    {
        REQUIRE(proc->decls.size() == 3);

        SECTION("Variable Declaration")
        {
            const auto *variable = std::get_if<ast::VariableDecl>(proc->decls.data());
            REQUIRE(variable != nullptr);

            CHECK(variable->names[0] == "counter");
            CHECK(variable->type_name == "integer");
            CHECK(variable->shared == false);
            CHECK(variable->init_expr.has_value());
        }

        SECTION("Constant Declaration")
        {
            const auto *constant = std::get_if<ast::ConstantDecl>(&proc->decls[1]);
            REQUIRE(constant != nullptr);

            CHECK(constant->names[0] == "MAX_VAL");
            CHECK(constant->type_name == "integer");
            CHECK(constant->init_expr.has_value());
        }

        SECTION("Shared Variable Declaration")
        {
            const auto *shared = std::get_if<ast::VariableDecl>(&proc->decls[2]);
            REQUIRE(shared != nullptr);

            CHECK(shared->names[0] == "flags");
            CHECK(shared->type_name == "bit_vector");
            CHECK(shared->shared == true);
        }
    }
}

TEST_CASE("Process with label", "[builder][process][label]")
{
    constexpr std::string_view VHDL_FILE = "entity E is end E;\n"
                                           "architecture A of E is\n"
                                           "begin\n"
                                           "    csr_write: process(clk, rst)\n"
                                           "    begin\n"
                                           "        null;\n"
                                           "    end process;\n"
                                           "end A;";

    const auto design = builder::buildFromString(VHDL_FILE);

    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->stmts.size() == 1);

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);

    SECTION("Label is captured")
    {
        REQUIRE(proc->label.has_value());
        CHECK(proc->label.value() == "csr_write");
    }

    SECTION("Sensitivity list is correct")
    {
        REQUIRE(proc->sensitivity_list.size() == 2);
        CHECK(proc->sensitivity_list[0] == "clk");
        CHECK(proc->sensitivity_list[1] == "rst");
    }
}

TEST_CASE("Process without label", "[builder][process][label]")
{
    constexpr std::string_view VHDL_FILE = "entity E is end E;\n"
                                           "architecture A of E is\n"
                                           "begin\n"
                                           "    process(clk)\n"
                                           "    begin\n"
                                           "        null;\n"
                                           "    end process;\n"
                                           "end A;";

    const auto design = builder::buildFromString(VHDL_FILE);

    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);

    CHECK_FALSE(proc->label.has_value());
}
