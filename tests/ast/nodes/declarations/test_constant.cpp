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

    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
    REQUIRE(decl_item != nullptr);
    const auto *constant = std::get_if<ast::ConstantDecl>(decl_item);
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

    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
    REQUIRE(decl_item != nullptr);
    const auto *constant = std::get_if<ast::ConstantDecl>(decl_item);
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

    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
    REQUIRE(decl_item != nullptr);
    const auto *constant = std::get_if<ast::ConstantDecl>(decl_item);
    REQUIRE(constant != nullptr);
    REQUIRE(constant->names[0] == "ENABLE");
    REQUIRE(constant->type_name == "boolean");
}

TEST_CASE("ConstantDecl: String constant", "[declarations][constant]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            constant MESSAGE : string := "Hello World";
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
    REQUIRE(decl_item != nullptr);
    const auto *constant = std::get_if<ast::ConstantDecl>(decl_item);
    REQUIRE(constant != nullptr);
    REQUIRE(constant->names[0] == "MESSAGE");
    REQUIRE(constant->type_name == "string");
    REQUIRE(constant->init_expr.has_value());
}

TEST_CASE("ConstantDecl: Multiple separate constant declarations", "[declarations][constant]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            constant WIDTH : integer := 8;
            constant HEIGHT : integer := 16;
            constant DEPTH : integer := 32;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 3);

    const auto *decl_item1 = std::get_if<ast::Declaration>(arch->decls.data());
    REQUIRE(decl_item1 != nullptr);
    const auto *const1 = std::get_if<ast::ConstantDecl>(decl_item1);
    REQUIRE(const1 != nullptr);
    REQUIRE(const1->names[0] == "WIDTH");

    const auto *decl_item2 = std::get_if<ast::Declaration>(&arch->decls[1]);
    REQUIRE(decl_item2 != nullptr);
    const auto *const2 = std::get_if<ast::ConstantDecl>(decl_item2);
    REQUIRE(const2 != nullptr);
    REQUIRE(const2->names[0] == "HEIGHT");

    const auto *decl_item3 = std::get_if<ast::Declaration>(&arch->decls[2]);
    REQUIRE(decl_item3 != nullptr);
    const auto *const3 = std::get_if<ast::ConstantDecl>(decl_item3);
    REQUIRE(const3 != nullptr);
    REQUIRE(const3->names[0] == "DEPTH");
}

TEST_CASE("ConstantDecl: Constant with expression initialization", "[declarations][constant]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            constant RESULT : integer := 10 + 20;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
    REQUIRE(decl_item != nullptr);
    const auto *constant = std::get_if<ast::ConstantDecl>(decl_item);
    REQUIRE(constant != nullptr);
    REQUIRE(constant->names[0] == "RESULT");
    REQUIRE(constant->type_name == "integer");
    REQUIRE(constant->init_expr.has_value());
}
