#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "ast/nodes/statements/waveform.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <utility>

namespace {

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
    auto make_stmt = []() -> ast::SequentialStatement {
        return ast::SequentialStatement{
            .kind = ast::SignalAssign{ .target = ast::TokenExpr{ .text = "x" },
                                      .waveform = makeWave(ast::TokenExpr{ .text = "'0'" }) }
        };
    };

    ast::IfStatement stmt;

    ast::IfStatement::ConditionalBranch if_branch{};
    if_branch.condition = ast::TokenExpr{ .text = "rst" };
    if_branch.body.emplace_back(make_stmt());
    stmt.branches.emplace_back(std::move(if_branch));

    ast::IfStatement::ConditionalBranch elsif_branch{};
    elsif_branch.condition = ast::TokenExpr{ .text = "en" };
    elsif_branch.body.emplace_back(make_stmt());
    stmt.branches.emplace_back(std::move(elsif_branch));

    ast::IfStatement::ElseBranch else_br{};
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
