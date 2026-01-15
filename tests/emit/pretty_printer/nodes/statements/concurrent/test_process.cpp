#include "ast/nodes/declarations/objects.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <utility>

TEST_CASE("Process Rendering", "[pretty_printer][process]")
{
    SECTION("Basic Process (No Sensitivity, No Decls)")
    {
        const ast::Process proc{};
        REQUIRE(emit::test::render(proc) == "process\nbegin\nend process;");
    }

    SECTION("Sensitivity List")
    {
        const ast::Process proc{
          .sensitivity_list = {"clk", "rst"}
        };

        const auto result = emit::test::render(proc);
        REQUIRE(result == "process(clk, rst)\nbegin\nend process;");
    }

    SECTION("Process with Declarations")
    {
        ast::Process proc{.sensitivity_list = {"clk"}};

        ast::VariableDecl var{};
        var.names = {"counter"};
        var.subtype = ast::SubtypeIndication{.type_mark = "integer"};
        var.init_expr = ast::TokenExpr{.text = "0"};
        proc.decls.emplace_back(std::move(var));

        ast::ConstantDecl constant{};
        constant.names = {"MAX"};
        constant.subtype = ast::SubtypeIndication{.type_mark = "integer"};
        constant.init_expr = ast::TokenExpr{.text = "10"};
        proc.decls.emplace_back(std::move(constant));

        ast::SequentialStatement body_stmt{};
        body_stmt.kind = ast::VariableAssign{
          .target = ast::TokenExpr{.text = "counter"},
          .value = ast::TokenExpr{.text = "0"},
        };
        proc.body.push_back(std::move(body_stmt));

        const std::string_view expected =
          "process(clk)\n" "  variable counter : integer := 0;\n" "  constant MAX : integer := 10;\n" "begin\n" "  counter := 0;\n" "end process;";

        REQUIRE(emit::test::render(proc) == expected);
    }

    SECTION("Process with Label")
    {
        ast::Process proc{
          .sensitivity_list = {"clk", "rst"}
        };

        ast::ConcurrentStatement wrapper{};
        wrapper.label = "csr_write";
        wrapper.kind = std::move(proc);

        const auto result = emit::test::render(wrapper);
        REQUIRE(result == "csr_write: process(clk, rst)\nbegin\nend process;");
    }

    SECTION("Process with Label and Body")
    {
        ast::Process proc{.sensitivity_list = {"clk"}};

        ast::SequentialStatement body_stmt{};
        body_stmt.kind = ast::VariableAssign{
          .target = ast::TokenExpr{.text = "state"},
          .value = ast::TokenExpr{.text = "IDLE"},
        };
        proc.body.push_back(std::move(body_stmt));

        ast::ConcurrentStatement wrapper{};
        wrapper.label = "state_machine";
        wrapper.kind = std::move(proc);

        const std::string_view expected =
          "state_machine: process(clk)\n" "begin\n" "  state := IDLE;\n" "end process;";

        REQUIRE(emit::test::render(wrapper) == expected);
    }
}
