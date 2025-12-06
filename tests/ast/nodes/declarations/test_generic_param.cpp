#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("GenericParam: Single generic with default", "[declarations][generic]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            generic (WIDTH : integer := 8);
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto *entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->generic_clause.generics.size() == 1);

    const auto &generic = entity->generic_clause.generics[0];
    REQUIRE(generic.names.size() == 1);
    REQUIRE(generic.names[0] == "WIDTH");
    REQUIRE(generic.type_name == "integer");
    REQUIRE(generic.default_expr.has_value());
}

TEST_CASE("GenericParam: Generic without default", "[declarations][generic]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            generic (WIDTH : integer);
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->generic_clause.generics.size() == 1);

    const auto &generic = entity->generic_clause.generics[0];
    REQUIRE(generic.names[0] == "WIDTH");
    REQUIRE(generic.type_name == "integer");
    REQUIRE_FALSE(generic.default_expr.has_value());
}

TEST_CASE("GenericParam: Multiple generics same declaration", "[declarations][generic]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            generic (WIDTH, HEIGHT, DEPTH : integer := 8);
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->generic_clause.generics.size() == 1);

    const auto &generic = entity->generic_clause.generics[0];
    REQUIRE(generic.names.size() == 3);
    REQUIRE(generic.names[0] == "WIDTH");
    REQUIRE(generic.names[1] == "HEIGHT");
    REQUIRE(generic.names[2] == "DEPTH");
    REQUIRE(generic.type_name == "integer");
    REQUIRE(generic.default_expr.has_value());
}

TEST_CASE("GenericParam: Multiple separate generic declarations", "[declarations][generic]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            generic (
                WIDTH : integer := 8;
                RESET_VAL : integer := 0;
                ENABLE_ASYNC : boolean := false
            );
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->generic_clause.generics.size() == 3);

    REQUIRE(entity->generic_clause.generics[0].names[0] == "WIDTH");
    REQUIRE(entity->generic_clause.generics[0].type_name == "integer");

    REQUIRE(entity->generic_clause.generics[1].names[0] == "RESET_VAL");
    REQUIRE(entity->generic_clause.generics[1].type_name == "integer");

    REQUIRE(entity->generic_clause.generics[2].names[0] == "ENABLE_ASYNC");
    REQUIRE(entity->generic_clause.generics[2].type_name == "boolean");
}

TEST_CASE("GenericParam: Generic with expression default", "[declarations][generic]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            generic (ADDR_WIDTH : integer := 2 ** 8);
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->generic_clause.generics.size() == 1);

    const auto &generic = entity->generic_clause.generics[0];
    REQUIRE(generic.names[0] == "ADDR_WIDTH");
    REQUIRE(generic.default_expr.has_value());
}
