#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("WhileLoop", "[statements][while_loop]")
{
    auto parse_loop = test_helpers::parseSequentialStmt<ast::WhileLoop>;

    SECTION("Simple while loop")
    {
        const auto *loop = parse_loop("while count < 10 loop count := count + 1; end loop;");
        REQUIRE(loop != nullptr);

        // Verify Condition: count < 10
        const auto *cond = std::get_if<ast::BinaryExpr>(&loop->condition);
        REQUIRE(cond != nullptr);
        CHECK(cond->op == "<");
        CHECK(std::get<ast::TokenExpr>(*cond->left).text == "count");
        CHECK(std::get<ast::TokenExpr>(*cond->right).text == "10");

        // Verify Body
        REQUIRE_FALSE(loop->body.empty());

        // Access Wrapper -> Kind
        const auto *assign = std::get_if<ast::VariableAssign>(&loop->body[0].kind);
        REQUIRE(assign != nullptr);
        CHECK(std::get<ast::TokenExpr>(assign->target).text == "count");
    }

    SECTION("Comparison condition")
    {
        const auto *loop = parse_loop("while index <= max_value loop\n"
                                      "    data(index) := '0';\n"
                                      "    index := index + 1;\n"
                                      "end loop;");
        REQUIRE(loop != nullptr);

        // Verify Condition: index <= max_value
        const auto *cond = std::get_if<ast::BinaryExpr>(&loop->condition);
        REQUIRE(cond != nullptr);
        CHECK(cond->op == "<=");
        CHECK(std::get<ast::TokenExpr>(*cond->left).text == "index");
        CHECK(std::get<ast::TokenExpr>(*cond->right).text == "max_value");

        REQUIRE(loop->body.size() == 2);
        CHECK(std::holds_alternative<ast::VariableAssign>(loop->body[0].kind));
        CHECK(std::holds_alternative<ast::VariableAssign>(loop->body[1].kind));
    }

    SECTION("Boolean condition")
    {
        const auto *loop = parse_loop("while not done loop\n"
                                      "    process_data;\n"
                                      "    check_status;\n"
                                      "end loop;");
        REQUIRE(loop != nullptr);

        // Verify Condition: not done
        const auto *cond = std::get_if<ast::UnaryExpr>(&loop->condition);
        REQUIRE(cond != nullptr);
        CHECK(cond->op == "not");
        CHECK(std::get<ast::TokenExpr>(*cond->value).text == "done");

        CHECK(loop->body.size() == 2);
    }

    SECTION("Logical operators")
    {
        const auto *loop = parse_loop("while enable = '1' and ready = '1' loop\n"
                                      "    transfer_data;\n"
                                      "end loop;");
        REQUIRE(loop != nullptr);

        // Verify Condition: (enable = '1') and (ready = '1')
        const auto *cond = std::get_if<ast::BinaryExpr>(&loop->condition);
        REQUIRE(cond != nullptr);
        CHECK(cond->op == "and");

        CHECK(loop->body.size() == 1);
    }
}
