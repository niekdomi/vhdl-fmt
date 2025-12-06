#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

// Helper to get expression from signal initialization
namespace {

auto getSignalInitExpr(const ast::DesignFile &design) -> const ast::Expr *
{
    if (design.units.size() < 2) {
        return nullptr;
    }

    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    if ((arch == nullptr) || arch->decls.empty()) {
        return nullptr;
    }

    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
    if (decl_item == nullptr) {
        return nullptr;
    }

    const auto *signal = std::get_if<ast::SignalDecl>(decl_item);
    if ((signal == nullptr) || !signal->init_expr.has_value()) {
        return nullptr;
    }

    return &(*signal->init_expr);
}

} // namespace

TEST_CASE("UnaryExpr: Negation operator", "[expressions][unary]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := -42;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *unary = std::get_if<ast::UnaryExpr>(expr);
    REQUIRE(unary != nullptr);
    REQUIRE(unary->op == "-");

    const auto *val = std::get_if<ast::TokenExpr>(unary->value.get());
    REQUIRE(val != nullptr);
    REQUIRE(val->text == "42");
}

TEST_CASE("UnaryExpr: Plus operator", "[expressions][unary]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := +42;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *unary = std::get_if<ast::UnaryExpr>(expr);
    REQUIRE(unary != nullptr);
    REQUIRE(unary->op == "+");

    const auto *val = std::get_if<ast::TokenExpr>(unary->value.get());
    REQUIRE(val != nullptr);
    REQUIRE(val->text == "42");
}

TEST_CASE("UnaryExpr: Not operator", "[expressions][unary]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : boolean := not true;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *unary = std::get_if<ast::UnaryExpr>(expr);
    REQUIRE(unary != nullptr);
    REQUIRE(unary->op == "not");

    const auto *val = std::get_if<ast::TokenExpr>(unary->value.get());
    REQUIRE(val != nullptr);
    REQUIRE(val->text == "true");
}

TEST_CASE("UnaryExpr: Not on identifier", "[expressions][unary]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : boolean := not ready;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *unary = std::get_if<ast::UnaryExpr>(expr);
    REQUIRE(unary != nullptr);
    REQUIRE(unary->op == "not");

    const auto *val = std::get_if<ast::TokenExpr>(unary->value.get());
    REQUIRE(val != nullptr);
    REQUIRE(val->text == "ready");
}
