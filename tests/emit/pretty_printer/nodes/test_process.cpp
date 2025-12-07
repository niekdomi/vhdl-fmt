#include "ast/nodes/declarations.hpp"
#include "ast/nodes/statements.hpp"
#include "emit/test_utils.hpp"
#include "nodes/expressions.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <utility>

TEST_CASE("Process Rendering", "[pretty_printer][process]")
{
    ast::Process proc;

    SECTION("Basic Process (No Sensitivity, No Decls)")
    {
        REQUIRE(emit::test::render(proc) == "process\nbegin\nend process;");
    }

    SECTION("Sensitivity List")
    {
        proc.sensitivity_list = { "clk", "rst" };

        // Should print as: process(clk, rst)
        const auto result = emit::test::render(proc);
        REQUIRE(result == "process(clk, rst)\nbegin\nend process;");
    }

    SECTION("Process with Declarations")
    {
        proc.sensitivity_list = { "clk" };

        // 1. Variable Declaration
        ast::VariableDecl var;
        var.names = { "counter" };
        var.subtype = ast::SubtypeIndication{ .type_mark = "integer" };
        var.init_expr = ast::TokenExpr{ .text = "0" };
        proc.decls.emplace_back(std::move(var));

        // 2. Constant Declaration
        ast::ConstantDecl constant;
        constant.names = { "MAX" };
        constant.subtype = ast::SubtypeIndication{ .type_mark = "integer" };
        constant.init_expr = ast::TokenExpr{ .text = "10" };
        proc.decls.emplace_back(std::move(constant));

        // 3. Body
        proc.body.emplace_back(ast::VariableAssign{ .target = ast::TokenExpr{ .text = "counter" },
                                                    .value = ast::TokenExpr{ .text = "0" } });

        constexpr std::string_view EXPECTED = "process(clk)\n"
                                              "  variable counter : integer := 0;\n"
                                              "  constant MAX : integer := 10;\n"
                                              "begin\n"
                                              "  counter := 0;\n"
                                              "end process;";

        REQUIRE(emit::test::render(proc) == EXPECTED);
    }

    SECTION("Process with Label")
    {
        proc.label = "csr_write";
        proc.sensitivity_list = { "clk", "rst" };

        const auto result = emit::test::render(proc);
        REQUIRE(result == "csr_write: process(clk, rst)\nbegin\nend process;");
    }

    SECTION("Process with Label and Body")
    {
        proc.label = "state_machine";
        proc.sensitivity_list = { "clk" };
        proc.body.emplace_back(ast::VariableAssign{ .target = ast::TokenExpr{ .text = "state" },
                                                    .value = ast::TokenExpr{ .text = "IDLE" } });

        constexpr std::string_view EXPECTED = "state_machine: process(clk)\n"
                                              "begin\n"
                                              "  state := IDLE;\n"
                                              "end process;";

        REQUIRE(emit::test::render(proc) == EXPECTED);
    }
}
