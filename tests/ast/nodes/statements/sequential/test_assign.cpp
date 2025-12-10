#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("Sequential Assignments", "[statements][assignment]")
{
    // Helpers
    auto parse_var_assign = test_helpers::parseSequentialStmt<ast::VariableAssign>;
    auto parse_sig_assign = test_helpers::parseSequentialStmt<ast::SignalAssign>;

    SECTION("Variable Assignments (:=)")
    {
        SECTION("Literal Value")
        {
            const auto *assign = parse_var_assign("var_int := 42;");
            REQUIRE(assign != nullptr);

            const auto *target = std::get_if<ast::TokenExpr>(&assign->target);
            const auto *value = std::get_if<ast::TokenExpr>(&assign->value);

            CHECK(target->text == "var_int");
            CHECK(value->text == "42");
        }

        SECTION("Binary Expression")
        {
            const auto *assign = parse_var_assign("var_int := var_a + 10;");
            REQUIRE(assign != nullptr);

            CHECK(std::get<ast::TokenExpr>(assign->target).text == "var_int");
            const auto *bin_expr = std::get_if<ast::BinaryExpr>(&assign->value);
            REQUIRE(bin_expr != nullptr);
            CHECK(bin_expr->op == "+");
        }
    }

    SECTION("Signal Assignments (<=)")
    {
        SECTION("Simple Literal")
        {
            const auto *assign = parse_sig_assign("sig_bit <= '1';");
            REQUIRE(assign != nullptr);

            const auto *target = std::get_if<ast::TokenExpr>(&assign->target);
            CHECK(target->text == "sig_bit");

            REQUIRE_FALSE(assign->waveform.is_unaffected);
            REQUIRE(assign->waveform.elements.size() == 1);

            const auto *value = std::get_if<ast::TokenExpr>(&assign->waveform.elements[0].value);
            CHECK(value->text == "'1'");
        }

        SECTION("Aggregate/Group Expression")
        {
            const auto *assign = parse_sig_assign("sig_vec <= (others => '0');");
            REQUIRE(assign != nullptr);

            CHECK(std::get<ast::TokenExpr>(assign->target).text == "sig_vec");

            REQUIRE(assign->waveform.elements.size() == 1);
            const auto *group = std::get_if<ast::GroupExpr>(&assign->waveform.elements[0].value);
            REQUIRE(group != nullptr);

            const auto *assoc = std::get_if<ast::BinaryExpr>(group->children.data());
            REQUIRE(assoc != nullptr);
            CHECK(assoc->op == "=>");
        }
    }
}
