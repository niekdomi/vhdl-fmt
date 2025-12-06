#include "ast/nodes/declarations.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <optional>
#include <utility>

TEST_CASE("TypeDecl: Enumeration type rendering", "[pretty_printer][type]")
{
    ast::TypeDecl type_decl;
    type_decl.name = "ctrl_state_t";
    type_decl.kind = ast::TypeKind::ENUMERATION;

    SECTION("Two enumeration literals")
    {
        type_decl.enum_literals = { "S_IDLE", "S_BUSY" };
        REQUIRE(emit::test::render(type_decl) == "type ctrl_state_t is (S_IDLE, S_BUSY);");
    }

    SECTION("Multiple enumeration literals")
    {
        type_decl.enum_literals = { "IDLE", "RUNNING", "PAUSED", "STOPPED" };
        REQUIRE(emit::test::render(type_decl)
                == "type ctrl_state_t is (IDLE, RUNNING, PAUSED, STOPPED);");
    }

    SECTION("Single enumeration literal")
    {
        type_decl.enum_literals = { "SINGLE" };
        REQUIRE(emit::test::render(type_decl) == "type ctrl_state_t is (SINGLE);");
    }

    SECTION("Empty enumeration (edge case)")
    {
        type_decl.enum_literals = {};
        REQUIRE(emit::test::render(type_decl) == "type ctrl_state_t;");
    }
}

TEST_CASE("TypeDecl: Record type rendering", "[pretty_printer][type]")
{
    ast::TypeDecl type_decl;
    type_decl.name = "ctrl_engine_t";
    type_decl.kind = ast::TypeKind::RECORD;

    SECTION("Simple record with single elements")
    {
        ast::RecordElement elem1;
        elem1.names = { "state" };
        elem1.type_name = "ctrl_state_t";

        ast::RecordElement elem2;
        elem2.names = { "start" };
        elem2.type_name = "std_ulogic";

        ast::RecordElement elem3;
        elem3.names = { "valid" };
        elem3.type_name = "std_ulogic";

        type_decl.record_elements.push_back(std::move(elem1));
        type_decl.record_elements.push_back(std::move(elem2));
        type_decl.record_elements.push_back(std::move(elem3));

        const std::string expected = "type ctrl_engine_t is record\n"
                                     "  state : ctrl_state_t;\n"
                                     "  start : std_ulogic;\n"
                                     "  valid : std_ulogic;\n"
                                     "end record;";

        REQUIRE(emit::test::render(type_decl) == expected);
    }

    SECTION("Record with multiple names in one element")
    {
        ast::RecordElement elem1;
        elem1.names = { "ready", "valid", "done" };
        elem1.type_name = "std_ulogic";

        ast::RecordElement elem2;
        elem2.names = { "data" };
        elem2.type_name = "std_logic_vector";

        type_decl.record_elements.push_back(std::move(elem1));
        type_decl.record_elements.push_back(std::move(elem2));

        const std::string expected = "type ctrl_engine_t is record\n"
                                     "  ready, valid, done : std_ulogic;\n"
                                     "  data : std_logic_vector;\n"
                                     "end record;";

        REQUIRE(emit::test::render(type_decl) == expected);
    }

    SECTION("Record with end label")
    {
        ast::RecordElement elem;
        elem.names = { "value" };
        elem.type_name = "integer";

        type_decl.name = "data_t";
        type_decl.record_elements.push_back(std::move(elem));
        type_decl.end_label = "data_t";

        const std::string expected = "type data_t is record\n"
                                     "  value : integer;\n"
                                     "end record data_t;";

        REQUIRE(emit::test::render(type_decl) == expected);
    }

    SECTION("Empty record")
    {
        // record_elements is already empty by default, no need to set it
        REQUIRE(emit::test::render(type_decl) == "type ctrl_engine_t is record\nend record;");
    }

    SECTION("Record with constrained element")
    {
        ast::RecordElement elem1;
        elem1.names = { "address" };
        elem1.type_name = "std_logic_vector";

        // Create constraint: 7 downto 0
        auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "7" });
        auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });

        ast::IndexConstraint idx_constraint;
        idx_constraint.ranges.children.emplace_back(
          ast::BinaryExpr{ .left = std::move(left), .op = "downto", .right = std::move(right) });

        elem1.constraint = ast::Constraint(std::move(idx_constraint));

        type_decl.record_elements.push_back(std::move(elem1));

        const std::string expected = "type ctrl_engine_t is record\n"
                                     "  address : std_logic_vector(7 downto 0);\n"
                                     "end record;";

        REQUIRE(emit::test::render(type_decl) == expected);
    }
}

TEST_CASE("TypeDecl: Other type rendering", "[pretty_printer][type]")
{
    ast::TypeDecl type_decl;
    type_decl.kind = ast::TypeKind::OTHER;

    SECTION("Array type")
    {
        type_decl.name = "byte_array";
        type_decl.other_definition = "array(0to7)ofstd_logic";

        REQUIRE(emit::test::render(type_decl) == "type byte_array is array(0to7)ofstd_logic;");
    }

    SECTION("Access type")
    {
        type_decl.name = "int_ptr";
        type_decl.other_definition = "accessinteger";

        REQUIRE(emit::test::render(type_decl) == "type int_ptr is accessinteger;");
    }

    SECTION("File type")
    {
        type_decl.name = "text_file";
        type_decl.other_definition = "fileofcharacter";

        REQUIRE(emit::test::render(type_decl) == "type text_file is fileofcharacter;");
    }

    SECTION("Range type")
    {
        type_decl.name = "byte_range";
        type_decl.other_definition = "range0to255";

        REQUIRE(emit::test::render(type_decl) == "type byte_range is range0to255;");
    }

    SECTION("Incomplete type")
    {
        type_decl.name = "incomplete_t";
        type_decl.other_definition = "";

        REQUIRE(emit::test::render(type_decl) == "type incomplete_t;");
    }
}

TEST_CASE("RecordElement rendering", "[pretty_printer][type]")
{
    ast::RecordElement elem;

    SECTION("Single name")
    {
        elem.names = { "state" };
        elem.type_name = "ctrl_state_t";

        REQUIRE(emit::test::render(elem) == "state : ctrl_state_t;");
    }

    SECTION("Multiple names")
    {
        elem.names = { "ready", "valid", "done" };
        elem.type_name = "std_ulogic";

        REQUIRE(emit::test::render(elem) == "ready, valid, done : std_ulogic;");
    }

    SECTION("With constraint")
    {
        elem.names = { "data" };
        elem.type_name = "std_logic_vector";

        // Create constraint: 15 downto 0
        auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "15" });
        auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });

        ast::IndexConstraint idx_constraint;
        idx_constraint.ranges.children.emplace_back(
          ast::BinaryExpr{ .left = std::move(left), .op = "downto", .right = std::move(right) });

        elem.constraint = ast::Constraint(std::move(idx_constraint));

        REQUIRE(emit::test::render(elem) == "data : std_logic_vector(15 downto 0);");
    }
}
