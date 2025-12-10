#include "ast/node.hpp"
#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace {
auto makePort(std::string name, std::string mode, std::string type) -> ast::Port
{
    return ast::Port{ .names = { std::move(name) },
                      .mode = std::move(mode),
                      .subtype = ast::SubtypeIndication{ .type_mark = std::move(type) } };
}

auto makeVectorPort(std::string name, std::string mode, std::string high, std::string low)
  -> ast::Port
{
    auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = std::move(high) });
    auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = std::move(low) });

    ast::IndexConstraint idx_constraint;
    idx_constraint.ranges.children.emplace_back(
      ast::BinaryExpr{ .left = std::move(left), .op = "downto", .right = std::move(right) });

    return ast::Port{
        .names = { std::move(name) },
        .mode = std::move(mode),
        .subtype
        = ast::SubtypeIndication{ .type_mark = "std_logic_vector",
                  .constraint = ast::Constraint(std::move(idx_constraint)) }
    };
}
} // namespace

TEST_CASE("Port Rendering", "[pretty_printer][declarations]")
{
    ast::Port port;
    // Default common settings
    port.mode = "in";
    port.subtype = ast::SubtypeIndication{ .type_mark = "std_logic" };

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
            port.subtype = ast::SubtypeIndication{ .type_mark = "std_logic_vector" };
            REQUIRE(emit::test::render(port) == "data_in, data_out : inout std_logic_vector");
        }
    }

    SECTION("With Constraints")
    {
        port.names = { "data" };
        port.subtype = ast::SubtypeIndication{ .type_mark = "std_logic_vector" };

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
            port.subtype = ast::SubtypeIndication{ .type_mark = "matrix_type" };

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

TEST_CASE("PortClause Rendering", "[pretty_printer][clauses][port]")
{
    ast::PortClause clause;

    SECTION("Empty Clause")
    {
        REQUIRE(emit::test::render(clause).empty());
    }

    SECTION("Single Port (Flat Layout)")
    {
        clause.ports.push_back(makePort("clk", "in", "std_logic"));
        REQUIRE(emit::test::render(clause) == "port ( clk : in std_logic );");
    }

    SECTION("Single Port (With Trivia)")
    {
        ast::Port port = makePort("reset", "in", "std_logic");

        port.addLeading(ast::Comment{ .text = "-- port leading" });
        port.addLeading(ast::Break{ .blank_lines = 1 });
        port.setInlineComment("-- port inline");
        port.addTrailing(ast::Break{ .blank_lines = 1 });
        port.addTrailing(ast::Comment{ .text = "-- port trailing" });

        clause.ports.push_back(std::move(port));

        clause.addLeading(ast::Comment{ .text = "-- Port clause starts here" });
        clause.addLeading(ast::Break{ .blank_lines = 1 });
        clause.setInlineComment("-- Inline comment for port clause");
        clause.addTrailing(ast::Break{ .blank_lines = 1 });
        clause.addTrailing(ast::Comment{ .text = "-- End of port clause" });

        constexpr std::string_view EXPECTED = "-- Port clause starts here\n"
                                              "\n"
                                              "port (\n"
                                              "  -- port leading\n"
                                              "  \n"
                                              "  reset : in std_logic -- port inline\n"
                                              "  \n"
                                              "  -- port trailing\n"
                                              "); -- Inline comment for port clause\n"
                                              "\n"
                                              "-- End of port clause";

        REQUIRE(emit::test::render(clause) == EXPECTED);
    }

    SECTION("Multiple Ports (Vertical Layout)")
    {
        clause.ports.push_back(makePort("clk", "in", "std_logic"));
        clause.ports.push_back(makePort("reset", "in", "std_logic"));

        SECTION("With Complex Constraints")
        {
            clause.ports.push_back(makeVectorPort("data_out", "out", "7", "0"));

            constexpr std::string_view EXPECTED = "port (\n"
                                                  "  clk : in std_logic;\n"
                                                  "  reset : in std_logic;\n"
                                                  "  data_out : out std_logic_vector(7 downto 0)\n"
                                                  ");";

            REQUIRE(emit::test::render(clause) == EXPECTED);
        }

        SECTION("Without Constraints")
        {
            clause.ports.push_back(makePort("output_signal", "out", "std_logic_vector"));

            constexpr std::string_view EXPECTED = "port (\n"
                                                  "  clk : in std_logic;\n"
                                                  "  reset : in std_logic;\n"
                                                  "  output_signal : out std_logic_vector\n"
                                                  ");";

            REQUIRE(emit::test::render(clause) == EXPECTED);
        }
    }
}
