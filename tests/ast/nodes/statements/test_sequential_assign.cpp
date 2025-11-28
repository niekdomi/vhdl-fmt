#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Sequential Assignments", "[statements][assignment]")
{
    // A single process containing multiple assignment scenarios to test
    constexpr std::string_view VHDL_FILE
      = "entity Test is end Test;\n"
        "architecture RTL of Test is\n"
        "    signal sig_bit : bit;\n"
        "    signal sig_vec : bit_vector(7 downto 0);\n"
        "begin\n"
        "    process\n"
        "        variable var_int : integer;\n"
        "        variable var_a   : integer := 1;\n"
        "    begin\n"
        "        -- [0] Variable := Literal\n"
        "        var_int := 42;\n"
        "\n"
        "        -- [1] Variable := Binary Expression\n"
        "        var_int := var_a + 10;\n"
        "\n"
        "        -- [2] Signal <= Literal\n"
        "        sig_bit <= '1';\n"
        "\n"
        "        -- [3] Signal <= Complex Expression (Aggregate)\n"
        "        sig_vec <= (others => '0');\n"
        "    end process;\n"
        "end RTL;";

    const auto design = builder::buildFromString(VHDL_FILE);

    // 1. Get Architecture (Unit 1)
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    // 2. Get the Process (Statement 0)
    REQUIRE_FALSE(arch->stmts.empty());
    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);

    // We expect exactly 4 statements in the body
    REQUIRE(proc->body.size() == 4);

    SECTION("Variable Assignments (:=)")
    {
        SECTION("Literal Value")
        {
            // Check Statement [0]
            const auto *assign = std::get_if<ast::VariableAssign>(proc->body.data());
            REQUIRE(assign != nullptr);

            const auto *target = std::get_if<ast::TokenExpr>(&assign->target);
            const auto *value = std::get_if<ast::TokenExpr>(&assign->value);

            // Use CHECK so both are reported if they fail
            CHECK(target->text == "var_int");
            CHECK(value->text == "42");
        }

        SECTION("Binary Expression")
        {
            // Check Statement [1]: var_int := var_a + 10;
            const auto *assign = std::get_if<ast::VariableAssign>(&proc->body[1]);
            REQUIRE(assign != nullptr);

            CHECK(std::get<ast::TokenExpr>(assign->target).text == "var_int");

            // Verify structure is BinaryExpr, not just a Token
            const auto *bin_expr = std::get_if<ast::BinaryExpr>(&assign->value);
            REQUIRE(bin_expr != nullptr);

            CHECK(std::get<ast::TokenExpr>(*bin_expr->left).text == "var_a");
            CHECK(bin_expr->op == "+");
            CHECK(std::get<ast::TokenExpr>(*bin_expr->right).text == "10");
        }
    }

    SECTION("Signal Assignments (<=)")
    {
        SECTION("Simple Literal")
        {
            // Check Statement [2]
            const auto *assign = std::get_if<ast::SignalAssign>(&proc->body[2]);
            REQUIRE(assign != nullptr);

            const auto *target = std::get_if<ast::TokenExpr>(&assign->target);
            const auto *value = std::get_if<ast::TokenExpr>(&assign->value);

            CHECK(target->text == "sig_bit");
            CHECK(value->text == "'1'");
        }

        SECTION("Aggregate/Group Expression")
        {
            // Check Statement [3]: sig_vec <= (others => '0');
            const auto *assign = std::get_if<ast::SignalAssign>(&proc->body[3]);
            REQUIRE(assign != nullptr);

            CHECK(std::get<ast::TokenExpr>(assign->target).text == "sig_vec");

            // Verify structure: GroupExpr containing a BinaryExpr('=>')
            const auto *group = std::get_if<ast::GroupExpr>(&assign->value);
            REQUIRE(group != nullptr);
            REQUIRE_FALSE(group->children.empty());

            // Inside the group is "others => '0'" which parses as a BinaryExpr
            const auto *assoc = std::get_if<ast::BinaryExpr>(group->children.data());
            REQUIRE(assoc != nullptr);

            CHECK(assoc->op == "=>");
            CHECK(std::get<ast::TokenExpr>(*assoc->left).text == "others");
            CHECK(std::get<ast::TokenExpr>(*assoc->right).text == "'0'");
        }
    }
}
