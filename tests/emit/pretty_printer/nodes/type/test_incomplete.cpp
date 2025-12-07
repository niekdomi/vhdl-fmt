#include "ast/nodes/declarations.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("TypeDecl: Incomplete", "[pretty_printer][type][incomplete]")
{
    SECTION("Forward declaration")
    {
        ast::TypeDecl type_decl{};
        type_decl.name = "node_t";
        // type_def is std::nullopt by default

        REQUIRE(emit::test::render(type_decl) == "type node_t;");
    }
}
