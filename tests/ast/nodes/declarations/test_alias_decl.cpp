#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("AliasDecl: Simple signal alias", "[declarations][alias_decl]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            signal data : std_logic_vector(7 downto 0);
            alias byte_data : std_logic_vector(7 downto 0) is data;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 2);

    const auto &signal = std::get<ast::SignalDecl>(arch.decls[0]);
    const auto &alias = std::get<ast::AliasDecl>(arch.decls[1]);
    REQUIRE(alias.name == "byte_data");
    REQUIRE(alias.type_name == "std_logic_vector");

    const auto &target_token = std::get<ast::TokenExpr>(alias.target);
    REQUIRE(target_token.text == "data");
}

TEST_CASE("AliasDecl: Alias for bit slice", "[declarations][alias_decl]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            signal data : std_logic_vector(15 downto 0);
            alias high_byte : std_logic_vector(7 downto 0) is data(15 downto 8);
            alias low_byte  : std_logic_vector(7 downto 0) is data(7 downto 0);
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 3);

    const auto &signal = std::get<ast::SignalDecl>(arch.decls[0]);
    const auto &high_alias = std::get<ast::AliasDecl>(arch.decls[1]);
    REQUIRE(high_alias.name == "high_byte");
    REQUIRE(high_alias.type_name == "std_logic_vector");

    const auto &high_call = std::get<ast::CallExpr>(high_alias.target);
    REQUIRE(high_call.callee != nullptr);

    const auto &high_callee = std::get<ast::TokenExpr>(*high_call.callee);
    REQUIRE(high_callee.text == "data");
    REQUIRE(high_call.args != nullptr);

    const auto &high_range = std::get<ast::BinaryExpr>(*high_call.args);
    REQUIRE(high_range.op == "downto");
    REQUIRE(high_range.left != nullptr);
    REQUIRE(high_range.right != nullptr);
    REQUIRE(std::get<ast::TokenExpr>(*high_range.left).text == "15");
    REQUIRE(std::get<ast::TokenExpr>(*high_range.right).text == "8");

    const auto &low_alias = std::get<ast::AliasDecl>(arch.decls[2]);
    REQUIRE(low_alias.name == "low_byte");
    REQUIRE(low_alias.type_name == "std_logic_vector");

    const auto &low_call = std::get<ast::CallExpr>(low_alias.target);
    REQUIRE(low_call.callee != nullptr);

    const auto &low_callee = std::get<ast::TokenExpr>(*low_call.callee);
    REQUIRE(low_callee.text == "data");
    REQUIRE(low_call.args != nullptr);

    const auto &low_range = std::get<ast::BinaryExpr>(*low_call.args);
    REQUIRE(low_range.op == "downto");
    REQUIRE(std::get<ast::TokenExpr>(*low_range.left).text == "7");
    REQUIRE(std::get<ast::TokenExpr>(*low_range.right).text == "0");
}

TEST_CASE("AliasDecl: Alias with different subtype", "[declarations][alias_decl]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            signal counter : integer;
            alias count_value : natural is counter;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 2);

    const auto &signal = std::get<ast::SignalDecl>(arch.decls[0]);
    const auto &alias = std::get<ast::AliasDecl>(arch.decls[1]);
    REQUIRE(alias.name == "count_value");
    REQUIRE(alias.type_name == "natural");

    const auto &target_token = std::get<ast::TokenExpr>(alias.target);
    REQUIRE(target_token.text == "counter");
}
