#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"
#include "nodes/statements.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("TypeDecl: Enumeration type", "[declarations][type]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            type ctrl_state_t is (S_IDLE, S_BUSY);
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
    REQUIRE(decl_item != nullptr);
    const auto *type_decl = std::get_if<ast::TypeDecl>(decl_item);
    REQUIRE(type_decl != nullptr);
    REQUIRE(type_decl->name == "ctrl_state_t");
    REQUIRE(type_decl->kind == ast::TypeKind::ENUMERATION);
    REQUIRE(type_decl->enum_literals.size() == 2);
    REQUIRE(type_decl->enum_literals[0] == "S_IDLE");
    REQUIRE(type_decl->enum_literals[1] == "S_BUSY");
}

TEST_CASE("TypeDecl: Record type", "[declarations][type]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            type ctrl_engine_t is record
                state : ctrl_state_t;
                start : std_ulogic;
                valid : std_ulogic;
            end record;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
    REQUIRE(decl_item != nullptr);
    const auto *type_decl = std::get_if<ast::TypeDecl>(decl_item);
    REQUIRE(type_decl != nullptr);
    REQUIRE(type_decl->name == "ctrl_engine_t");
    REQUIRE(type_decl->kind == ast::TypeKind::RECORD);
    REQUIRE(type_decl->record_elements.size() == 3);

    REQUIRE(type_decl->record_elements[0].names.size() == 1);
    REQUIRE(type_decl->record_elements[0].names[0] == "state");
    REQUIRE(type_decl->record_elements[0].type_name == "ctrl_state_t");

    REQUIRE(type_decl->record_elements[1].names.size() == 1);
    REQUIRE(type_decl->record_elements[1].names[0] == "start");
    REQUIRE(type_decl->record_elements[1].type_name == "std_ulogic");

    REQUIRE(type_decl->record_elements[2].names.size() == 1);
    REQUIRE(type_decl->record_elements[2].names[0] == "valid");
    REQUIRE(type_decl->record_elements[2].type_name == "std_ulogic");
}

TEST_CASE("TypeDecl: Record with end label", "[declarations][type]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            type data_t is record
                value : integer;
            end record data_t;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
    REQUIRE(decl_item != nullptr);
    const auto *type_decl = std::get_if<ast::TypeDecl>(decl_item);
    REQUIRE(type_decl != nullptr);
    REQUIRE(type_decl->name == "data_t");
    REQUIRE(type_decl->kind == ast::TypeKind::RECORD);
    REQUIRE(type_decl->end_label.has_value());
    REQUIRE(type_decl->end_label.value() == "data_t");
}

TEST_CASE("TypeDecl: Multiple record elements in one declaration", "[declarations][type]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            type flags_t is record
                ready, valid, done : std_ulogic;
            end record;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
    REQUIRE(decl_item != nullptr);
    const auto *type_decl = std::get_if<ast::TypeDecl>(decl_item);
    REQUIRE(type_decl != nullptr);
    REQUIRE(type_decl->kind == ast::TypeKind::RECORD);
    REQUIRE(type_decl->record_elements.size() == 1);

    REQUIRE(type_decl->record_elements[0].names.size() == 3);
    REQUIRE(type_decl->record_elements[0].names[0] == "ready");
    REQUIRE(type_decl->record_elements[0].names[1] == "valid");
    REQUIRE(type_decl->record_elements[0].names[2] == "done");
    REQUIRE(type_decl->record_elements[0].type_name == "std_ulogic");
}

TEST_CASE("TypeDecl: Array type (stored as text)", "[declarations][type]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            type byte_array is array (0 to 7) of std_logic;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
    REQUIRE(decl_item != nullptr);
    const auto *type_decl = std::get_if<ast::TypeDecl>(decl_item);
    REQUIRE(type_decl != nullptr);
    REQUIRE(type_decl->name == "byte_array");
    REQUIRE(type_decl->kind == ast::TypeKind::OTHER);
    REQUIRE_FALSE(type_decl->other_definition.empty());
}

TEST_CASE("TypeDecl: Incomplete type declaration", "[declarations][type]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            type incomplete_t;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    const auto *decl_item = std::get_if<ast::Declaration>(arch->decls.data());
    REQUIRE(decl_item != nullptr);
    const auto *type_decl = std::get_if<ast::TypeDecl>(decl_item);
    REQUIRE(type_decl != nullptr);
    REQUIRE(type_decl->name == "incomplete_t");
    REQUIRE(type_decl->kind == ast::TypeKind::OTHER);
    REQUIRE(type_decl->other_definition.empty());
}

TEST_CASE("TypeDecl: Type in process", "[declarations][type]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
        begin
            process
                type state_t is (IDLE, RUN);
            begin
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->stmts.size() == 1);

    const auto *process = std::get_if<ast::Process>(arch->stmts.data());
    REQUIRE(process != nullptr);
    REQUIRE(process->decls.size() == 1);

    const auto *type_decl = std::get_if<ast::TypeDecl>(process->decls.data());
    REQUIRE(type_decl != nullptr);
    REQUIRE(type_decl->name == "state_t");
    REQUIRE(type_decl->kind == ast::TypeKind::ENUMERATION);
    REQUIRE(type_decl->enum_literals.size() == 2);
    REQUIRE(type_decl->enum_literals[0] == "IDLE");
    REQUIRE(type_decl->enum_literals[1] == "RUN");
}
