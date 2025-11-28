#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("GenericClause: Single generic parameter", "[clauses][generic]")
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
    REQUIRE(entity.generic_clause.generics[0].names[0] == "WIDTH");
    REQUIRE(entity.generic_clause.generics[0].type_name == "integer");
    REQUIRE(entity.generic_clause.generics[0].default_expr.has_value());
}

TEST_CASE("GenericClause: Multiple generic parameters", "[clauses][generic]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            generic (
                WIDTH : integer := 8;
                DEPTH : natural := 256;
                ENABLE : boolean := true
            );
        end E;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.generic_clause.generics.size() == 3);
    REQUIRE(entity.generic_clause.generics[0].names[0] == "WIDTH");
    REQUIRE(entity.generic_clause.generics[1].names[0] == "DEPTH");
    REQUIRE(entity.generic_clause.generics[2].names[0] == "ENABLE");
}
