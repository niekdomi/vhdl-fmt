#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <cstddef>
#include <string_view>
#include <variant>

namespace {

// Helper to safely extract a concurrent statement from the architecture
template<typename T>
[[nodiscard]]
auto getConcurrentStmt(const ast::Architecture *arch, std::size_t index) -> const T *
{
    REQUIRE(index < arch->stmts.size());
    const auto *stmt = std::get_if<T>(&arch->stmts[index]);
    REQUIRE(stmt != nullptr);
    return stmt;
}

} // namespace

TEST_CASE("Selected Assignment Translator", "[builder][selected_assign]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Test is end Test;
        architecture RTL of Test is
            signal selector : integer;
            signal output   : std_logic_vector(3 downto 0);
        begin
            -- [0] Simple Selected Assignment
            with selector select
                output <= "0000" when 0,
                          "1111" when 1,
                          "ZZZZ" when others;

            -- [1] Selected Assignment with Ranges and Multiple Choices
            with selector select
                output <= "0000" when 0 to 3,
                          "1111" when 4 | 5,
                          "ZZZZ" when others;
        end RTL;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);

    // Navigate to Architecture
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);

    // Expect 2 statements
    REQUIRE(arch->stmts.size() == 2);

    SECTION("Simple Selected Assignment")
    {
        const auto *stmt = getConcurrentStmt<ast::SelectedConcurrentAssign>(arch, 0);

        // Check Header
        CHECK(std::get<ast::TokenExpr>(stmt->selector).text == "selector");
        CHECK(std::get<ast::TokenExpr>(stmt->target).text == "output");

        REQUIRE(stmt->selections.size() == 3);

        // 1. "0000" when 0
        const auto &s0 = stmt->selections[0];
        // Check Waveform Value
        REQUIRE(s0.waveform.elements.size() == 1);
        CHECK(std::get<ast::TokenExpr>(s0.waveform.elements[0].value).text == "\"0000\"");
        // Check Choice
        REQUIRE(s0.choices.size() == 1);
        CHECK(std::get<ast::TokenExpr>(s0.choices[0]).text == "0");

        // 2. "1111" when 1
        const auto &s1 = stmt->selections[1];
        CHECK(std::get<ast::TokenExpr>(s1.waveform.elements[0].value).text == "\"1111\"");
        REQUIRE(s1.choices.size() == 1);
        CHECK(std::get<ast::TokenExpr>(s1.choices[0]).text == "1");

        // 3. "ZZZZ" when others
        const auto &s2 = stmt->selections[2];
        CHECK(std::get<ast::TokenExpr>(s2.waveform.elements[0].value).text == "\"ZZZZ\"");
        REQUIRE(s2.choices.size() == 1);
        CHECK(std::get<ast::TokenExpr>(s2.choices[0]).text == "others");
    }

    SECTION("Selected Assignment with Ranges")
    {
        const auto *stmt = getConcurrentStmt<ast::SelectedConcurrentAssign>(arch, 1);

        REQUIRE(stmt->selections.size() == 3);

        // 1. "0000" when 0 to 3
        const auto &s0 = stmt->selections[0];
        CHECK(std::get<ast::TokenExpr>(s0.waveform.elements[0].value).text == "\"0000\"");

        REQUIRE(s0.choices.size() == 1);
        // Ranges like "0 to 3" are parsed as BinaryExpr with op "to"
        const auto *range = std::get_if<ast::BinaryExpr>(s0.choices.data());
        REQUIRE(range != nullptr);
        CHECK(range->op == "to");
        CHECK(std::get<ast::TokenExpr>(*range->left).text == "0");
        CHECK(std::get<ast::TokenExpr>(*range->right).text == "3");

        // 2. "1111" when 4 | 5
        const auto &s1 = stmt->selections[1];
        CHECK(std::get<ast::TokenExpr>(s1.waveform.elements[0].value).text == "\"1111\"");

        // "4 | 5" results in multiple choices in the vector
        REQUIRE(s1.choices.size() == 2);
        CHECK(std::get<ast::TokenExpr>(s1.choices[0]).text == "4");
        CHECK(std::get<ast::TokenExpr>(s1.choices[1]).text == "5");

        // 3. "ZZZZ" when others
        const auto &s2 = stmt->selections[2];
        CHECK(std::get<ast::TokenExpr>(s2.waveform.elements[0].value).text == "\"ZZZZ\"");
        CHECK(std::get<ast::TokenExpr>(s2.choices[0]).text == "others");
    }
}
