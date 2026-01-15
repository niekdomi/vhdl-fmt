#include "ast/nodes/declarations.hpp"
#include "ast/nodes/types.hpp"
#include "type_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("TypeDecl: Access", "[builder][type][access]")
{
    SECTION("Access type definition")
    {
        const auto* decl = type_utils::parseType("type ptr_t is access integer;");
        REQUIRE(decl != nullptr);
        REQUIRE(decl->name == "ptr_t");

        const auto* def = std::get_if<ast::AccessTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);
        REQUIRE(def->subtype.type_mark == "integer");
    }

    SECTION("Access to complex subtype")
    {
        const auto* decl = type_utils::parseType("type string_ptr is access string;");
        REQUIRE(decl != nullptr);

        const auto* def = std::get_if<ast::AccessTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);
        REQUIRE(def->subtype.type_mark == "string");
    }
}
