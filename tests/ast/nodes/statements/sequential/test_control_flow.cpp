#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("IfStatement", "[statements][if]")
{
    auto parse_if = test_helpers::parseSequentialStmt<ast::IfStatement>;

    SECTION("Simple If")
    {
        const auto *stmt = parse_if("if enable = '1' then\n"
                                    "    data <= '1';\n"
                                    "end if;");
        REQUIRE(stmt != nullptr);

        // Check Condition
        const auto *cond = std::get_if<ast::BinaryExpr>(&stmt->if_branch.condition);
        REQUIRE(cond != nullptr);
        CHECK(cond->op == "=");

        // Check Body
        CHECK(stmt->if_branch.body.size() == 1);

        // No elsif/else
        CHECK(stmt->elsif_branches.empty());
        CHECK_FALSE(stmt->else_branch.has_value());
    }

    SECTION("If-Else")
    {
        const auto *stmt = parse_if("if valid then\n"
                                    "    count := count + 1;\n"
                                    "else\n"
                                    "    error := '1';\n"
                                    "end if;");
        REQUIRE(stmt != nullptr);

        CHECK(stmt->if_branch.body.size() == 1);
        CHECK(stmt->elsif_branches.empty());

        REQUIRE(stmt->else_branch.has_value());
        CHECK(stmt->else_branch->body.size() == 1);
    }

    SECTION("If-Elsif-Else")
    {
        const auto *stmt = parse_if("if state = IDLE then\n"
                                    "    ready <= '1';\n"
                                    "elsif state = BUSY then\n"
                                    "    ready <= '0';\n"
                                    "elsif state = ERROR then\n"
                                    "    report \"error\";\n"
                                    "else\n"
                                    "    null;\n"
                                    "end if;");
        REQUIRE(stmt != nullptr);

        // Verify IF branch
        CHECK(stmt->if_branch.body.size() == 1);
        CHECK(std::holds_alternative<ast::SignalAssign>(stmt->if_branch.body[0]));

        REQUIRE(stmt->elsif_branches.size() == 2);

        // Check first elsif
        const auto *cond1 = std::get_if<ast::BinaryExpr>(&stmt->elsif_branches[0].condition);
        REQUIRE(cond1 != nullptr);
        CHECK(stmt->elsif_branches[0].body.size() == 1);
        CHECK(std::holds_alternative<ast::SignalAssign>(stmt->elsif_branches[0].body[0]));

        // Check second elsif
        const auto *cond2 = std::get_if<ast::BinaryExpr>(&stmt->elsif_branches[1].condition);
        REQUIRE(cond2 != nullptr);
        CHECK(stmt->elsif_branches[1].body.size() == 1);
        // TODO(vedivad): Once ReportStatement is supported, check for it
        CHECK_FALSE(stmt->elsif_branches[1].body.empty());

        // Check else
        REQUIRE(stmt->else_branch.has_value());
        CHECK(stmt->else_branch->body.size() == 1);
        CHECK(std::holds_alternative<ast::NullStatement>(stmt->else_branch->body[0]));
    }
}

TEST_CASE("NullStatement", "[statements][null]")
{
    auto parse_null = test_helpers::parseSequentialStmt<ast::NullStatement>;

    SECTION("Simple Null")
    {
        const auto *stmt = parse_null("null;");
        REQUIRE(stmt != nullptr);
    }
}
