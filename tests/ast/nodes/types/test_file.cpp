#include "ast/nodes/declarations.hpp"
#include "ast/nodes/types.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("TypeDecl: File", "[builder][type][file]")
{
    SECTION("File type definition")
    {
        const auto *decl = test_helpers::parseType("type log_file_t is file of character;");
        REQUIRE(decl != nullptr);
        REQUIRE(decl->name == "log_file_t");

        const auto *def = std::get_if<ast::FileTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);
        REQUIRE(def->subtype.type_mark == "character");
    }
}
