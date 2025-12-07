#include "ast/node.hpp"
#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <string>
#include <string_view>
#include <utility>

namespace {

// Helper functions for test setup
auto makeGeneric(std::string name, std::string type, std::string def_val) -> ast::GenericParam
{
    return ast::GenericParam{ .names = { std::move(name) },
                              .subtype = ast::SubtypeIndication{ .type_mark = std::move(type) },
                              .default_expr = ast::TokenExpr{ .text = std::move(def_val) } };
}

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

TEST_CASE("GenericClause Rendering", "[pretty_printer][clauses][generic]")
{
    ast::GenericClause clause;

    SECTION("Empty Clause")
    {
        REQUIRE(emit::test::render(clause).empty());
    }

    SECTION("Single Parameter")
    {
        clause.generics.push_back(makeGeneric("WIDTH", "integer", "8"));
        REQUIRE(emit::test::render(clause) == "generic ( WIDTH : integer := 8 );");
    }

    SECTION("Multiple Parameters")
    {
        clause.generics.push_back(makeGeneric("WIDTH", "positive", "8"));
        clause.generics.push_back(makeGeneric("HEIGHT", "positive", "16"));

        REQUIRE(emit::test::render(clause)
                == "generic ( WIDTH : positive := 8; HEIGHT : positive := 16 );");
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
