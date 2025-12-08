#include "ast/nodes/declarations.hpp"
#include "ast/nodes/declarations/objects.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <format>
#include <string_view>
#include <variant>

namespace {

/// @brief Helper for testing the Process Header (Label, Sensitivity).
[[nodiscard]]
auto parseProcess(std::string_view process_code) -> const ast::Process *
{
    return test_helpers::parseConcurrentStmt<ast::Process>(process_code);
}

/// @brief Helper for testing Process Declarations.
[[nodiscard]]
auto parseProcessDecls(std::string_view decls) -> const ast::Process *
{
    const auto code = std::format("process(clk)\n{}\nbegin\nend process;", decls);
    return test_helpers::parseConcurrentStmt<ast::Process>(code);
}

/// @brief Helper for testing Process Body.
[[nodiscard]]
auto parseProcessBody(std::string_view body) -> const ast::Process *
{
    const auto code = std::format("process(clk)\nbegin\n{}\nend process;", body);
    return test_helpers::parseConcurrentStmt<ast::Process>(code);
}

} // namespace

TEST_CASE("Process", "[builder][statements][process]")
{
    SECTION("Labels and Sensitivity Lists")
    {
        SECTION("Standard sensitivity list")
        {
            const auto *proc = parseProcess("process(clk, rst) begin null; end process;");
            REQUIRE(proc != nullptr);

            CHECK_FALSE(proc->label.has_value());
            REQUIRE(proc->sensitivity_list.size() == 2);
            CHECK(proc->sensitivity_list[0] == "clk");
            CHECK(proc->sensitivity_list[1] == "rst");
        }

        SECTION("Process with Label")
        {
            const auto *proc = parseProcess("sync_logic: process(clk) begin null; end process;");
            REQUIRE(proc != nullptr);

            REQUIRE(proc->label.has_value());
            CHECK(proc->label.value() == "sync_logic");
        }

        SECTION("Process without sensitivity list (Implicit)")
        {
            const auto *proc = parseProcess("process begin wait; end process;");
            REQUIRE(proc != nullptr);
            CHECK(proc->sensitivity_list.empty());
        }

        /* // TODO(vedivad): Support for Process End Labels
        SECTION("Process with End Label")
        {
            const auto *proc = parseProcess(
                "my_proc: process(clk)\n"
                "begin\n"
                "    null;\n"
                "end process my_proc;"
            );
            REQUIRE(proc != nullptr);

            // Assuming ast::Process adds: std::optional<std::string> end_label;
            REQUIRE(proc->end_label.has_value());
            CHECK(proc->end_label.value() == "my_proc");
        }
        */
    }

    SECTION("Declarative Part")
    {
        SECTION("Variables and Constants")
        {
            const auto *proc = parseProcessDecls("variable counter : integer := 0;\n"
                                                 "constant MAX : integer := 100;");
            REQUIRE(proc != nullptr);
            REQUIRE(proc->decls.size() == 2);

            // 1. Variable
            const auto *var = std::get_if<ast::VariableDecl>(proc->decls.data());
            REQUIRE(var != nullptr);
            CHECK(var->names[0] == "counter");
            CHECK(var->subtype.type_mark == "integer");

            // 2. Constant
            const auto *constant = std::get_if<ast::ConstantDecl>(&proc->decls[1]);
            REQUIRE(constant != nullptr);
            CHECK(constant->names[0] == "MAX");
        }

        SECTION("Shared Variables")
        {
            const auto *proc = parseProcessDecls("shared variable flag : boolean;");
            REQUIRE(proc != nullptr);

            const auto *shared = std::get_if<ast::VariableDecl>(proc->decls.data());
            REQUIRE(shared != nullptr);
            CHECK(shared->names[0] == "flag");
            CHECK(shared->shared);
        }

        SECTION("Type Declarations")
        {
            const auto *proc = parseProcessDecls("type state_t is (IDLE, BUSY);");
            REQUIRE(proc != nullptr);

            const auto *type = std::get_if<ast::TypeDecl>(proc->decls.data());
            REQUIRE(type != nullptr);
            CHECK(type->name == "state_t");
        }

        SECTION("Aliases and Files")
        {
            const auto *proc
              = parseProcessDecls("file output : text open write_mode is \"out.txt\";\n"
                                  "alias my_sig is external_sig;");
            REQUIRE(proc != nullptr);
            REQUIRE(proc->decls.size() == 2);
        }
    }

    SECTION("Body Container")
    {
        SECTION("Multiple Statements")
        {
            // Verify order and types of statements in the process body
            const auto *proc = parseProcessBody("counter := counter + 1;\n"
                                                "null;");
            REQUIRE(proc != nullptr);
            REQUIRE(proc->body.size() == 2);

            CHECK(std::holds_alternative<ast::VariableAssign>(proc->body[0]));
            CHECK(std::holds_alternative<ast::NullStatement>(proc->body[1]));
        }

        SECTION("Empty Body")
        {
            // Technically an empty process is valid syntax: `begin end process;`
            // But it creates an infinite simulation loop.
            const auto *proc = parseProcessBody("");
            REQUIRE(proc != nullptr);
            CHECK(proc->body.empty());
        }
    }
}
