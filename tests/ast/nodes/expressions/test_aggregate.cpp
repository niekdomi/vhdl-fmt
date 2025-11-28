#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Aggregate: Positional aggregate", "[expressions][aggregate]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            signal vec : std_logic_vector(2 downto 0);
        begin
            vec <= ('1', '0', '1');
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    // Aggregates are represented as GroupExpr in the generic AST
    const auto &agg = std::get<ast::GroupExpr>(assign.value);
    REQUIRE(agg.children.size() == 3);

    const auto &first = std::get<ast::TokenExpr>(agg.children[0]);
    REQUIRE(first.text == "'1'");

    const auto &second = std::get<ast::TokenExpr>(agg.children[1]);
    REQUIRE(second.text == "'0'");

    const auto &third = std::get<ast::TokenExpr>(agg.children[2]);
    REQUIRE(third.text == "'1'");
}

TEST_CASE("Aggregate: Named aggregate with others", "[expressions][aggregate]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            signal vec : std_logic_vector(7 downto 0);
        begin
            vec <= (others => '0');
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    // Aggregates with named associations are represented as GroupExpr
    // containing BinaryExpr nodes with "=>" operator
    const auto &agg = std::get<ast::GroupExpr>(assign.value);
    REQUIRE_FALSE(agg.children.empty());

    // The first child should be a BinaryExpr representing "others => '0'"
    const auto &assoc = std::get<ast::BinaryExpr>(agg.children[0]);
    REQUIRE(assoc.op == "=>");
    REQUIRE(assoc.left != nullptr);
    REQUIRE(std::get<ast::TokenExpr>(*assoc.left).text == "others");
}

TEST_CASE("Aggregate: Mixed positional and named", "[expressions][aggregate]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            signal vec : std_logic_vector(3 downto 0);
        begin
            vec <= ('1', 1 => '0', others => '1');
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    // Mixed aggregates are also GroupExpr
    const auto &agg = std::get<ast::GroupExpr>(assign.value);
    REQUIRE(agg.children.size() == 3);

    const auto &first = std::get<ast::TokenExpr>(agg.children[0]);
    REQUIRE(first.text == "'1'");

    const auto &second = std::get<ast::BinaryExpr>(agg.children[1]);
    REQUIRE(second.left != nullptr);
    REQUIRE(std::get<ast::TokenExpr>(*second.left).text == "1");
    REQUIRE(std::get<ast::TokenExpr>(*second.right).text == "'0'");

    const auto &third = std::get<ast::BinaryExpr>(agg.children[2]);
    REQUIRE(third.left != nullptr);
    REQUIRE(std::get<ast::TokenExpr>(*third.left).text == "others");
    REQUIRE(std::get<ast::TokenExpr>(*third.right).text == "'1'");
}

TEST_CASE("Aggregate: Nested aggregate", "[expressions][aggregate]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            type matrix_t is array(0 to 1, 0 to 1) of std_logic;
            signal matrix : matrix_t;
        begin
            matrix <= (('0', '1'), ('1', '0'));
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    // Outer aggregate
    const auto &outer_agg = std::get<ast::GroupExpr>(assign.value);
    REQUIRE(outer_agg.children.size() == 2);

    // Each child of outer aggregate is itself a positional aggregate
    const auto &first_inner = std::get<ast::GroupExpr>(outer_agg.children[0]);
    REQUIRE(first_inner.children.size() == 2);
    REQUIRE(std::get<ast::TokenExpr>(first_inner.children[0]).text == "'0'");
    REQUIRE(std::get<ast::TokenExpr>(first_inner.children[1]).text == "'1'");

    const auto &second_inner = std::get<ast::GroupExpr>(outer_agg.children[1]);
    REQUIRE(second_inner.children.size() == 2);
    REQUIRE(std::get<ast::TokenExpr>(second_inner.children[0]).text == "'1'");
    REQUIRE(std::get<ast::TokenExpr>(second_inner.children[1]).text == "'0'");
}

TEST_CASE("Aggregate: Range choice in aggregate", "[expressions][aggregate]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            signal vec : std_logic_vector(7 downto 0);
        begin
            vec <= (7 downto 4 => '1', 3 downto 0 => '0');
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    // Aggregates with range choices
    const auto &agg = std::get<ast::GroupExpr>(assign.value);
    REQUIRE(agg.children.size() == 2);

    // Each child should be a named association (BinaryExpr with "=>")
    for (const auto &child : agg.children) {
        const auto &assoc = std::get<ast::BinaryExpr>(child);
        REQUIRE(assoc.op == "=>");
        const auto &range = std::get<ast::BinaryExpr>(*assoc.left);
        REQUIRE(range.op == "downto");
        REQUIRE(range.left != nullptr);
        REQUIRE(range.right != nullptr);
        REQUIRE(std::holds_alternative<ast::TokenExpr>(*range.left));
        REQUIRE(std::holds_alternative<ast::TokenExpr>(*range.right));
    }
}
