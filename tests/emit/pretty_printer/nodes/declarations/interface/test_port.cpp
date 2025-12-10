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

} // namespace

TEST_CASE("Port Rendering", "[pretty_printer][declarations]")
{
    ast::Port port = makePort("clk", "in", "std_logic");

    SECTION("Basic Declaration")
    {
        REQUIRE(emit::test::render(port) == "clk : in std_logic");
    }

    SECTION("Multiple Names")
    {
        port.names = { "a", "b" };
        REQUIRE(emit::test::render(port) == "a, b : in std_logic");
    }

    SECTION("With Constraints")
    {
        port.names = { "data" };
        port.subtype.type_mark = "std_logic_vector";

        // Create constraint: (7 downto 0)
        auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "7" });
        auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });

        ast::IndexConstraint idx_constraint{};
        idx_constraint.ranges.children.emplace_back(
          ast::BinaryExpr{ .left = std::move(left), .op = "downto", .right = std::move(right) });

        port.subtype.constraint = ast::Constraint(std::move(idx_constraint));

        SECTION("Constraint Only")
        {
            REQUIRE(emit::test::render(port) == "data : in std_logic_vector(7 downto 0)");
        }

        SECTION("Constraint and Default Value")
        {
            port.default_expr = ast::TokenExpr{ .text = "x\"00\"" };
            REQUIRE(emit::test::render(port)
                    == "data : in std_logic_vector(7 downto 0) := x\"00\"");
        }
    }
}

TEST_CASE("PortClause Rendering", "[pretty_printer][clauses][port]")
{
    ast::PortClause clause{};

    SECTION("Empty Clause")
    {
        REQUIRE(emit::test::render(clause).empty());
    }

    SECTION("Single Port")
    {
        clause.ports.push_back(makePort("clk", "in", "std_logic"));
        REQUIRE(emit::test::render(clause) == "port ( clk : in std_logic );");
    }

    SECTION("Vertical Layout (Multiple Ports)")
    {
        auto config = emit::test::defaultConfig();
        config.line_config.line_length = 10; // Ensure no grouping

        clause.ports.push_back(makePort("clk", "in", "std_logic"));
        clause.ports.push_back(makePort("rst", "in", "std_logic"));

        constexpr std::string_view EXPECTED = "port (\n"
                                              "  clk : in std_logic;\n"
                                              "  rst : in std_logic\n"
                                              ");";
        REQUIRE(emit::test::render(clause, config) == EXPECTED);
    }

    SECTION("Alignment Logic")
    {
        auto config = emit::test::defaultConfig();
        config.line_config.line_length = 10; // Ensure no grouping
        config.port_map.align_signals = true;

        clause.ports.push_back(makePort("clk", "in", "std_logic"));
        clause.ports.push_back(makePort("data_valid", "out", "std_logic"));

        constexpr std::string_view EXPECTED = "port (\n"
                                              "  clk        : in  std_logic;\n"
                                              "  data_valid : out std_logic\n"
                                              ");";

        REQUIRE(emit::test::render(clause, config) == EXPECTED);
    }

    SECTION("Trivia Preservation in List")
    {
        ast::Port p1 = makePort("clk", "in", "bit");
        p1.addLeading(ast::Break{ 1 });
        p1.addLeading(ast::Comment{ "-- Leading clock" });
        p1.setInlineComment("-- clock");
        p1.addTrailing(ast::Comment{ "-- Trailing clock" });
        p1.addTrailing(ast::Break{ 1 });

        ast::Port p2 = makePort("rst", "in", "bit");
        p2.addLeading(ast::Comment{ "-- Leading reset" });
        p2.setInlineComment("-- reset");
        p2.addTrailing(ast::Comment{ "-- Trailing reset" });
        p2.addTrailing(ast::Break{ 1 });

        clause.ports.push_back(std::move(p1));
        clause.ports.push_back(std::move(p2));

        constexpr std::string_view EXPECTED = "port (\n"
                                              "  \n"
                                              "  -- Leading clock\n"
                                              "  clk : in bit; -- clock\n"
                                              "  -- Trailing clock\n"
                                              "  \n"
                                              "  -- Leading reset\n"
                                              "  rst : in bit -- reset\n"
                                              "  -- Trailing reset\n"
                                              "  \n"
                                              ");";

        REQUIRE(emit::test::render(clause) == EXPECTED);
    }
}