#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("Statement: Waveforms", "[builder][statements][waveforms]")
{
    SECTION("Time Delays (AFTER)")
    {
        const auto *stmt
          = test_helpers::parseSequentialStmt<ast::SignalAssign>("s <= '1' after 5 ns;");
        REQUIRE(stmt != nullptr);

        REQUIRE(stmt->waveform.elements.size() == 1);
        const auto &elem = stmt->waveform.elements[0];

        // Check Value ('1')
        CHECK(std::get<ast::TokenExpr>(elem.value).text == "'1'");

        // Check Delay (5 ns)
        REQUIRE(elem.after.has_value());
        const auto *phys = std::get_if<ast::PhysicalLiteral>(&*elem.after);
        REQUIRE(phys != nullptr);
        CHECK(phys->value == "5");
        CHECK(phys->unit == "ns");
    }

    SECTION("Multiple Drivers (Comma Separated)")
    {
        const auto *stmt = test_helpers::parseSequentialStmt<ast::SignalAssign>(
          "clk <= '1' after 5 ns, '0' after 10 ns;");
        REQUIRE(stmt != nullptr);

        REQUIRE(stmt->waveform.elements.size() == 2);

        // Element 0: '1' after 5 ns
        {
            const auto &el = stmt->waveform.elements[0];
            CHECK(std::get<ast::TokenExpr>(el.value).text == "'1'");
            REQUIRE(el.after.has_value());
        }

        // Element 1: '0' after 10 ns
        {
            const auto &el = stmt->waveform.elements[1];
            CHECK(std::get<ast::TokenExpr>(el.value).text == "'0'");
            REQUIRE(el.after.has_value());
        }
    }

    SECTION("UNAFFECTED Keyword")
    {
        // UNAFFECTED is typically used in conditional assignments (concurrent)
        const auto *stmt = test_helpers::parseConcurrentStmt<ast::ConditionalConcurrentAssign>(
          "s <= '1' when en = '1' else unaffected;");
        REQUIRE(stmt != nullptr);
        REQUIRE(stmt->waveforms.size() == 2);

        // Waveform 1: '1' when ...
        CHECK_FALSE(stmt->waveforms[0].waveform.is_unaffected);
        CHECK(std::get<ast::TokenExpr>(stmt->waveforms[0].waveform.elements[0].value).text
              == "'1'");

        // Waveform 2: else unaffected
        CHECK(stmt->waveforms[1].waveform.is_unaffected);
        CHECK(stmt->waveforms[1].waveform.elements.empty());
    }

    SECTION("Inline Comments Attach to Element (Not Child Expressions)")
    {
        // We assume the code is inside a process
        constexpr std::string_view CODE = "process begin "
                                          "  s <= '1' after 5 ns, -- first element\n"
                                          "       '0' after 10 ns; -- second element\n"
                                          "end process;";

        const auto *proc = test_helpers::parseConcurrentStmt<ast::Process>(CODE);
        REQUIRE(proc != nullptr);
        REQUIRE(proc->body.size() == 1);

        // Get the Wrapper (SequentialStatement)
        const auto &stmt_wrapper = proc->body[0];

        // Get the Inner Node (SignalAssign)
        REQUIRE(std::holds_alternative<ast::SignalAssign>(stmt_wrapper.kind));
        const auto &assign = std::get<ast::SignalAssign>(stmt_wrapper.kind);

        REQUIRE(assign.waveform.elements.size() == 2);

        // Element 0: Has inline comment "-- first element"
        const auto &el0 = assign.waveform.elements[0];
        REQUIRE(el0.hasTrivia());
        REQUIRE(el0.getInlineComment().has_value());
        CHECK(el0.getInlineComment().value() == "-- first element");

        // Element 1: No trivia (comment is after the semicolon, so it belongs to the statement)
        const auto &el1 = assign.waveform.elements[1];
        CHECK_FALSE(el1.hasTrivia());

        // Statement Wrapper: Has inline comment "-- second element"
        // The wrapper owns the semicolon and the trailing comment.
        REQUIRE(stmt_wrapper.hasTrivia());
        REQUIRE(stmt_wrapper.getInlineComment().has_value());
        CHECK(stmt_wrapper.getInlineComment().value() == "-- second element");
    }
}
