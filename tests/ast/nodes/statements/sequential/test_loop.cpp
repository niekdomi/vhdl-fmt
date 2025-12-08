#include "ast/nodes/statements/sequential.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("Loop", "[statements][loop]")
{
    auto parse_loop = test_helpers::parseSequentialStmt<ast::Loop>;

    SECTION("Simple infinite loop")
    {
        const auto *loop = parse_loop("loop null; end loop;");
        REQUIRE(loop != nullptr);
        REQUIRE(loop->body.size() == 1);
        CHECK(std::holds_alternative<ast::NullStatement>(loop->body[0]));
        CHECK_FALSE(loop->label.has_value());
    }

    SECTION("Labeled infinite loop")
    {
        const auto *loop = parse_loop("main_loop: loop count := count + 1; end loop;");
        REQUIRE(loop != nullptr);
        REQUIRE(loop->label.has_value());
        CHECK(loop->label.value() == "main_loop");
    }

    SECTION("Labeled loop")
    {
        const auto *loop = parse_loop("my_loop: loop\n"
                                      "    x := x + 1;\n"
                                      "    null;\n"
                                      "end loop my_loop;");
        REQUIRE(loop != nullptr);

        REQUIRE(loop->label.has_value());
        CHECK(loop->label.value() == "my_loop");

        REQUIRE(loop->body.size() == 2);
        CHECK(std::holds_alternative<ast::VariableAssign>(loop->body[0]));
        CHECK(std::holds_alternative<ast::NullStatement>(loop->body[1]));
    }

    SECTION("Infinite loop with multiple statements")
    {
        const auto *loop = parse_loop("loop\n"
                                      "    data_out <= data_in;\n"
                                      "    count := count + 1;\n"
                                      "    status <= '1';\n"
                                      "end loop;");
        REQUIRE(loop != nullptr);
        CHECK(loop->body.size() == 3);
    }
}
