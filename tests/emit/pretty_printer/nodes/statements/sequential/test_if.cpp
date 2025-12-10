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

TEST_CASE("If Statement", "[pretty_printer][control_flow][sequential]")
{
    // Helper to create a dummy statement (x <= '0')
    auto make_stmt = []() -> ast::SequentialStatement {
        return ast::SignalAssign{ .target = ast::TokenExpr{ .text = "x" },
                                  .waveform = makeWave(ast::TokenExpr{ .text = "'0'" }) };
    };

    ast::IfStatement stmt;

    // 1. IF
    stmt.if_branch.condition = ast::TokenExpr{ .text = "rst" };
    stmt.if_branch.body.emplace_back(make_stmt());

    // 2. ELSIF
    ast::IfStatement::Branch elsif;
    elsif.condition = ast::TokenExpr{ .text = "en" };
    elsif.body.emplace_back(make_stmt());
    stmt.elsif_branches.emplace_back(std::move(elsif));

    // 3. ELSE
    ast::IfStatement::Branch else_br;
    else_br.body.emplace_back(make_stmt());
    stmt.else_branch = std::move(else_br);

    constexpr std::string_view EXPECTED = "if rst then\n"
                                          "  x <= '0';\n"
                                          "elsif en then\n"
                                          "  x <= '0';\n"
                                          "else\n"
                                          "  x <= '0';\n"
                                          "end if;";

    REQUIRE(emit::test::render(stmt) == EXPECTED);
}
