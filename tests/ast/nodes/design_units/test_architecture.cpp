#include "ast/nodes/declarations.hpp"
#include "ast/nodes/declarations/objects.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <variant>

TEST_CASE("Architecture", "[design_units][architecture]")
{
    auto parse_arch = test_helpers::parseDesignUnit<ast::Architecture>;

    SECTION("Header and Footer (Metadata)")
    {
        const auto *arch = parse_arch(R"(
            architecture RTL of MyEntity is
            begin
            end architecture RTL;
        )");
        REQUIRE(arch != nullptr);

        CHECK(arch->name == "RTL");
        CHECK(arch->entity_name == "MyEntity");
        CHECK(arch->has_end_architecture_keyword);
        CHECK(arch->end_label.value_or("") == "RTL");
    }

    SECTION("Declarative Part Container")
    {
        // Verify architecture can hold different types of declarations.
        const auto *arch = parse_arch(R"(
            architecture Mixed of Test is
                constant C : integer := 0;
                signal S : bit;
                component MyComp is end component;
            begin
            end;
        )");
        REQUIRE(arch != nullptr);
        REQUIRE(arch->decls.size() == 3);

        CHECK(std::holds_alternative<ast::ConstantDecl>(arch->decls[0]));
        CHECK(std::holds_alternative<ast::SignalDecl>(arch->decls[1]));
        CHECK(std::holds_alternative<ast::ComponentDecl>(arch->decls[2]));
    }

    SECTION("Statement Part Container")
    {
        // Verify architecture can hold different types of concurrent statements.
        const auto *arch = parse_arch(R"(
            architecture Logic of Test is
            begin
                -- Conditional Assignment
                s <= '1' when en else '0';
                
                -- Process
                process begin wait; end process;
            end;
        )");
        REQUIRE(arch != nullptr);
        REQUIRE(arch->stmts.size() == 2);

        // Check statement 1 (Assignment)
        CHECK(std::holds_alternative<ast::ConditionalConcurrentAssign>(arch->stmts[0].kind));

        // Check statement 2 (Process)
        CHECK(std::holds_alternative<ast::Process>(arch->stmts[1].kind));
    }
}