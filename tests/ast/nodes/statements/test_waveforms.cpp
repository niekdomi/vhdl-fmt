#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

namespace {

// Helper to access the first statement of the first process
// (We use a process + sequential signal assignment to test waveforms easily)
[[nodiscard]]
auto getFirstSignalAssign(const ast::DesignFile &design) -> const ast::SignalAssign *
{
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    if (arch == nullptr || arch->stmts.empty()) {
        return nullptr;
    }

    const auto *proc = std::get_if<ast::Process>(arch->stmts.data());
    if (proc == nullptr || proc->body.empty()) {
        return nullptr;
    }

    return std::get_if<ast::SignalAssign>(proc->body.data());
}

} // namespace

TEST_CASE("Waveform Parsing", "[builder][statements][waveforms]")
{
    SECTION("Time Delays (AFTER)")
    {
        constexpr std::string_view VHDL = R"(
            entity Test is end Test;
            architecture RTL of Test is
                signal s : bit;
            begin
                process begin
                    -- Single value with delay
                    s <= '1' after 5 ns;
                end process;
            end RTL;
        )";

        const auto design = builder::buildFromString(VHDL);
        const auto *assign = getFirstSignalAssign(design);
        REQUIRE(assign != nullptr);

        REQUIRE(assign->waveform.elements.size() == 1);
        const auto &elem = assign->waveform.elements[0];

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
        constexpr std::string_view VHDL = R"(
            entity Test is end Test;
            architecture RTL of Test is
                signal clk : bit;
            begin
                process begin
                    -- Clock generator pattern
                    clk <= '1' after 5 ns, '0' after 10 ns;
                end process;
            end RTL;
        )";

        const auto design = builder::buildFromString(VHDL);
        const auto *assign = getFirstSignalAssign(design);
        REQUIRE(assign != nullptr);

        // Verify we captured BOTH elements
        REQUIRE(assign->waveform.elements.size() == 2);

        // Element 0: '1' after 5 ns
        {
            const auto &el = assign->waveform.elements[0];
            CHECK(std::get<ast::TokenExpr>(el.value).text == "'1'");
            REQUIRE(el.after.has_value());
        }

        // Element 1: '0' after 10 ns
        {
            const auto &el = assign->waveform.elements[1];
            CHECK(std::get<ast::TokenExpr>(el.value).text == "'0'");
            REQUIRE(el.after.has_value());
        }
    }

    SECTION("UNAFFECTED Keyword")
    {
        constexpr std::string_view VHDL = R"(
            entity Test is end Test;
            architecture RTL of Test is
                signal s : bit;
            begin
                -- Concurrent Conditional Assignment with UNAFFECTED
                s <= '1' when en = '1' else unaffected;
            end RTL;
        )";

        const auto design = builder::buildFromString(VHDL);
        const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
        REQUIRE(arch != nullptr);

        const auto *assign = std::get_if<ast::ConditionalConcurrentAssign>(arch->stmts.data());
        REQUIRE(assign != nullptr);
        REQUIRE(assign->waveforms.size() == 2);

        // Waveform 1: '1' when ...
        CHECK_FALSE(assign->waveforms[0].waveform.is_unaffected);
        CHECK(std::get<ast::TokenExpr>(assign->waveforms[0].waveform.elements[0].value).text
              == "'1'");

        // Waveform 2: else unaffected
        CHECK(assign->waveforms[1].waveform.is_unaffected);
        CHECK(assign->waveforms[1].waveform.elements.empty());
    }
}
