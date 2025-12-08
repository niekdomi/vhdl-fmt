#include "ast/nodes/declarations.hpp"
#include "ast/nodes/types.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("TypeDecl: Enumeration", "[builder][type][enum]")
{
    SECTION("Standard enumeration")
    {
        const auto *decl = test_helpers::parseType("type state_t is (IDLE, RUNNING, STOPPED);");
        REQUIRE(decl != nullptr);
        REQUIRE(decl->name == "state_t");
        REQUIRE(decl->type_def.has_value());

        const auto *def = std::get_if<ast::EnumerationTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);

        REQUIRE(def->literals.size() == 3);
        REQUIRE(def->literals[0] == "IDLE");
        REQUIRE(def->literals[1] == "RUNNING");
        REQUIRE(def->literals[2] == "STOPPED");
    }

    SECTION("Single literal")
    {
        const auto *decl = test_helpers::parseType("type mode_t is (SINGLE);");
        REQUIRE(decl != nullptr);

        const auto *def = std::get_if<ast::EnumerationTypeDef>(&decl->type_def.value());
        REQUIRE(def != nullptr);

        REQUIRE(def->literals.size() == 1);
        REQUIRE(def->literals[0] == "SINGLE");
    }
}
