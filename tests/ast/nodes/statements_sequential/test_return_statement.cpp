#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("ReturnStatement: Simple return in function", "[statements_sequential][return_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            function get_value return integer is
            begin
                return 42;
            end function;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &func = std::get<ast::FunctionDecl>(arch.decls[0]);
    REQUIRE(func.name == "get_value");
    REQUIRE(func.return_type == "integer");
    REQUIRE(func.body.size() == 1);

    const auto &ret = std::get<ast::ReturnStatement>(func.body[0]);
    REQUIRE(ret.value.has_value());
    const auto &value = std::get<ast::TokenExpr>(ret.value.value());
    REQUIRE(value.text == "42");
}

TEST_CASE("ReturnStatement: Return with expression", "[statements_sequential][return_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            function add(a, b : integer) return integer is
            begin
                return a + b;
            end function;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &func = std::get<ast::FunctionDecl>(arch.decls[0]);
    REQUIRE(func.name == "add");
    REQUIRE(func.parameters.size() == 1);
    REQUIRE(func.parameters[0].names.size() == 2);
    REQUIRE(func.parameters[0].names[0] == "a");
    REQUIRE(func.parameters[0].names[1] == "b");
    REQUIRE(func.return_type == "integer");
    REQUIRE(func.body.size() == 1);

    const auto &ret = std::get<ast::ReturnStatement>(func.body[0]);
    REQUIRE(ret.value.has_value());
    const auto &expr = std::get<ast::BinaryExpr>(ret.value.value());
    REQUIRE(expr.op == "+");
    REQUIRE(std::get<ast::TokenExpr>(*expr.left).text == "a");
    REQUIRE(std::get<ast::TokenExpr>(*expr.right).text == "b");
}

TEST_CASE("ReturnStatement: Return in procedure (no value)",
          "[statements_sequential][return_statement]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            procedure early_exit is
            begin
                return;
            end procedure;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &proc = std::get<ast::ProcedureDecl>(arch.decls[0]);
    REQUIRE(proc.name == "early_exit");
    REQUIRE(proc.body.size() == 1);

    const auto &ret = std::get<ast::ReturnStatement>(proc.body[0]);
    REQUIRE_FALSE(ret.value.has_value());
}
