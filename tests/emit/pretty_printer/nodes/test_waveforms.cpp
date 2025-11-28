#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <optional>
#include <string_view>
#include <vector>

namespace {

auto token(std::string_view text) -> ast::TokenExpr
{
    return ast::TokenExpr{ .text = std::string(text) };
}

} // namespace

TEST_CASE("Waveform Rendering", "[pretty_printer][waveforms]")
{
    ast::SignalAssign assign;
    assign.target = token("s");

    SECTION("Time Delays (AFTER)")
    {
        // s <= '1' after 5 ns;
        ast::Waveform::Element elem;
        elem.value = token("'1'");
        elem.after = token("5 ns");
        assign.waveform.elements.push_back(std::move(elem));

        REQUIRE(emit::test::render(assign) == "s <= '1' after 5 ns;");
    }

    SECTION("Multiple Drivers")
    {
        // Driver 1
        ast::Waveform::Element el1;
        el1.value = token("'1'");
        el1.after = token("5 ns");
        assign.waveform.elements.push_back(std::move(el1));

        // Driver 2
        ast::Waveform::Element el2;
        el2.value = token("'0'");
        el2.after = token("10 ns");
        assign.waveform.elements.push_back(std::move(el2));

        SECTION("Fits on one line (Flat)")
        {
            // Default width is 80, this string is ~35 chars, so it stays flat.
            constexpr std::string_view EXPECTED = "s <= '1' after 5 ns, '0' after 10 ns;";
            REQUIRE(emit::test::render(assign) == EXPECTED);
        }

        SECTION("Forces Break (Hanging Indent)")
        {
            // Set a tiny line length to force the "hang" behavior
            common::Config tight_config = emit::test::defaultConfig();
            tight_config.line_config.line_length = 20;

            // Expected behavior:
            // s <=
            //   '1' after 5 ns,
            //   '0' after 10 ns;
            constexpr std::string_view EXPECTED = "s <=\n"
                                                  "  '1' after 5 ns,\n"
                                                  "  '0' after 10 ns;";

            REQUIRE(emit::test::render(assign, tight_config) == EXPECTED);
        }
    }

    SECTION("UNAFFECTED Keyword")
    {
        assign.waveform.is_unaffected = true;
        REQUIRE(emit::test::render(assign) == "s <= unaffected;");
    }
}
