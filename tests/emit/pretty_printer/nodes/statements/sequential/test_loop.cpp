#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "ast/nodes/statements/waveform.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <utility>

namespace {

// Helper to wrap a simple value into a Waveform
auto makeWave(ast::TokenExpr val) -> ast::Waveform
{
    ast::Waveform w;
    ast::Waveform::Element el;
    el.value = std::move(val);
    w.elements.emplace_back(std::move(el));
    return w;
}

} // namespace

TEST_CASE("Loop Statements", "[pretty_printer][control_flow][sequential]")
{
    // Helper to create a dummy statement (x <= '0')
    auto make_stmt = []() -> ast::SequentialStatement {
        return ast::SignalAssign{ .target = ast::TokenExpr{ .text = "x" },
                                  .waveform = makeWave(ast::TokenExpr{ .text = "'0'" }) };
    };

    SECTION("For Loop")
    {
        ast::ForLoop stmt;
        stmt.iterator = "i";
        stmt.range = ast::TokenExpr{ .text = "0 to 7" };
        stmt.body.emplace_back(make_stmt());

        constexpr std::string_view EXPECTED = "for i in 0 to 7 loop\n"
                                              "  x <= '0';\n"
                                              "end loop;";

        REQUIRE(emit::test::render(stmt) == EXPECTED);
    }

    SECTION("While Loop")
    {
        ast::WhileLoop stmt;
        stmt.condition = ast::TokenExpr{ .text = "valid" };
        stmt.body.emplace_back(make_stmt());

        constexpr std::string_view EXPECTED = "while valid loop\n"
                                              "  x <= '0';\n"
                                              "end loop;";

        REQUIRE(emit::test::render(stmt) == EXPECTED);
    }

    SECTION("Basic Loop")
    {
        ast::Loop stmt;
        stmt.body.emplace_back(make_stmt());

        constexpr std::string_view EXPECTED = "loop\n"
                                              "  x <= '0';\n"
                                              "end loop;";

        REQUIRE(emit::test::render(stmt) == EXPECTED);
    }

    SECTION("Labeled Loop")
    {
        ast::Loop stmt;
        stmt.label = "main_loop";
        stmt.body.emplace_back(make_stmt());

        constexpr std::string_view EXPECTED = "main_loop: loop\n"
                                              "  x <= '0';\n"
                                              "end loop;";

        REQUIRE(emit::test::render(stmt) == EXPECTED);
    }
}
