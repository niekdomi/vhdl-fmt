#include "ast/nodes/declarations.hpp"
#include "ast/nodes/declarations/decl_utils.hpp"
#include "ast/nodes/types.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("Declaration: Type Wrapper", "[builder][decl][type]")
{
    SECTION("Incomplete Type Declaration")
    {
        const auto *decl = decl_utils::parse<ast::TypeDecl>("type node_t;");
        REQUIRE(decl != nullptr);

        CHECK(decl->name == "node_t");
        CHECK_FALSE(decl->type_def.has_value());
    }

    SECTION("Full Type Declaration (Wrapper Check)")
    {
        // We aren't testing the Record logic here (that's in types/test_record.cpp)
        // We just want to ensure the TypeDecl correctly wraps it.
        const auto *decl
          = decl_utils::parse<ast::TypeDecl>("type point is record x,y: integer; end record;");

        REQUIRE(decl != nullptr);
        CHECK(decl->name == "point");
        REQUIRE(decl->type_def.has_value());

        CHECK(std::holds_alternative<ast::RecordTypeDef>(decl->type_def.value()));
    }
}
