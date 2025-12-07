#include "ast/nodes/declarations.hpp"
#include "ast/nodes/types.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <utility>

TEST_CASE("TypeDecl: Access", "[pretty_printer][type][access]")
{
    ast::TypeDecl type_decl;
    type_decl.name = "ptr_t";

    SECTION("Access type")
    {
        ast::AccessTypeDef access_def;
        access_def.pointed_type = "integer";

        type_decl.type_def = std::move(access_def);

        REQUIRE(emit::test::render(type_decl) == "type ptr_t is access integer;");
    }
}
