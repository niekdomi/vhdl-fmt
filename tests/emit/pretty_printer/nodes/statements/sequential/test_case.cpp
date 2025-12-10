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

TEST_CASE("Case Statement", "[pretty_printer][control_flow][sequential]")
{
    // Helper to create a dummy statement (x <= '0')
    auto make_stmt = []() -> ast::SequentialStatement {
        return ast::SignalAssign{ .target = ast::TokenExpr{ .text = "x" },
                                  .waveform = makeWave(ast::TokenExpr{ .text = "'0'" }) };
    };

    ast::CaseStatement stmt;
    stmt.selector = ast::TokenExpr{ .text = "state" };

    ast::CaseStatement::WhenClause clause;
    clause.choices.emplace_back(ast::TokenExpr{ .text = "IDLE" });
    clause.choices.emplace_back(ast::TokenExpr{ .text = "RESET" });
    clause.body.emplace_back(make_stmt());

    stmt.when_clauses.emplace_back(std::move(clause));

    constexpr std::string_view EXPECTED = "case state is\n"
                                          "  when IDLE | RESET =>\n"
                                          "    x <= '0';\n"
                                          "end case;";

    REQUIRE(emit::test::render(stmt) == EXPECTED);
}
