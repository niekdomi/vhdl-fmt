#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

namespace {
// Helper to safely extract a statement from the process body
template<typename T>
[[nodiscard]]
auto getStmt(const ast::Process *proc, std::size_t index) -> const T *
{
    REQUIRE(index < proc->body.size());
    const auto *stmt = std::get_if<T>(&proc->body[index]);
    REQUIRE(stmt != nullptr);
    return stmt;
}
} // namespace

TEST_CASE("Control Flow Translator", "[builder][control_flow]")
{
    // A single VHDL source exercising all 4 control flow types
    constexpr std::string_view VHDL_FILE = "entity E is end E;\n"
                                           "architecture A of E is\n"
                                           "begin\n"
                                           "    process\n"
                                           "        variable x, y : integer := 0;\n"
                                           "        variable state : integer := 0;\n"
                                           "    begin\n"
                                           "        -- [0] IF Statement (If-Elsif-Else)\n"
                                           "        if x = 0 then\n"
                                           "            y := 1;\n"
                                           "        elsif x = 1 then\n"
                                           "            y := 2;\n"
                                           "        else\n"
                                           "            y := 3;\n"
                                           "        end if;\n"
                                           "\n"
                                           "        -- [1] CASE Statement\n"
                                           "        case state is\n"
                                           "            when 0 | 1 =>\n"
                                           "                x := 0;\n"
                                           "            when others =>\n"
                                           "                x := 1;\n"
                                           "        end case;\n"
                                           "\n"
                                           "        -- [2] FOR Loop\n"
                                           "        for i in 0 to 9 loop\n"
                                           "            x := x + 1;\n"
                                           "        end loop;\n"
                                           "\n"
                                           "        -- [3] WHILE Loop\n"
                                           "        while x < 20 loop\n"
                                           "            x := x + 1;\n"
                                           "        end loop;\n"
                                           "    end process;\n"
                                           "end A;";

    const auto design = builder::buildFromString(VHDL_FILE);

    // Navigate to Process
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(proc != nullptr);

    // Expect 4 statements (If, Case, For, While)
    REQUIRE(proc->body.size() == 4);

    SECTION("IF Statement")
    {
        const auto *stmt = getStmt<ast::IfStatement>(proc, 0);

        // Check IF Branch condition (x=0)
        const auto *if_cond = std::get_if<ast::BinaryExpr>(&stmt->if_branch.condition);
        CHECK(if_cond->op == "=");
        CHECK(std::get<ast::TokenExpr>(*if_cond->right).text == "0");
        CHECK(stmt->if_branch.body.size() == 1);

        // Check ELSIF Branch
        REQUIRE(stmt->elsif_branches.size() == 1);
        const auto *elsif_cond = std::get_if<ast::BinaryExpr>(&stmt->elsif_branches[0].condition);
        CHECK(std::get<ast::TokenExpr>(*elsif_cond->right).text == "1");

        // Check ELSE Branch
        REQUIRE(stmt->else_branch.has_value());
        CHECK(stmt->else_branch->body.size() == 1);
    }

    SECTION("CASE Statement")
    {
        const auto *stmt = getStmt<ast::CaseStatement>(proc, 1);

        // Check Selector (state)
        CHECK(std::get<ast::TokenExpr>(stmt->selector).text == "state");

        REQUIRE(stmt->when_clauses.size() == 2);

        // Clause 1: when 0 | 1
        const auto &c1 = stmt->when_clauses[0];
        REQUIRE(c1.choices.size() == 2);
        CHECK(std::get<ast::TokenExpr>(c1.choices[0]).text == "0");
        CHECK(std::get<ast::TokenExpr>(c1.choices[1]).text == "1");

        // Clause 2: when others
        const auto &c2 = stmt->when_clauses[1];
        REQUIRE(c2.choices.size() == 1);
        CHECK(std::get<ast::TokenExpr>(c2.choices[0]).text == "others");
    }

    SECTION("FOR Loop")
    {
        const auto *stmt = getStmt<ast::ForLoop>(proc, 2);

        CHECK(stmt->iterator == "i");

        // Range: 0 to 9
        const auto *range = std::get_if<ast::BinaryExpr>(&stmt->range);
        REQUIRE(range != nullptr);
        CHECK(range->op == "to");
        CHECK(std::get<ast::TokenExpr>(*range->left).text == "0");
        CHECK(std::get<ast::TokenExpr>(*range->right).text == "9");

        CHECK(stmt->body.size() == 1);
    }

    SECTION("WHILE Loop")
    {
        const auto *stmt = getStmt<ast::WhileLoop>(proc, 3);

        // Condition: x < 20
        const auto *cond = std::get_if<ast::BinaryExpr>(&stmt->condition);
        REQUIRE(cond != nullptr);
        CHECK(cond->op == "<");
        CHECK(std::get<ast::TokenExpr>(*cond->right).text == "20");

        CHECK(stmt->body.size() == 1);
    }
}
