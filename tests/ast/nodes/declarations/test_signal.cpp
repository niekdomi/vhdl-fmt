#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("SignalDecl: Single signal with type", "[declarations][signal]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal temp : std_logic;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *decl_item = std::get_if<ast::Declaration>(&arch->decls[0]);
    REQUIRE(decl_item != nullptr);
    const auto *signal = std::get_if<ast::SignalDecl>(decl_item);
    REQUIRE(signal != nullptr);
    REQUIRE(signal->names.size() == 1);
    REQUIRE(signal->names[0] == "temp");
    REQUIRE(signal->type_name == "std_logic");
    REQUIRE_FALSE(signal->init_expr.has_value());
}

TEST_CASE("SignalDecl: Signal with initialization", "[declarations][signal]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal count : integer := 42;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *decl_item = std::get_if<ast::Declaration>(&arch->decls[0]);
    REQUIRE(decl_item != nullptr);
    const auto *signal = std::get_if<ast::SignalDecl>(decl_item);
    REQUIRE(signal != nullptr);
    REQUIRE(signal->names.size() == 1);
    REQUIRE(signal->names[0] == "count");
    REQUIRE(signal->type_name == "integer");
    REQUIRE(signal->init_expr.has_value());
}

TEST_CASE("SignalDecl: Multiple signals same declaration", "[declarations][signal]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal clk, rst, enable : std_logic;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *decl_item = std::get_if<ast::Declaration>(&arch->decls[0]);
    REQUIRE(decl_item != nullptr);
    const auto *signal = std::get_if<ast::SignalDecl>(decl_item);
    REQUIRE(signal != nullptr);
    REQUIRE(signal->names.size() == 3);
    REQUIRE(signal->names[0] == "clk");
    REQUIRE(signal->names[1] == "rst");
    REQUIRE(signal->names[2] == "enable");
    REQUIRE(signal->type_name == "std_logic");
}
