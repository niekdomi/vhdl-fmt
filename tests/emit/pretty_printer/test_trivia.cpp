#include "ast/node.hpp"
#include "ast/nodes/declarations.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Trivia Rendering", "[pretty_printer][trivia]")
{
    SECTION("Standard Nodes (Declarations)")
    {
        ast::GenericParam param{ .names = { "WIDTH" },
                                 .subtype = ast::SubtypeIndication{ .type_mark = "integer" } };

        SECTION("No Trivia")
        {
            REQUIRE(emit::test::render(param) == "WIDTH : integer");
        }

        SECTION("Leading Trivia")
        {
            SECTION("Single Comment")
            {
                param.addLeading(ast::Comment{ "-- lead" });
                // Comment gets hardline() automatically
                REQUIRE(emit::test::render(param) == "-- lead\nWIDTH : integer");
            }

            SECTION("Vertical Whitespace (Breaks preserved)")
            {
                param.addLeading(ast::Break{ .blank_lines = 2 });
                REQUIRE(emit::test::render(param) == "\n\nWIDTH : integer");
            }
        }

        SECTION("Trailing Trivia (Special 'Last Item' Logic)")
        {
            // The renderer adds a Hardline prefix before the trailing block starts.
            // formatLastTrailing reduces Break count by 1 to account for that prefix.

            SECTION("Trailing Comment")
            {
                param.addTrailing(ast::Comment{ "-- trail" });
                // Result: Core + \n + Comment
                REQUIRE(emit::test::render(param) == "WIDTH : integer\n-- trail");
            }

            SECTION("Trailing Break (1 line)")
            {
                // Break{1} -> Prefix(\n) + (1-1 newlines) -> \n
                param.addTrailing(ast::Break{ .blank_lines = 1 });
                REQUIRE(emit::test::render(param) == "WIDTH : integer\n");
            }

            SECTION("Trailing Break (2 lines)")
            {
                // Break{2} -> Prefix(\n) + (2-1 newlines) -> \n\n
                param.addTrailing(ast::Break{ .blank_lines = 2 });
                REQUIRE(emit::test::render(param) == "WIDTH : integer\n\n");
            }
        }

        SECTION("Inline Trivia")
        {
            param.setInlineComment("-- inline");
            // Inline adds: Space + Text + Hardlines(0) (break enforcer)
            REQUIRE(emit::test::render(param) == "WIDTH : integer -- inline");
        }

        SECTION("Inline + Trailing Combination")
        {
            // This tests that the inline comment doesn't eat the newline required
            // for the trailing trivia.
            param.setInlineComment("-- inline");
            param.addTrailing(ast::Comment{ "-- trailing" });

            constexpr std::string_view EXPECTED = "WIDTH : integer -- inline\n"
                                                  "-- trailing";
            REQUIRE(emit::test::render(param) == EXPECTED);
        }
    }

    SECTION("Expression Nodes (Newline Suppression)")
    {
        // TokenExpr satisfies the `IsExpression` concept in PrettyPrinter,
        // so `suppress_newlines` will be passed as true to `withTrivia`.
        ast::TokenExpr expr{ .text = "A" };

        SECTION("Leading Breaks are suppressed")
        {
            // Add a break that would normally render as \n\n
            expr.addLeading(ast::Break{ .blank_lines = 2 });

            // Should be ignored for expressions to keep math tight
            REQUIRE(emit::test::render(expr) == "A");
        }

        SECTION("Leading Comments are KEPT")
        {
            // Comments are never suppressed, as that would delete data
            expr.addLeading(ast::Comment{ "-- note" });
            REQUIRE(emit::test::render(expr) == "-- note\nA");
        }

        SECTION("Trailing Breaks are suppressed")
        {
            expr.addTrailing(ast::Break{ .blank_lines = 1 });
            REQUIRE(emit::test::render(expr) == "A");
        }

        SECTION("Inline Comments still work")
        {
            expr.setInlineComment("-- val");
            REQUIRE(emit::test::render(expr) == "A -- val");
        }
    }
}
