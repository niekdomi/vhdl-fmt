#include "ast/nodes/declarations.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/types.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <string>
#include <utility>
#include <vector>

TEST_CASE("TypeDecl: Record", "[pretty_printer][type][record]")
{
    ast::TypeDecl type_decl{};
    type_decl.name = "packet_t";

    SECTION("Simple record (Populated, No Label)")
    {
        ast::RecordElement header{};
        header.names = { "id" };
        header.subtype.type_mark = "integer";

        ast::RecordElement payload{};
        payload.names = { "data" };
        payload.subtype.type_mark = "std_logic_vector";

        ast::RecordTypeDef record_def{};
        record_def.elements.push_back(std::move(header));
        record_def.elements.push_back(std::move(payload));

        type_decl.type_def = std::move(record_def);

        SECTION("Alignment")
        {
            constexpr auto EXPECTED = "type packet_t is record\n"
                                      "  id   : integer;\n"
                                      "  data : std_logic_vector;\n"
                                      "end record;";

            auto config = emit::test::defaultConfig();
            config.port_map.align_signals = true;

            REQUIRE(emit::test::render(type_decl, config) == EXPECTED);
        }
    }

    SECTION("Empty record (No Label)")
    {
        ast::RecordTypeDef record_def{};
        // No elements, no end_label
        type_decl.type_def = std::move(record_def);

        // Should render concisely on one line
        REQUIRE(emit::test::render(type_decl) == "type packet_t is record end record;");
    }

    SECTION("Empty record (With Label)")
    {
        ast::RecordTypeDef record_def{};
        record_def.end_label = "packet_t";

        type_decl.type_def = std::move(record_def);

        REQUIRE(emit::test::render(type_decl) == "type packet_t is record end record packet_t;");
    }

    SECTION("Populated record (With Label)")
    {
        ast::RecordElement elem{};
        elem.names = { "val" };
        elem.subtype.type_mark = "integer";

        ast::RecordTypeDef record_def{};
        record_def.elements.push_back(std::move(elem));
        record_def.end_label = "packet_t";

        type_decl.type_def = std::move(record_def);

        constexpr auto EXPECTED = "type packet_t is record\n"
                                  "  val : integer;\n"
                                  "end record packet_t;";

        REQUIRE(emit::test::render(type_decl) == EXPECTED);
    }
}

TEST_CASE("RecordElement Rendering", "[pretty_printer][type][record]")
{
    ast::RecordElement elem{};

    SECTION("Multiple names")
    {
        elem.names = { "r", "g", "b" };
        elem.subtype.type_mark = "byte";

        REQUIRE(emit::test::render(elem) == "r, g, b : byte;");
    }

    SECTION("Index Constrained element (Parentheses)")
    {
        elem.names = { "addr" };
        elem.subtype.type_mark = "unsigned";

        // Constraint: (31 downto 0)
        auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "31" });
        auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });

        ast::IndexConstraint constr{};
        constr.ranges.children.emplace_back(
          ast::BinaryExpr{ .left = std::move(left), .op = "downto", .right = std::move(right) });
        elem.subtype.constraint = ast::Constraint(std::move(constr));

        REQUIRE(emit::test::render(elem) == "addr : unsigned(31 downto 0);");
    }

    SECTION("Range Constrained element (Keyword)")
    {
        elem.names = { "level" };
        elem.subtype.type_mark = "integer";

        // Constraint: range 0 to 255
        auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });
        auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "255" });

        ast::RangeConstraint constr{};
        constr.range
          = ast::BinaryExpr{ .left = std::move(left), .op = "to", .right = std::move(right) };
        elem.subtype.constraint = ast::Constraint(std::move(constr));

        REQUIRE(emit::test::render(elem) == "level : integer range 0 to 255;");
    }
}
