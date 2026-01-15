#include "ast/nodes/declarations/objects.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("Declaration: Variable", "[builder][decl][variable]")
{
    auto parse_decl = test_helpers::parseDecl<ast::VariableDecl>;

    SECTION("Process variable")
    {
        const auto* decl = parse_decl("variable cnt : integer := 0;");
        REQUIRE(decl != nullptr);

        REQUIRE(decl->names.size() == 1);
        REQUIRE(decl->names.at(0) == "cnt");
        REQUIRE(decl->subtype.type_mark == "integer");
        REQUIRE_FALSE(decl->shared);
    }

    SECTION("Shared variable")
    {
        const auto* decl = parse_decl("shared variable mem : memory_t;");
        REQUIRE(decl != nullptr);

        REQUIRE(decl->names.at(0) == "mem");
        REQUIRE(decl->subtype.type_mark == "memory_t");
        REQUIRE(decl->shared == true);
    }
}
