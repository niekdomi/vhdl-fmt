#include "ast/nodes/declarations.hpp"
#include "type_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <optional>

TEST_CASE("TypeDecl: Incomplete", "[builder][type][incomplete]")
{
    SECTION("Forward declaration")
    {
        const auto* decl = type_utils::parseType("type node_t;");
        REQUIRE(decl != nullptr);
        REQUIRE(decl->name == "node_t");

        // type_def should be empty (std::nullopt)
        REQUIRE_FALSE(decl->type_def.has_value());
    }
}
