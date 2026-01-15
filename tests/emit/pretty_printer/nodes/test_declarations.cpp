#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <optional>
#include <utility>

TEST_CASE("GenericParam Rendering", "[pretty_printer][declarations]")
{
    ast::GenericParam param{};
    // Default common settings
    param.subtype = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                                            .type_mark = "integer",
                                            .constraint = std::nullopt };

    SECTION("Basic Declarations")
    {
        SECTION("Single Name")
        {
            param.names = { "WIDTH" };
            REQUIRE(emit::test::render(param) == "WIDTH : integer");
        }

        SECTION("Multiple Names")
        {
            param.names = { "WIDTH", "HEIGHT", "DEPTH" };
            param.subtype = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                                                    .type_mark = "positive",
                                                    .constraint = std::nullopt }; // Override type
            REQUIRE(emit::test::render(param) == "WIDTH, HEIGHT, DEPTH : positive");
        }
    }

    SECTION("With Default Values")
    {
        SECTION("Single Name with Default")
        {
            param.names = { "WIDTH" };
            param.default_expr = ast::TokenExpr{ .text = "8" };
            REQUIRE(emit::test::render(param) == "WIDTH : integer := 8");
        }

        SECTION("Multiple Names with Default")
        {
            param.names = { "A", "B" };
            param.subtype = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                                                    .type_mark = "natural",
                                                    .constraint = std::nullopt };
            param.default_expr = ast::TokenExpr{ .text = "0" };
            REQUIRE(emit::test::render(param) == "A, B : natural := 0");
        }
    }
}

TEST_CASE("Port Rendering", "[pretty_printer][declarations]")
{
    ast::Port port;
    // Default common settings
    port.mode = "in";
    port.subtype = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                                           .type_mark = "std_logic",
                                           .constraint = std::nullopt };

    SECTION("Basic Declarations")
    {
        SECTION("Single Name")
        {
            port.names = { "clk" };
            REQUIRE(emit::test::render(port) == "clk : in std_logic");
        }

        SECTION("Multiple Names and Different Mode")
        {
            port.names = { "data_in", "data_out" };
            port.mode = "inout";
            port.subtype = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                                                   .type_mark = "std_logic_vector",
                                                   .constraint = std::nullopt };
            REQUIRE(emit::test::render(port) == "data_in, data_out : inout std_logic_vector");
        }
    }

    SECTION("With Constraints")
    {
        port.names = { "data" };
        port.subtype = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                                               .type_mark = "std_logic_vector",
                                               .constraint = std::nullopt };

        SECTION("Single Range (7 downto 0)")
        {
            // Create constraint: 7 downto 0
            auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "7" });
            auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });

            ast::IndexConstraint idx_constraint;
            idx_constraint.ranges.children.emplace_back(ast::BinaryExpr{
              .left = std::move(left), .op = "downto", .right = std::move(right) });

            port.subtype.constraint = ast::Constraint(std::move(idx_constraint));

            SECTION("Constraint Only")
            {
                REQUIRE(emit::test::render(port) == "data : in std_logic_vector(7 downto 0)");
            }

            SECTION("Constraint and Default Value")
            {
                port.default_expr = ast::TokenExpr{ .text = "X\"00\"" };
                REQUIRE(emit::test::render(port)
                        == "data : in std_logic_vector(7 downto 0) := X\"00\"");
            }
        }

        SECTION("Multi-dimensional Range")
        {
            port.names = { "matrix" };
            port.mode = "out";
            port.subtype = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                                                   .type_mark = "matrix_type",
                                                   .constraint = std::nullopt };

            // Constraint 1: 7 downto 0
            ast::BinaryExpr range1{ .left
                                    = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "7" }),
                                    .op = "downto",
                                    .right
                                    = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" }) };

            // Constraint 2: 3 downto 0
            ast::BinaryExpr range2{ .left
                                    = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "3" }),
                                    .op = "downto",
                                    .right
                                    = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" }) };

            ast::IndexConstraint idx_constraint{};
            idx_constraint.ranges.children.emplace_back(std::move(range1));
            idx_constraint.ranges.children.emplace_back(std::move(range2));

            port.subtype.constraint = ast::Constraint(std::move(idx_constraint));

            REQUIRE(emit::test::render(port) == "matrix : out matrix_type(7 downto 0, 3 downto 0)");
        }
    }

    SECTION("Default Value Only")
    {
        port.names = { "enable" };
        port.default_expr = ast::TokenExpr{ .text = "'0'" };
        REQUIRE(emit::test::render(port) == "enable : in std_logic := '0'");
    }
}
