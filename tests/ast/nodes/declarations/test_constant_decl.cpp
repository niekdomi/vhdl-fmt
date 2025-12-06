#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("ConstantDecl: Simple constant with initialization", "[declarations][constant]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            constant WIDTH : integer := 8;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *constant = std::get_if<ast::ConstantDecl>(arch->decls.data());
    REQUIRE(constant != nullptr);
    REQUIRE(constant->names.size() == 1);
    REQUIRE(constant->names[0] == "WIDTH");
    REQUIRE(constant->type_name == "integer");
    REQUIRE(constant->init_expr.has_value());
}

TEST_CASE("ConstantDecl: Multiple constants same declaration", "[declarations][constant]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            constant MIN, MAX, DEFAULT : integer := 42;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *constant = std::get_if<ast::ConstantDecl>(arch->decls.data());
    REQUIRE(constant != nullptr);
    REQUIRE(constant->names.size() == 3);
    REQUIRE(constant->names[0] == "MIN");
    REQUIRE(constant->names[1] == "MAX");
    REQUIRE(constant->names[2] == "DEFAULT");
    REQUIRE(constant->type_name == "integer");
    REQUIRE(constant->init_expr.has_value());
}

TEST_CASE("ConstantDecl: Boolean constant", "[declarations][constant]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            constant ENABLE : boolean := true;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *constant = std::get_if<ast::ConstantDecl>(arch->decls.data());
    REQUIRE(constant != nullptr);
    REQUIRE(constant->names[0] == "ENABLE");
    REQUIRE(constant->type_name == "boolean");
}
