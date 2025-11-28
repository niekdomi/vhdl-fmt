#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("GroupExpr: Aggregate with others clause", "[expressions][group_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal data : std_logic_vector(7 downto 0) := (others => '0');
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &signal = std::get<ast::SignalDecl>(arch.decls[0]);
    REQUIRE(signal.init_expr.has_value());

    const auto &group = std::get<ast::GroupExpr>(signal.init_expr.value());
    REQUIRE_FALSE(group.children.empty());

    const auto &assoc = std::get<ast::BinaryExpr>(group.children[0]);
    REQUIRE(assoc.op == "=>");
    REQUIRE(assoc.left != nullptr);
    REQUIRE(assoc.right != nullptr);
    const auto &choice = std::get<ast::TokenExpr>(*assoc.left);
    REQUIRE(choice.text == "others");
    const auto &value = std::get<ast::TokenExpr>(*assoc.right);
    REQUIRE(value.text == "'0'");
}

TEST_CASE("GroupExpr: Positional aggregate", "[expressions][group_expr]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal flags : std_logic_vector(3 downto 0) := ('1', '0', '1', '0');
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &signal = std::get<ast::SignalDecl>(arch.decls[0]);
    REQUIRE(signal.init_expr.has_value());

    const auto &group = std::get<ast::GroupExpr>(signal.init_expr.value());
    REQUIRE(group.children.size() == 4);

    REQUIRE(std::get<ast::TokenExpr>(group.children[0]).text == "'1'");
    REQUIRE(std::get<ast::TokenExpr>(group.children[1]).text == "'0'");
    REQUIRE(std::get<ast::TokenExpr>(group.children[2]).text == "'1'");
    REQUIRE(std::get<ast::TokenExpr>(group.children[3]).text == "'0'");
}
