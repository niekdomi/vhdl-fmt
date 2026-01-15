#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("IfStatement", "[statements][if]")
{
    auto parse_if = test_helpers::parseSequentialStmt<ast::IfStatement>;

    SECTION("Simple If")
    {
        const auto* stmt = parse_if("if enable = '1' then\n" "    data <= '1';\n" "end if;");
        REQUIRE(stmt != nullptr);

        // Check Branches
        REQUIRE(stmt->branches.size() == 1);

        // Check Condition
        const auto* cond = std::get_if<ast::BinaryExpr>(&stmt->branches.at(0).condition);
        REQUIRE(cond != nullptr);
        CHECK(cond->op == "=");

        // Check Body size
        CHECK(stmt->branches.at(0).body.size() == 1);

        // No else
        CHECK_FALSE(stmt->else_branch.has_value());
    }

    SECTION("If-Else")
    {
        const auto* stmt = parse_if(
          "if valid then\n" "    count := count + 1;\n" "else\n" "    error := '1';\n" "end if;");
        REQUIRE(stmt != nullptr);

        CHECK(stmt->branches.size() == 1);
        CHECK(stmt->branches.at(0).body.size() == 1);

        REQUIRE(stmt->else_branch.has_value());
        CHECK(stmt->else_branch->body.size() == 1);
    }

    SECTION("If-Elsif-Else")
    {
        const auto* stmt = parse_if(
          "if state = IDLE then\n" "    ready <= '1';\n" "elsif state = BUSY then\n" "    ready <= '0';\n" "elsif state = ERROR then\n" "    report \"error\";\n" "else\n" "    null;\n" "end if;");
        REQUIRE(stmt != nullptr);

        // 1 IF + 2 ELSIFs = 3 branches
        REQUIRE(stmt->branches.size() == 3);

        // Verify IF branch (Index 0)
        CHECK(stmt->branches.at(0).body.size() == 1);
        // Body contains wrappers, check .kind
        CHECK(std::holds_alternative<ast::SignalAssign>(stmt->branches.at(0).body.at(0).kind));

        // Check first elsif (Index 1)
        const auto* cond1 = std::get_if<ast::BinaryExpr>(&stmt->branches.at(1).condition);
        REQUIRE(cond1 != nullptr);
        CHECK(stmt->branches.at(1).body.size() == 1);
        CHECK(std::holds_alternative<ast::SignalAssign>(stmt->branches.at(1).body.at(0).kind));

        // Check second elsif (Index 2)
        const auto* cond2 = std::get_if<ast::BinaryExpr>(&stmt->branches.at(2).condition);
        REQUIRE(cond2 != nullptr);
        CHECK(stmt->branches.at(2).body.size() == 1);
        CHECK_FALSE(stmt->branches.at(2).body.empty());

        // Check else
        REQUIRE(stmt->else_branch.has_value());
        CHECK(stmt->else_branch->body.size() == 1);
        CHECK(std::holds_alternative<ast::NullStatement>(stmt->else_branch->body.at(0).kind));
    }
}

TEST_CASE("NullStatement", "[statements][null]")
{
    auto parse_null = test_helpers::parseSequentialStmt<ast::NullStatement>;

    SECTION("Simple Null")
    {
        const auto* stmt = parse_null("null;");
        REQUIRE(stmt != nullptr);
    }
}
