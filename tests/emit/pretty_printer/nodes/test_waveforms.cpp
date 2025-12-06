#include "ast/node.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "common/config.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace {

// Helper: Creates a signal assignment with a target
auto makeAssign(std::string target) -> ast::SignalAssign
{
    ast::SignalAssign assign{ .target = ast::TokenExpr{ .text = std::move(target) } };
    return assign;
}

// Helper: Creates a waveform element (value + optional after clause)
auto makeElem(std::string value, std::string after) -> ast::Waveform::Element
{
    ast::Waveform::Element elem{ .value = ast::TokenExpr{ .text = std::move(value) },
                                 .after = ast::TokenExpr{ .text = std::move(after) } };
    return elem;
}

} // namespace

TEST_CASE("Waveform Rendering", "[pretty_printer][waveforms]")
{
    auto assign = makeAssign("s");

    SECTION("Time Delays (AFTER)")
    {
        assign.waveform.elements.emplace_back(makeElem("'1'", "5 ns"));

        REQUIRE(emit::test::render(assign) == "s <= '1' after 5 ns;");
    }

    SECTION("Multiple Drivers")
    {
        assign.waveform.elements.emplace_back(makeElem("'1'", "5 ns"));
        assign.waveform.elements.emplace_back(makeElem("'0'", "10 ns"));

        SECTION("Fits on one line (Flat)")
        {
            constexpr std::string_view EXPECTED = "s <= '1' after 5 ns, '0' after 10 ns;";
            REQUIRE(emit::test::render(assign) == EXPECTED);
        }

        SECTION("Forces Break (Hanging Indent)")
        {
            // Set a tiny line length to force the "hang" behavior
            common::Config tight_config = emit::test::defaultConfig();
            tight_config.line_config.line_length = 20;

            constexpr std::string_view EXPECTED = "s <= '1' after 5 ns,\n"
                                                  "     '0' after 10 ns;";

            REQUIRE(emit::test::render(assign, tight_config) == EXPECTED);
        }

        SECTION("With Comments")
        {
            assign.setInlineComment("-- Second value");
            assign.waveform.elements[0].addTrailing(ast::Comment{ .text = "-- First trailing" });
            assign.waveform.elements[0].setInlineComment("-- First value");

            constexpr std::string_view EXPECTED = "s <= '1' after 5 ns, -- First value\n"
                                                  "     -- First trailing\n"
                                                  "     '0' after 10 ns; -- Second value";

            REQUIRE(emit::test::render(assign) == EXPECTED);
        }
    }

    SECTION("UNAFFECTED Keyword")
    {
        assign.waveform.is_unaffected = true;
        REQUIRE(emit::test::render(assign) == "s <= unaffected;");
    }
}
