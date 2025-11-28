#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"
#include "nodes/declarations.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <string>
#include <string_view>
#include <utility>

TEST_CASE("GenericClause Rendering", "[pretty_printer][clauses][generic]")
{
    ast::GenericClause clause;

    SECTION("Empty Clause")
    {
        const auto result = emit::test::render(clause);
        REQUIRE(result.empty());
    }

    SECTION("Populated Clause")
    {
        SECTION("Single Parameter (Flat Layout)")
        {
            clause.generics.emplace_back(
              ast::GenericParam{ .names = { "WIDTH" },
                                 .type_name = "integer",
                                 .default_expr = ast::TokenExpr{ .text = "8" },
                                 .is_last = true });

            const auto result = emit::test::render(clause);
            REQUIRE(result == "generic ( WIDTH : integer := 8 );");
        }

        SECTION("Multiple Parameters (Flat Layout)")
        {
            // Note: Generics usually render flat unless extremely long
            clause.generics.emplace_back(
              ast::GenericParam{ .names = { "WIDTH" },
                                 .type_name = "positive",
                                 .default_expr = ast::TokenExpr{ .text = "8" },
                                 .is_last = false });

            clause.generics.emplace_back(
              ast::GenericParam{ .names = { "HEIGHT" },
                                 .type_name = "positive",
                                 .default_expr = ast::TokenExpr{ .text = "16" },
                                 .is_last = true });

            const auto result = emit::test::render(clause);
            REQUIRE(result == "generic ( WIDTH : positive := 8; HEIGHT : positive := 16 );");
        }
    }
}

TEST_CASE("PortClause Rendering", "[pretty_printer][clauses][port]")
{
    ast::PortClause clause;

    SECTION("Empty Clause")
    {
        const auto result = emit::test::render(clause);
        REQUIRE(result.empty());
    }

    SECTION("Populated Clause")
    {
        SECTION("Single Port (Flat Layout)")
        {
            clause.ports.emplace_back(ast::Port{
              .names = { "clk" }, .mode = "in", .type_name = "std_logic", .is_last = true });

            const auto result = emit::test::render(clause);
            REQUIRE(result == "port ( clk : in std_logic );");
        }

        SECTION("Multiple Ports (Vertical/Broken Layout)")
        {
            // 1. Simple Port
            clause.ports.emplace_back(ast::Port{
              .names = { "clk" }, .mode = "in", .type_name = "std_logic", .is_last = false });

            // 2. Simple Port
            clause.ports.emplace_back(ast::Port{
              .names = { "reset" }, .mode = "in", .type_name = "std_logic", .is_last = false });

            SECTION("With Complex Constraints")
            {
                // Build constraint: (7 downto 0)
                auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "7" });
                auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });

                ast::IndexConstraint idx_constraint;
                idx_constraint.ranges.children.emplace_back(ast::BinaryExpr{
                  .left = std::move(left), .op = "downto", .right = std::move(right) });

                // 3. Complex Port
                clause.ports.emplace_back(
                  ast::Port{ .names = { "data_out" },
                             .mode = "out",
                             .type_name = "std_logic_vector",
                             .constraint = ast::Constraint(std::move(idx_constraint)),
                             .is_last = true });

                const std::string result = emit::test::render(clause);
                constexpr std::string_view EXPECTED
                  = "port (\n"
                    "  clk : in std_logic;\n"
                    "  reset : in std_logic;\n"
                    "  data_out : out std_logic_vector(7 downto 0)\n"
                    ");";
                REQUIRE(result == EXPECTED);
            }

            SECTION("Without Constraints (Standard Vertical)")
            {
                // 3. Simple Port
                clause.ports.emplace_back(ast::Port{ .names = { "output_signal" },
                                                     .mode = "out",
                                                     .type_name = "std_logic_vector",
                                                     .is_last = true });

                const auto result = emit::test::render(clause);
                constexpr std::string_view EXPECTED = "port (\n"
                                                      "  clk : in std_logic;\n"
                                                      "  reset : in std_logic;\n"
                                                      "  output_signal : out std_logic_vector\n"
                                                      ");";
                REQUIRE(result == EXPECTED);
            }
        }
    }
}
