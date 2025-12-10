#include "ast/nodes/statements.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string>
#include <string_view>
#include <variant>

TEST_CASE("Loop", "[statements][loop]")
{
    // Helper to parse just the inner loop body
    auto parse_loop_body = test_helpers::parseSequentialStmt<ast::Loop>;

    SECTION("Simple infinite loop")
    {
        const auto *loop = parse_loop_body("loop null; end loop;");
        REQUIRE(loop != nullptr);

        REQUIRE(loop->body.size() == 1);
        CHECK(std::holds_alternative<ast::NullStatement>(loop->body[0].kind));
    }

    SECTION("Infinite loop with multiple statements")
    {
        constexpr std::string_view CODE = R"(
            loop
                data_out <= data_in;
                count := count + 1;
                status <= '1';
            end loop;
        )";

        const auto *loop = parse_loop_body(CODE);
        REQUIRE(loop != nullptr);
        CHECK(loop->body.size() == 3);
    }

    SECTION("Labeled infinite loop")
    {
        constexpr std::string_view CODE = "process begin "
                                          "  main_loop: loop count := count + 1; end loop; "
                                          "end process;";

        const auto *proc = test_helpers::parseConcurrentStmt<ast::Process>(CODE);
        REQUIRE(proc != nullptr);
        REQUIRE(proc->body.size() == 1);

        const auto &wrapper = proc->body[0];

        // 1. Verify Label on Wrapper
        REQUIRE(wrapper.label.has_value());
        CHECK(wrapper.label.value() == "main_loop");

        // 2. Verify Inner Kind is Loop
        CHECK(std::holds_alternative<ast::Loop>(wrapper.kind));
    }

    SECTION("Labeled loop with end label")
    {
        constexpr std::string_view LOOP_CODE = "my_loop: loop\n"
                                               "    x := x + 1;\n"
                                               "    null;\n"
                                               "end loop my_loop;";

        const std::string proc_code = "process begin " + std::string(LOOP_CODE) + " end process;";

        const auto *proc = test_helpers::parseConcurrentStmt<ast::Process>(proc_code);
        REQUIRE(proc != nullptr);
        REQUIRE(proc->body.size() == 1);

        const auto &wrapper = proc->body[0];

        // 1. Verify Label
        REQUIRE(wrapper.label.has_value());
        CHECK(wrapper.label.value() == "my_loop");

        // 2. Verify Body Structure
        const auto *loop = std::get_if<ast::Loop>(&wrapper.kind);
        REQUIRE(loop != nullptr);
        REQUIRE(loop->body.size() == 2);

        CHECK(std::holds_alternative<ast::VariableAssign>(loop->body[0].kind));
        CHECK(std::holds_alternative<ast::NullStatement>(loop->body[1].kind));
    }
}