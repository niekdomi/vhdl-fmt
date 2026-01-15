#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("ForLoop", "[statements][for_loop]")
{
    auto parse_loop = test_helpers::parseSequentialStmt<ast::ForLoop>;

    SECTION("Simple for loop with to range")
    {
        const auto* for_loop = parse_loop("for i in 0 to 10 loop sum := sum + i; end loop;");
        REQUIRE(for_loop != nullptr);
        REQUIRE(for_loop->iterator == "i");

        // Verify Range: 0 to 10
        const auto* range = std::get_if<ast::BinaryExpr>(&for_loop->range);
        REQUIRE(range != nullptr);
        CHECK(range->op == "to");
        CHECK(std::get<ast::TokenExpr>(*range->left).text == "0");
        CHECK(std::get<ast::TokenExpr>(*range->right).text == "10");

        // Verify Body
        REQUIRE(for_loop->body.size() == 1);
    }

    SECTION("For loop with downto range")
    {
        const auto* for_loop = parse_loop("for i in 10 downto 0 loop data(i) := '0'; end loop;");
        REQUIRE(for_loop != nullptr);
        REQUIRE(for_loop->iterator == "i");

        // Verify Range: 10 downto 0
        const auto* range = std::get_if<ast::BinaryExpr>(&for_loop->range);
        REQUIRE(range != nullptr);
        CHECK(range->op == "downto");
        CHECK(std::get<ast::TokenExpr>(*range->left).text == "10");
        CHECK(std::get<ast::TokenExpr>(*range->right).text == "0");
    }

    SECTION("For loop with attribute range")
    {
        const auto* for_loop =
          parse_loop("for i in data'range loop result(i) := data(i); end loop;");
        REQUIRE(for_loop != nullptr);
        REQUIRE(for_loop->iterator == "i");

        // Verify Range: data'range
        const auto* attr = std::get_if<ast::AttributeExpr>(&for_loop->range);
        REQUIRE(attr != nullptr);
        CHECK(std::get<ast::TokenExpr>(*attr->prefix).text == "data");
        CHECK(attr->attribute == "range");
    }

    SECTION("For loop with multiple statements")
    {
        const auto* for_loop = parse_loop(
          "for i in 0 to 7 loop\n" "    temp := data(i);\n" "    result(i) := temp xor key;\n" "    valid(i) := '1';\n" "end loop;");
        REQUIRE(for_loop != nullptr);
        REQUIRE(for_loop->iterator == "i");
        REQUIRE_FALSE(for_loop->body.empty());
    }

    SECTION("Nested for loops")
    {
        const auto* outer_loop = parse_loop(
          "for i in 0 to 3 loop\n" "    for j in 0 to 3 loop\n" "        matrix(i, j) := i * j;\n" "    end loop;\n" "end loop;");
        REQUIRE(outer_loop != nullptr);

        // Verify Inner Loop
        REQUIRE(outer_loop->body.size() == 1);

        // Access Wrapper -> Kind
        CHECK(std::holds_alternative<ast::ForLoop>(outer_loop->body.at(0).kind));
        const auto& inner_loop = std::get<ast::ForLoop>(outer_loop->body.at(0).kind);

        REQUIRE(inner_loop.iterator == "j");

        // Verify Inner Body
        REQUIRE(inner_loop.body.size() == 1);
        CHECK(std::holds_alternative<ast::VariableAssign>(inner_loop.body.at(0).kind));
    }

    SECTION("For loop with larger range")
    {
        const auto* for_loop = parse_loop(
          "for idx in 0 to 255 loop\n" "    memory(idx) := (others => '0');\n" "end loop;");
        REQUIRE(for_loop != nullptr);
        REQUIRE(for_loop->iterator == "idx");
    }

    SECTION("For loop with if statement inside")
    {
        const auto* for_loop = parse_loop(
          "for i in 0 to 10 loop\n" "    if i mod 2 = 0 then\n" "        even_sum := even_sum + i;\n" "    else\n" "        odd_sum := odd_sum + i;\n" "    end if;\n" "end loop;");
        REQUIRE(for_loop != nullptr);
        REQUIRE(for_loop->iterator == "i");
        REQUIRE_FALSE(for_loop->body.empty());

        CHECK(std::holds_alternative<ast::IfStatement>(for_loop->body.at(0).kind));
    }
}
