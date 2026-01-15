#include "ast/node.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"
#include "nodes/declarations/interface.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string>
#include <string_view>
#include <utility>

namespace {

auto makePort(std::string name, std::string mode, std::string type) -> ast::Port
{
    return ast::Port{.names = {std::move(name)},
                     .mode = std::move(mode),
                     .subtype = ast::SubtypeIndication{.type_mark = std::move(type)}};
}

} // namespace

TEST_CASE("Trivia Rendering", "[pretty_printer][trivia]")
{
    SECTION("Standard Nodes (Declarations)")
    {
        ast::GenericParam param{.names = {"WIDTH"},
                                .subtype = ast::SubtypeIndication{.type_mark = "integer"}};

        SECTION("Leading Trivia")
        {
            param.addLeading(ast::Comment{"-- lead"});
            REQUIRE(emit::test::render(param) == "-- lead\nWIDTH : integer");
        }

        SECTION("Leading Whitespace (Normalize)")
        {
            param.addLeading(ast::Break{.blank_lines = 2});
            REQUIRE(emit::test::render(param) == "\nWIDTH : integer");
        }

        SECTION("Trailing Trivia (Last Item Logic)")
        {
            SECTION("Trailing Comment")
            {
                param.addTrailing(ast::Comment{"-- trail"});
                REQUIRE(emit::test::render(param) == "WIDTH : integer\n-- trail");
            }

            SECTION("Trailing Break (Normalize)")
            {
                // Last break becomes empty to allow list separators to handle the newline
                param.addTrailing(ast::Break{.blank_lines = 2});
                REQUIRE(emit::test::render(param) == "WIDTH : integer\n");
            }
        }

        SECTION("Inline Trivia")
        {
            param.setInlineComment("-- inline");
            REQUIRE(emit::test::render(param) == "WIDTH : integer -- inline");
        }

        SECTION("Inline + Trailing Combination")
        {
            param.setInlineComment("-- inline");
            param.addTrailing(ast::Comment{"-- trailing"});

            const std::string_view expected = "WIDTH : integer -- inline\n" "-- trailing";
            REQUIRE(emit::test::render(param) == expected);
        }

        SECTION("Inline + Trailing Break")
        {
            // Verify no double newline generation
            param.setInlineComment("-- inline");
            param.addTrailing(ast::Break{});
            REQUIRE(emit::test::render(param) == "WIDTH : integer -- inline\n");
        }
    }

    SECTION("Complex Scenarios")
    {
        SECTION("List Separator Interaction")
        {
            // Verify that a trailing Break doesn't double-up with the list separator
            ast::PortClause clause{};

            ast::Port p1 = makePort("clk", "in", "bit");
            p1.addTrailing(ast::Break{1}); // User blank line

            ast::Port p2 = makePort("rst", "in", "bit");

            clause.ports.push_back(std::move(p1));
            clause.ports.push_back(std::move(p2));

            const std::string_view expected =
              "port (\n" "  clk : in bit;\n" // Separator provided by Break normalization
              "  \n" "  rst : in bit\n" ");";

            REQUIRE(emit::test::render(clause) == expected);
        }

        SECTION("Interleaved Trivia")
        {
            // Test [Comment] -> [Break] -> [Comment] -> [Break(Last)]
            ast::GenericParam param{.names = {"WIDTH"},
                                    .subtype = ast::SubtypeIndication{.type_mark = "integer"}};

            param.addTrailing(ast::Comment{"-- Step 1"});
            param.addTrailing(ast::Break{});
            param.addTrailing(ast::Comment{"-- Step 2"});
            param.addTrailing(ast::Break{});

            const std::string_view expected = "WIDTH : integer\n" "-- Step 1\n" "\n" "-- Step 2\n";

            REQUIRE(emit::test::render(param) == expected);
        }
    }

    SECTION("Expression Nodes (Newline Suppression)")
    {
        ast::TokenExpr expr{.text = "A"};

        SECTION("Leading Breaks Suppressed")
        {
            expr.addLeading(ast::Break{.blank_lines = 2});
            REQUIRE(emit::test::render(expr) == "A");
        }

        SECTION("Leading Comments Preserved")
        {
            expr.addLeading(ast::Comment{"-- note"});
            REQUIRE(emit::test::render(expr) == "-- note\nA");
        }

        SECTION("Trailing Breaks Suppressed")
        {
            expr.addTrailing(ast::Break{.blank_lines = 1});
            REQUIRE(emit::test::render(expr) == "A");
        }
    }
}
