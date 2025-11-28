#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("ReportStatement: Simple report statement", "[statements_sequential][report_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
        begin
            process
            begin
                report "Test message";
                wait;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    const auto &report_stmt = std::get<ast::ReportStatement>(proc.body[0]);
    REQUIRE(std::get<ast::TokenExpr>(report_stmt.message).text == "\"Test message\"");
    REQUIRE_FALSE(report_stmt.severity.has_value());
}

TEST_CASE("ReportStatement: Report with severity level",
          "[statements_sequential][report_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
        begin
            process
            begin
                report "Warning message" severity warning;
                wait;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    const auto &report_stmt = std::get<ast::ReportStatement>(proc.body[0]);
    REQUIRE(std::get<ast::TokenExpr>(report_stmt.message).text == "\"Warning message\"");
    REQUIRE(std::get<ast::TokenExpr>(report_stmt.severity.value()).text == "warning");
}

TEST_CASE("ReportStatement: Report with error severity",
          "[statements_sequential][report_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
        begin
            process
            begin
                report "Critical error occurred" severity error;
                wait;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    const auto &report_stmt = std::get<ast::ReportStatement>(proc.body[0]);
    REQUIRE(std::get<ast::TokenExpr>(report_stmt.message).text == "\"Critical error occurred\"");
    REQUIRE(std::get<ast::TokenExpr>(report_stmt.severity.value()).text == "error");
}
