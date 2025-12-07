#include "ast/nodes/declarations/objects.hpp"
#include "ast/nodes/expressions.hpp"
#include "decl_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("Declaration: Signal", "[builder][decl][signal]")
{
    SECTION("Basic signal")
    {
        const auto *decl = decl_utils::parse<ast::SignalDecl>("signal clk : std_logic;");
        REQUIRE(decl != nullptr);

        REQUIRE(decl->names.size() == 1);
        REQUIRE(decl->names[0] == "clk");
        REQUIRE(decl->subtype.type_mark == "std_logic");
        REQUIRE_FALSE(decl->init_expr.has_value());
    }

    SECTION("Signal with resolution function")
    {
        const auto *decl = decl_utils::parse<ast::SignalDecl>("signal s : resolved std_logic;");
        REQUIRE(decl != nullptr);

        REQUIRE(decl->subtype.resolution_func.has_value());
        REQUIRE(decl->subtype.resolution_func.value() == "resolved");
        REQUIRE(decl->subtype.type_mark == "std_logic");
    }

    SECTION("Signal with BUS keyword")
    {
        // Requires VHDL-2008 or specific parser support, but AST supports it
        const auto *decl = decl_utils::parse<ast::SignalDecl>("signal bus_sig : wire bus;");
        REQUIRE(decl != nullptr);

        REQUIRE(decl->names[0] == "bus_sig");
        REQUIRE(decl->subtype.type_mark == "wire");
        REQUIRE(decl->has_bus_kw == true);
    }

    SECTION("Signal with index constraint and init")
    {
        const auto *decl = decl_utils::parse<ast::SignalDecl>(
          "signal data : std_logic_vector(7 downto 0) := (others => '0');");
        REQUIRE(decl != nullptr);

        REQUIRE(decl->subtype.type_mark == "std_logic_vector");

        // Verify Constraint
        REQUIRE(decl->subtype.constraint.has_value());
        const auto *idx = std::get_if<ast::IndexConstraint>(&decl->subtype.constraint.value());
        REQUIRE(idx != nullptr);

        // Verify Init Expr (Aggregate)
        REQUIRE(decl->init_expr.has_value());
        REQUIRE(std::holds_alternative<ast::GroupExpr>(decl->init_expr.value()));
    }
}
