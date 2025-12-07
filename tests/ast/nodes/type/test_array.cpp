#include "ast/nodes/declarations.hpp"
#include "ast/nodes/types.hpp"
#include "type_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("TypeDecl: Array", "[builder][type][array]")
{
    SECTION("Unconstrained array")
    {
        const auto *decl
          = type_utils::parseType("type mem_t is array(natural range <>) of std_logic;");
        REQUIRE(decl != nullptr);
        REQUIRE(decl->name == "mem_t");

        const auto *def = std::get_if<ast::ArrayTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);
        REQUIRE(def->element_type == "std_logic");
        REQUIRE(def->index_types.size() == 1);
        REQUIRE(def->index_types[0] == "natural");
    }

    SECTION("Constrained array")
    {
        const auto *decl = type_utils::parseType("type byte_t is array(7 downto 0) of bit;");
        REQUIRE(decl != nullptr);

        const auto *def = std::get_if<ast::ArrayTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);
        REQUIRE(def->element_type == "bit");
        REQUIRE(def->index_types.size() == 1);
        // Note: The builder currently extracts the raw text for constrained ranges
        REQUIRE(def->index_types[0] == "7 downto 0");
    }

    SECTION("Multi-dimensional unconstrained")
    {
        const auto *decl = type_utils::parseType(
          "type matrix_t is array(integer range <>, integer range <>) of real;");
        REQUIRE(decl != nullptr);

        const auto *def = std::get_if<ast::ArrayTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);
        REQUIRE(def->element_type == "real");
        REQUIRE(def->index_types.size() == 2);
        REQUIRE(def->index_types[0] == "integer");
        REQUIRE(def->index_types[1] == "integer");
    }
}
