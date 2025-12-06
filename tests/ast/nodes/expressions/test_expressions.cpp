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
    const auto *signal = std::get_if<ast::SignalDecl>(arch->decls.data());
    if ((signal == nullptr) || !signal->init_expr.has_value()) {
        return nullptr;
    }
    return &(*signal->init_expr);
}

} // namespace

TEST_CASE("Token expression: integer literal", "[expressions][token]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := 42;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *tok = std::get_if<ast::TokenExpr>(expr);
    REQUIRE(tok != nullptr);
    REQUIRE(tok->text == "42");
}

TEST_CASE("Token expression: bit literal", "[expressions][token]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : std_logic := '1';
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *tok = std::get_if<ast::TokenExpr>(expr);
    REQUIRE(tok != nullptr);
    REQUIRE(tok->text == "'1'");
}

TEST_CASE("Token expression: identifier", "[expressions][token]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := MAX_VALUE;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *tok = std::get_if<ast::TokenExpr>(expr);
    REQUIRE(tok != nullptr);
    REQUIRE(tok->text == "MAX_VALUE");
}

TEST_CASE("Unary expression: negation", "[expressions][unary]")
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

TEST_CASE("Unary expression: not operator", "[expressions][unary]")
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
}

TEST_CASE("Unary expression: abs operator", "[expressions][unary]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := abs -5;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *unary = std::get_if<ast::UnaryExpr>(expr);
    REQUIRE(unary != nullptr);
    REQUIRE(unary->op == "abs");
}

TEST_CASE("Binary expression: addition", "[expressions][binary][arithmetic]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := 5 + 3;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *bin = std::get_if<ast::BinaryExpr>(expr);
    REQUIRE(bin != nullptr);
    REQUIRE(bin->op == "+");

    const auto *left = std::get_if<ast::TokenExpr>(bin->left.get());
    REQUIRE(left != nullptr);
    REQUIRE(left->text == "5");

    const auto *right = std::get_if<ast::TokenExpr>(bin->right.get());
    REQUIRE(right != nullptr);
    REQUIRE(right->text == "3");
}

TEST_CASE("Binary expression: exponentiation", "[expressions][binary][arithmetic]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := 2 ** 8;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *bin = std::get_if<ast::BinaryExpr>(expr);
    REQUIRE(bin != nullptr);
    REQUIRE(bin->op == "**");
}

TEST_CASE("Binary expression: or operator", "[expressions][binary][logical]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : boolean := a or b;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *bin = std::get_if<ast::BinaryExpr>(expr);
    REQUIRE(bin != nullptr);
    REQUIRE(bin->op == "or");
}

TEST_CASE("Binary expression: equality", "[expressions][binary][relational]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : boolean := count = 10;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *bin = std::get_if<ast::BinaryExpr>(expr);
    REQUIRE(bin != nullptr);
    REQUIRE(bin->op == "=");
}

TEST_CASE("Binary expression: downto range", "[expressions][binary][range]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (data : in std_logic_vector(7 downto 0));
        end E;
        architecture A of E is
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto *entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->port_clause.ports.size() == 1);

    const auto &port = entity->port_clause.ports[0];
    REQUIRE(port.constraints.size() == 1);

    const auto &range = port.constraints[0];
    REQUIRE(range.op == "downto");
}

TEST_CASE("Binary expression: to range", "[expressions][binary][range]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (data : in std_logic_vector(0 to 7));
        end E;
        architecture A of E is
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->port_clause.ports.size() == 1);

    const auto &port = entity->port_clause.ports[0];
    REQUIRE(port.constraints.size() == 1);

    const auto &range = port.constraints[0];
    REQUIRE(range.op == "to");
}

TEST_CASE("Binary expression: attribute (apostrophe)", "[expressions][binary][attribute]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := data'length;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *bin = std::get_if<ast::BinaryExpr>(expr);
    REQUIRE(bin != nullptr);
    REQUIRE(bin->op == "'");

    const auto *left = std::get_if<ast::TokenExpr>(bin->left.get());
    REQUIRE(left != nullptr);
    REQUIRE(left->text == "data");

    const auto *right = std::get_if<ast::TokenExpr>(bin->right.get());
    REQUIRE(right != nullptr);
    REQUIRE(right->text == "length");
}

TEST_CASE("Binary expression: selected name (dot)", "[expressions][binary][select]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := record_var.field;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    // For formatting, selected names are kept as single tokens
    // to avoid adding spaces like "record_var . field"
    const auto *tok = std::get_if<ast::TokenExpr>(expr);
    REQUIRE(tok != nullptr);
    REQUIRE(tok->text == "record_var.field");
}

// Parenthesized expressions
TEST_CASE("Parenthesized expression: complex", "[expressions][paren]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := (a + b);
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *paren = std::get_if<ast::ParenExpr>(expr);
    REQUIRE(paren != nullptr);

    const auto *inner = std::get_if<ast::BinaryExpr>(paren->inner.get());
    REQUIRE(inner != nullptr);
    REQUIRE(inner->op == "+");
}

