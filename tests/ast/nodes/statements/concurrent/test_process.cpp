#include "ast/nodes/declarations.hpp"
#include "ast/nodes/declarations/objects.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements.hpp" // For ConcurrentStatement wrapper
#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <format>
#include <string_view>
#include <variant>

namespace {

/// @brief Helper for testing the Process Header (Sensitivity).
[[nodiscard]]
auto parseProcess(std::string_view process_code) -> const ast::Process*
{
    return test_helpers::parseConcurrentStmt<ast::Process>(process_code);
}

/// @brief Helper for testing Process Declarations.
[[nodiscard]]
auto parseProcessDecls(std::string_view decls) -> const ast::Process*
{
    const auto code = std::format("process(clk)\n{}\nbegin\nend process;", decls);
    return test_helpers::parseConcurrentStmt<ast::Process>(code);
}

/// @brief Helper for testing Process Body.
[[nodiscard]]
auto parseProcessBody(std::string_view body) -> const ast::Process*
{
    const auto code = std::format("process(clk)\nbegin\n{}\nend process;", body);
    return test_helpers::parseConcurrentStmt<ast::Process>(code);
}

} // namespace

TEST_CASE("Process", "[builder][statements][process]")
{
    SECTION("Sensitivity Lists")
    {
        SECTION("Standard sensitivity list")
        {
            const auto* proc = parseProcess("process(clk, rst) begin null; end process;");
            REQUIRE(proc != nullptr);

            REQUIRE(proc->sensitivity_list.size() == 2);
            CHECK(proc->sensitivity_list.at(0) == "clk");
            CHECK(proc->sensitivity_list.at(1) == "rst");
        }

        SECTION("Process without sensitivity list (Implicit)")
        {
            const auto* proc = parseProcess("process begin wait; end process;");
            REQUIRE(proc != nullptr);
            CHECK(proc->sensitivity_list.empty());
        }
    }

    SECTION("Process Label (Verified on Wrapper)")
    {
        const std::string_view code = "sync_logic: process(clk) begin null; end process;";

        const auto* arch = test_helpers::parseArchitectureWithStmt(code);
        REQUIRE(arch != nullptr);
        REQUIRE(arch->stmts.size() == 1);

        const auto& wrapper = arch->stmts.at(0);

        // Verify Label on Wrapper
        REQUIRE(wrapper.label.has_value());
        CHECK(wrapper.label.value() == "sync_logic");

        // Verify Kind
        CHECK(std::holds_alternative<ast::Process>(wrapper.kind));

        // Verify Content access
        const auto& proc = std::get<ast::Process>(wrapper.kind);
        CHECK(proc.sensitivity_list.size() == 1);
        CHECK(proc.sensitivity_list.at(0) == "clk");
    }

    SECTION("Declarative Part")
    {
        SECTION("Variables and Constants")
        {
            const auto* proc = parseProcessDecls(
              "variable counter : integer := 0;\n" "constant MAX : integer := 100;");
            REQUIRE(proc != nullptr);
            REQUIRE(proc->decls.size() == 2);

            // 1. Variable
            const auto* var = std::get_if<ast::VariableDecl>(proc->decls.data());
            REQUIRE(var != nullptr);
            CHECK(var->names.at(0) == "counter");
            CHECK(var->subtype.type_mark == "integer");

            // 2. Constant
            const auto* constant = std::get_if<ast::ConstantDecl>(&proc->decls.at(1));
            REQUIRE(constant != nullptr);
            CHECK(constant->names.at(0) == "MAX");
        }

        SECTION("Shared Variables")
        {
            const auto* proc = parseProcessDecls("shared variable flag : boolean;");
            REQUIRE(proc != nullptr);

            const auto* shared = std::get_if<ast::VariableDecl>(proc->decls.data());
            REQUIRE(shared != nullptr);
            CHECK(shared->names.at(0) == "flag");
            CHECK(shared->shared);
        }

        SECTION("Type Declarations")
        {
            const auto* proc = parseProcessDecls("type state_t is (IDLE, BUSY);");
            REQUIRE(proc != nullptr);

            const auto* type = std::get_if<ast::TypeDecl>(proc->decls.data());
            REQUIRE(type != nullptr);
            CHECK(type->name == "state_t");
        }

        // TODO(vedivad): Support for Aliases and Files
        SECTION("Aliases and Files")
        {
            const auto* proc = parseProcessDecls(
              "file output : text open write_mode is \"out.txt\";\n" "alias my_sig is external_sig;");
            REQUIRE(proc != nullptr);

            REQUIRE(proc->decls.size() == 2);
        }
    }

    SECTION("Body Container")
    {
        SECTION("Multiple Statements")
        {
            // Verify order and types of statements in the process body
            const auto* proc = parseProcessBody("counter := counter + 1;\n" "null;");
            REQUIRE(proc != nullptr);
            REQUIRE(proc->body.size() == 2);

            // Process body contains SequentialStatement wrappers.
            // Check the 'kind' inside them.

            const auto& stmt1 = proc->body.at(0);
            CHECK(std::holds_alternative<ast::VariableAssign>(stmt1.kind));

            const auto& stmt2 = proc->body.at(1);
            CHECK(std::holds_alternative<ast::NullStatement>(stmt2.kind));
        }

        SECTION("Empty Body")
        {
            const auto* proc = parseProcessBody("");
            REQUIRE(proc != nullptr);
            CHECK(proc->body.empty());
        }
    }
}
