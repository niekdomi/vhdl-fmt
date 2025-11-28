#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_message.hpp>
#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("AssertStatement: Simple assert without message",
          "[statements_sequential][assert_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (data : in std_logic);
        end E;
        architecture A of E is
        begin
            process(data)
            begin
                assert data = '1';
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &assert_stmt = std::get<ast::AssertStatement>(proc.body[0]);
    const auto &cond = std::get<ast::BinaryExpr>(assert_stmt.condition);
    REQUIRE(cond.op == "=");
    REQUIRE(cond.left != nullptr);
    REQUIRE(cond.right != nullptr);
    REQUIRE(std::get<ast::TokenExpr>(*cond.left).text == "data");
    REQUIRE(std::get<ast::TokenExpr>(*cond.right).text == "'1'");
    REQUIRE_FALSE(assert_stmt.message.has_value());
    REQUIRE_FALSE(assert_stmt.severity.has_value());
}

TEST_CASE("AssertStatement: Assert with report message",
          "[statements_sequential][assert_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (valid : in boolean);
        end E;
        architecture A of E is
        begin
            process(valid)
            begin
                assert valid
                    report "Validation failed"
                    severity error;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &assert_stmt = std::get<ast::AssertStatement>(proc.body[0]);
    REQUIRE(std::get<ast::TokenExpr>(assert_stmt.condition).text == "valid");
    REQUIRE(std::get<ast::TokenExpr>(assert_stmt.message.value()).text == "\"Validation failed\"");
    REQUIRE(std::get<ast::TokenExpr>(assert_stmt.severity.value()).text == "error");
}

TEST_CASE("AssertStatement: Assert with complex condition",
          "[statements_sequential][assert_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk, reset : in std_logic);
        end E;
        architecture A of E is
        begin
            process(clk, reset)
            begin
                assert (clk = '1' and reset = '0')
                    report "Invalid clock/reset combination"
                    severity warning;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &assert_stmt = std::get<ast::AssertStatement>(proc.body[0]);
    const ast::BinaryExpr *cond = nullptr;
    if (std::holds_alternative<ast::BinaryExpr>(assert_stmt.condition)) {
        cond = &std::get<ast::BinaryExpr>(assert_stmt.condition);
    } else if (std::holds_alternative<ast::ParenExpr>(assert_stmt.condition)) {
        const auto &inner = *std::get<ast::ParenExpr>(assert_stmt.condition).inner;
        REQUIRE(std::holds_alternative<ast::BinaryExpr>(inner));
        cond = &std::get<ast::BinaryExpr>(inner);
    }
    REQUIRE(cond != nullptr);
    REQUIRE(cond->op == "and");
    REQUIRE(cond->left != nullptr);
    REQUIRE(cond->right != nullptr);
    const auto type_of = [](const ast::Expr &expr) -> const char * {
        if (std::holds_alternative<ast::BinaryExpr>(expr)) {
            return "binary";
        }
        if (std::holds_alternative<ast::ParenExpr>(expr)) {
            return "paren";
        }
        if (std::holds_alternative<ast::TokenExpr>(expr)) {
            return "token";
        }
        if (std::holds_alternative<ast::UnaryExpr>(expr)) {
            return "unary";
        }
        if (std::holds_alternative<ast::CallExpr>(expr)) {
            return "call";
        }
        if (std::holds_alternative<ast::GroupExpr>(expr)) {
            return "group";
        }
        return "other";
    };
    INFO("left type: " << type_of(*cond->left));
    INFO("right type: " << type_of(*cond->right));
    const ast::BinaryExpr *left_cond = nullptr;
    if (std::holds_alternative<ast::BinaryExpr>(*cond->left)) {
        left_cond = &std::get<ast::BinaryExpr>(*cond->left);
    } else if (std::holds_alternative<ast::ParenExpr>(*cond->left)) {
        const auto &inner = *std::get<ast::ParenExpr>(*cond->left).inner;
        REQUIRE(std::holds_alternative<ast::BinaryExpr>(inner));
        left_cond = &std::get<ast::BinaryExpr>(inner);
    }
    REQUIRE(left_cond != nullptr);
    REQUIRE(left_cond->op == "=");
    REQUIRE(std::get<ast::TokenExpr>(*left_cond->left).text == "clk");
    REQUIRE(std::get<ast::TokenExpr>(*left_cond->right).text == "'1'");

    const ast::BinaryExpr *right_cond = nullptr;
    if (std::holds_alternative<ast::BinaryExpr>(*cond->right)) {
        right_cond = &std::get<ast::BinaryExpr>(*cond->right);
    } else if (std::holds_alternative<ast::ParenExpr>(*cond->right)) {
        const auto &inner = *std::get<ast::ParenExpr>(*cond->right).inner;
        REQUIRE(std::holds_alternative<ast::BinaryExpr>(inner));
        right_cond = &std::get<ast::BinaryExpr>(inner);
    }
    REQUIRE(right_cond != nullptr);
    REQUIRE(right_cond->op == "=");
    REQUIRE(std::get<ast::TokenExpr>(*right_cond->left).text == "reset");
    REQUIRE(std::get<ast::TokenExpr>(*right_cond->right).text == "'0'");
    REQUIRE(std::get<ast::TokenExpr>(assert_stmt.message.value()).text
            == "\"Invalid clock/reset combination\"");
    REQUIRE(std::get<ast::TokenExpr>(assert_stmt.severity.value()).text == "warning");
}
