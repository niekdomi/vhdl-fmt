#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("GenericParam: Single generic with default", "[declarations][generic]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            generic (WIDTH : integer := 8);
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.generic_clause.generics.size() == 1);

    const auto &generic = entity.generic_clause.generics[0];
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
    REQUIRE(design.units.size() == 1);
    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.generic_clause.generics.size() == 1);

    const auto &generic = entity.generic_clause.generics[0];
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
    REQUIRE(design.units.size() == 1);
    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.generic_clause.generics.size() == 1);

    const auto &generic = entity.generic_clause.generics[0];
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
                WIDTH : integer := 8
            );
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.generic_clause.generics.size() == 1);

    const auto &param = entity.generic_clause.generics[0];
    REQUIRE(param.names.size() == 1);
    REQUIRE(param.names[0] == "WIDTH");
    REQUIRE(param.type_name == "integer");
    REQUIRE(param.default_expr.has_value());
}

TEST_CASE("GenericParam: Generic with expression default", "[declarations][generic]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            generic (
                MIN, MAX, DEFAULT : integer := 42
            );
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.generic_clause.generics.size() == 1);

    const auto &param = entity.generic_clause.generics[0];
    REQUIRE(param.names.size() == 3);
    REQUIRE(param.names[0] == "MIN");
    REQUIRE(param.names[1] == "MAX");
    REQUIRE(param.names[2] == "DEFAULT");
    REQUIRE(param.type_name == "integer");
    REQUIRE(param.default_expr.has_value());
}

TEST_CASE("GenericParam: Generic without default value", "[declarations][generic_param]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            generic (
                DATA_WIDTH : positive
            );
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.generic_clause.generics.size() == 1);

    const auto &param = entity.generic_clause.generics[0];
    REQUIRE(param.names.size() == 1);
    REQUIRE(param.names[0] == "DATA_WIDTH");
    REQUIRE(param.type_name == "positive");
    REQUIRE_FALSE(param.default_expr.has_value());
}
