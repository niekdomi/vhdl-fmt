#include "ast/nodes/declarations.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/types.hpp"
#include "type_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("TypeDecl: Record", "[builder][type][record]")
{
    SECTION("Simple record")
    {
        const auto *decl
          = type_utils::parseType("type point_t is record x, y : integer; end record;");
        REQUIRE(decl != nullptr);
        REQUIRE(decl->name == "point_t");

        const auto *def = std::get_if<ast::RecordTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);
        REQUIRE(def->elements.size() == 1);

        const auto &elem = def->elements[0];
        REQUIRE(elem.names.size() == 2);
        REQUIRE(elem.names[0] == "x");
        REQUIRE(elem.names[1] == "y");
        REQUIRE(elem.subtype.type_mark == "integer");
    }

    SECTION("Record with constraints and end label")
    {
        const auto *decl = type_utils::parseType("type packet_t is record \n"
                                                 "  data : std_logic_vector(7 downto 0);\n"
                                                 "  id   : integer;\n"
                                                 "end record packet_t;");
        REQUIRE(decl != nullptr);

        const auto *def = std::get_if<ast::RecordTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);
        REQUIRE(def->end_label.has_value());
        REQUIRE(def->end_label.value() == "packet_t");
        REQUIRE(def->elements.size() == 2);

        // Check first element constraint
        const auto &elem0 = def->elements[0];
        REQUIRE(elem0.names[0] == "data");
        REQUIRE(elem0.subtype.type_mark == "std_logic_vector");
        REQUIRE(elem0.subtype.constraint.has_value());
        const auto *idx = std::get_if<ast::IndexConstraint>(&elem0.subtype.constraint.value());
        REQUIRE(idx != nullptr);
    }
}