TEST_CASE("Call expression: single argument", "[expressions][call]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : boolean := rising_edge(clk);
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *call = std::get_if<ast::CallExpr>(expr);
    REQUIRE(call != nullptr);

    const auto *callee = std::get_if<ast::TokenExpr>(call->callee.get());
    REQUIRE(callee != nullptr);
    REQUIRE(callee->text == "rising_edge");

    const auto *arg = std::get_if<ast::TokenExpr>(call->args.get());
    REQUIRE(arg != nullptr);
    REQUIRE(arg->text == "clk");
}

TEST_CASE("Call expression: multiple arguments", "[expressions][call]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := max(a, b);
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *call = std::get_if<ast::CallExpr>(expr);
    REQUIRE(call != nullptr);

    const auto *callee = std::get_if<ast::TokenExpr>(call->callee.get());
    REQUIRE(callee != nullptr);
    REQUIRE(callee->text == "max");

    const auto *args = std::get_if<ast::GroupExpr>(call->args.get());
    REQUIRE(args != nullptr);
    REQUIRE(args->children.size() == 2);
}

TEST_CASE("Call expression: array indexing", "[expressions][call]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : std_logic := data(5);
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *call = std::get_if<ast::CallExpr>(expr);
    REQUIRE(call != nullptr);

    const auto *callee = std::get_if<ast::TokenExpr>(call->callee.get());
    REQUIRE(callee != nullptr);
    REQUIRE(callee->text == "data");

    const auto *arg = std::get_if<ast::TokenExpr>(call->args.get());
    REQUIRE(arg != nullptr);
    REQUIRE(arg->text == "5");
}

TEST_CASE("Call expression: slice with range", "[expressions][call][slice]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : std_logic_vector := data(7 downto 0);
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *call = std::get_if<ast::CallExpr>(expr);
    REQUIRE(call != nullptr);

    const auto *callee = std::get_if<ast::TokenExpr>(call->callee.get());
    REQUIRE(callee != nullptr);
    REQUIRE(callee->text == "data");

    const auto *range_expr = std::get_if<ast::BinaryExpr>(call->args.get());
    REQUIRE(range_expr != nullptr);
    REQUIRE(range_expr->op == "downto");
}

TEST_CASE("Group expression: simple aggregate", "[expressions][group]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : std_logic_vector := (others => '0');
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *group = std::get_if<ast::GroupExpr>(expr);
    REQUIRE(group != nullptr);
    REQUIRE(group->children.size() == 1);

    const auto *elem = std::get_if<ast::BinaryExpr>(group->children.data());
    REQUIRE(elem != nullptr);
    REQUIRE(elem->op == "=>");
}

TEST_CASE("Group expression: multiple elements", "[expressions][group]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : std_logic_vector := (0 => '1', 1 => '0');
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *group = std::get_if<ast::GroupExpr>(expr);
    REQUIRE(group != nullptr);
    REQUIRE(group->children.size() == 2);

    // Both elements should be binary expressions with "=>" operator
    for (const auto &child : group->children) {
        const auto *elem = std::get_if<ast::BinaryExpr>(&child);
        REQUIRE(elem != nullptr);
        REQUIRE(elem->op == "=>");
    }
}

// Complex nested expressions
TEST_CASE("Complex expression: nested binary operations", "[expressions][complex]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := a + b * c;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    // Top-level should be addition
    const auto *add = std::get_if<ast::BinaryExpr>(expr);
    REQUIRE(add != nullptr);
    REQUIRE(add->op == "+");

    // Right side should be multiplication
    const auto *mul = std::get_if<ast::BinaryExpr>(add->right.get());
    REQUIRE(mul != nullptr);
    REQUIRE(mul->op == "*");
}

TEST_CASE("Complex expression: chained selections", "[expressions][complex]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := rec1.rec2.field;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    // For formatting, pure selected names (only dots, no calls/slices/attributes)
    // should be kept as a single TokenExpr to avoid unwanted spaces
    // This ensures "rec1.rec2.field" stays together, not "rec1 . rec2 . field"
    const auto *tok = std::get_if<ast::TokenExpr>(expr);
    REQUIRE(tok != nullptr);
    REQUIRE(tok->text == "rec1.rec2.field");
}

TEST_CASE("Complex expression: function call with arithmetic", "[expressions][complex]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := func(a + b);
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *expr = getSignalInitExpr(design);
    REQUIRE(expr != nullptr);

    const auto *call = std::get_if<ast::CallExpr>(expr);
    REQUIRE(call != nullptr);

    const auto *callee = std::get_if<ast::TokenExpr>(call->callee.get());
    REQUIRE(callee != nullptr);
    REQUIRE(callee->text == "func");

    const auto *arg = std::get_if<ast::BinaryExpr>(call->args.get());
    REQUIRE(arg != nullptr);
    REQUIRE(arg->op == "+");
}
