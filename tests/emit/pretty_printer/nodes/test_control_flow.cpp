#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
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

TEST_CASE("Control Flow Rendering", "[pretty_printer][control_flow]")
{
    // Helper to create a dummy statement (x <= '0')
    auto make_stmt = []() -> ast::SequentialStatement {
        return ast::SignalAssign{ .target = ast::TokenExpr{ .text = "x" },
                                  .waveform = makeWave(ast::TokenExpr{ .text = "'0'" }) };
    };

    SECTION("If Statement")
    {
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

    SECTION("Case Statement")
    {
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

    SECTION("Null Statement")
    {
        ast::NullStatement stmt;
        constexpr std::string_view EXPECTED = "null;";
        REQUIRE(emit::test::render(stmt) == EXPECTED);
    }
}
