#include "ast/nodes/declarations.hpp"
#include "ast/nodes/types.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <utility>

TEST_CASE("TypeDecl: File", "[pretty_printer][type][file]")
{
    ast::TypeDecl type_decl;
    type_decl.name = "text_file_t";

    SECTION("File type")
    {
        ast::FileTypeDef file_def;
        file_def.content_type = "character";

        type_decl.type_def = std::move(file_def);

        REQUIRE(emit::test::render(type_decl) == "type text_file_t is file of character;");
    }
}
