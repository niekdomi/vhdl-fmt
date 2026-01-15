#include "ast/nodes/declarations/decl_utils.hpp"
#include "ast/nodes/declarations/objects.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("Declaration: Variable", "[builder][decl][variable]")
{
    SECTION("Process variable")
    {
        const auto* decl = decl_utils::parse<ast::VariableDecl>("variable cnt : integer := 0;");
        REQUIRE(decl != nullptr);

        REQUIRE(decl->names.size() == 1);
        REQUIRE(decl->names[0] == "cnt");
        REQUIRE(decl->subtype.type_mark == "integer");
        REQUIRE_FALSE(decl->shared);
    }

    SECTION("Shared variable")
    {
        const auto* decl = decl_utils::parse<ast::VariableDecl>("shared variable mem : memory_t;");
        REQUIRE(decl != nullptr);

        REQUIRE(decl->names[0] == "mem");
        REQUIRE(decl->subtype.type_mark == "memory_t");
        REQUIRE(decl->shared == true);
    }
}
