#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Sequential Assignments", "[statements][assignment]")
{
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
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);
    REQUIRE(proc->body.size() == 4);

    SECTION("Variable Assignments (:=)")
    {
        // VariableAssign structure did NOT change, it still uses 'value'
        SECTION("Literal Value")
        {
            const auto *assign = std::get_if<ast::VariableAssign>(proc->body.data());
            REQUIRE(assign != nullptr);

            const auto *target = std::get_if<ast::TokenExpr>(&assign->target);
            const auto *value = std::get_if<ast::TokenExpr>(&assign->value);

            CHECK(target->text == "var_int");
            CHECK(value->text == "42");
        }

        SECTION("Binary Expression")
        {
            const auto *assign = std::get_if<ast::VariableAssign>(&proc->body[1]);
            REQUIRE(assign != nullptr);

            CHECK(std::get<ast::TokenExpr>(assign->target).text == "var_int");
            const auto *bin_expr = std::get_if<ast::BinaryExpr>(&assign->value);
            REQUIRE(bin_expr != nullptr);
            CHECK(bin_expr->op == "+");
        }
    }

    SECTION("Signal Assignments (<=)")
    {
        // SignalAssign structure CHANGED: uses 'waveform.elements'
        SECTION("Simple Literal")
        {
            const auto *assign = std::get_if<ast::SignalAssign>(&proc->body[2]);
            REQUIRE(assign != nullptr);

            const auto *target = std::get_if<ast::TokenExpr>(&assign->target);
            CHECK(target->text == "sig_bit");

            // New AST access:
            REQUIRE_FALSE(assign->waveform.is_unaffected);
            REQUIRE(assign->waveform.elements.size() == 1);

            const auto *value = std::get_if<ast::TokenExpr>(&assign->waveform.elements[0].value);
            CHECK(value->text == "'1'");
        }

        SECTION("Aggregate/Group Expression")
        {
            const auto *assign = std::get_if<ast::SignalAssign>(&proc->body[3]);
            REQUIRE(assign != nullptr);

            CHECK(std::get<ast::TokenExpr>(assign->target).text == "sig_vec");

            // New AST access:
            REQUIRE(assign->waveform.elements.size() == 1);
            const auto *group = std::get_if<ast::GroupExpr>(&assign->waveform.elements[0].value);
            REQUIRE(group != nullptr);

            const auto *assoc = std::get_if<ast::BinaryExpr>(group->children.data());
            REQUIRE(assoc != nullptr);
            CHECK(assoc->op == "=>");
        }
    }
}
