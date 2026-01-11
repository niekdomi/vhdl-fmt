#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <format>
#include <string_view>
#include <variant>

namespace {

/// @brief Helper to parse a generic clause string within an entity.
/// @param generic_content The content inside 'generic ( ... );'
/// @return Pointer to the parsed Entity node.
[[nodiscard]]
auto parseGenerics(std::string_view generic_content) -> const ast::Entity *
{
    const auto code = std::format("entity E is generic ({}); end E;", generic_content);

    static ast::DesignFile design{};
    design = builder::buildFromString(code);

    if (design.units.empty()) {
        return nullptr;
    }

    return std::get_if<ast::Entity>(&design.units.front().unit);
}

} // namespace

TEST_CASE("Declaration: Generic Param", "[builder][decl][interface]")
{
    SECTION("Standard Generic")
    {
        const auto *entity = parseGenerics("CLK_PERIOD : time");
        REQUIRE(entity != nullptr);

        const auto &gen = entity->generic_clause.generics[0];
        CHECK(gen.names[0] == "CLK_PERIOD");
        CHECK(gen.subtype.type_mark == "time");
        CHECK_FALSE(gen.default_expr.has_value());
    }

    SECTION("Generic with default")
    {
        const auto *entity = parseGenerics("WIDTH : integer := 32");
        REQUIRE(entity != nullptr);

        const auto &generics = entity->generic_clause.generics;
        REQUIRE(generics.size() == 1);

        const auto &gen = generics[0];
        REQUIRE(gen.names.size() == 1);
        CHECK(gen.names[0] == "WIDTH");
        CHECK(gen.subtype.type_mark == "integer");

        REQUIRE(gen.default_expr.has_value());
        const auto *val = std::get_if<ast::TokenExpr>(&gen.default_expr.value());
        REQUIRE(val != nullptr);
        CHECK(val->text == "32");
    }

    SECTION("Generic with multiple names (comma-separated)")
    {
        const auto *entity = parseGenerics("N, M : integer := 0");
        REQUIRE(entity != nullptr);

        const auto &generics = entity->generic_clause.generics;
        REQUIRE(generics.size() == 1); // One declaration node

        const auto &gen = generics[0];
        REQUIRE(gen.names.size() == 2);
        CHECK(gen.names[0] == "N");
        CHECK(gen.names[1] == "M");
        CHECK(gen.subtype.type_mark == "integer");
    }

    SECTION("Generic with subtype constraint")
    {
        const auto *entity = parseGenerics("DELAY : time range 0 ns to 100 ns");
        REQUIRE(entity != nullptr);

        const auto &gen = entity->generic_clause.generics[0];
        CHECK(gen.names[0] == "DELAY");
        CHECK(gen.subtype.type_mark == "time");

        // Check constraint existence
        REQUIRE(gen.subtype.constraint.has_value());
        const auto *range = std::get_if<ast::RangeConstraint>(&gen.subtype.constraint.value());
        REQUIRE(range != nullptr);
        CHECK(range->range.op == "to");
    }

    SECTION("Multiple generic declarations (semicolon-separated)")
    {
        const auto *entity = parseGenerics("A : integer; B : boolean := false");
        REQUIRE(entity != nullptr);

        const auto &generics = entity->generic_clause.generics;
        REQUIRE(generics.size() == 2);

        // First declaration
        CHECK(generics[0].names[0] == "A");
        CHECK(generics[0].subtype.type_mark == "integer");

        // Second declaration
        CHECK(generics[1].names[0] == "B");
        CHECK(generics[1].subtype.type_mark == "boolean");
        REQUIRE(generics[1].default_expr.has_value());
    }
}
