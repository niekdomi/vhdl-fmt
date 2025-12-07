#include "ast/nodes/declarations.hpp"
#include "ast/nodes/types.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string>
#include <vector>

TEST_CASE("TypeDecl: Enumeration", "[pretty_printer][type][enum]")
{
    ast::TypeDecl type_decl;
    type_decl.name = "state_t";

    SECTION("Standard enumeration")
    {
        ast::EnumerationTypeDef enum_def;
        enum_def.literals = { "IDLE", "RUNNING", "STOPPED" };

        type_decl.type_def = std::move(enum_def);

        REQUIRE(emit::test::render(type_decl) == "type state_t is (IDLE, RUNNING, STOPPED);");
    }

    SECTION("Single literal")
    {
        ast::EnumerationTypeDef enum_def;
        enum_def.literals = { "SINGLE" };

        type_decl.type_def = std::move(enum_def);

        REQUIRE(emit::test::render(type_decl) == "type state_t is (SINGLE);");
    }

    // Note: The "empty enumeration" edge case produces "type name is ();"
    // Incomplete types are handled in test_incomplete.cpp
}
