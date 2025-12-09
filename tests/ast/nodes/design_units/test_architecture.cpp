#include "ast/nodes/declarations.hpp"
#include "ast/nodes/declarations/objects.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "builder/ast_builder.hpp"
#include "test_helpers.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Architecture", "[design_units][architecture]")
{
    // Case 1: Architecture with component (Full file with Entity)
    SECTION("With component declarations")
    {
        constexpr std::string_view VHDL_FILE = R"(
            entity test_ent is
            end test_ent;

            architecture rtl of test_ent is
                component my_comp
                    generic (WIDTH : integer := 8);
                    port (clk : in std_logic);
                end component;
            begin
            end architecture rtl;
        )";

        auto design = builder::buildFromString(VHDL_FILE);
        REQUIRE(design.units.size() == 2);

        const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
        REQUIRE(arch != nullptr);
        CHECK(arch->name == "rtl");

        REQUIRE(arch->decls.size() == 1);
        const auto *comp = std::get_if<ast::ComponentDecl>(arch->decls.data());
        REQUIRE(comp != nullptr);
        CHECK(comp->name == "my_comp");

        // Verify Component Generics/Ports
        REQUIRE(comp->generic_clause.generics.size() == 1);
        CHECK(comp->generic_clause.generics[0].names[0] == "WIDTH");

        REQUIRE(comp->port_clause.ports.size() == 1);
        CHECK(comp->port_clause.ports[0].names[0] == "clk");
        CHECK(comp->port_clause.ports[0].mode == "in");
    }

    // Case 2: Basic architecture (Standalone unit)
    SECTION("Basic architecture without statements")
    {
        const auto *arch = test_helpers::parseDesignUnit<ast::Architecture>(R"(
            architecture RTL of MyEntity is
                signal temp : std_logic;
            begin
                temp <= '1';
            end RTL;
        )");
        REQUIRE(arch != nullptr);
        CHECK(arch->name == "RTL");
        CHECK(arch->entity_name == "MyEntity");

        // Verify Declaration
        REQUIRE(arch->decls.size() == 1);
        const auto *sig = std::get_if<ast::SignalDecl>(arch->decls.data());
        REQUIRE(sig != nullptr);
        CHECK(sig->names[0] == "temp");
        CHECK(sig->subtype.type_mark == "std_logic");

        // Verify Statement
        REQUIRE(arch->stmts.size() == 1);
        const auto *assign = std::get_if<ast::ConditionalConcurrentAssign>(arch->stmts.data());
        REQUIRE(assign != nullptr);
        CHECK(std::get<ast::TokenExpr>(assign->target).text == "temp");
    }

    // Case 3: Multiple architectures (Manual build)
    SECTION("Multiple architectures for same entity")
    {
        constexpr std::string_view VHDL_FILE = R"(
            architecture RTL of Counter is
            begin
            end RTL;

            architecture Behavioral of Counter is
            begin
            end Behavioral;
        )";

        const auto design = builder::buildFromString(VHDL_FILE);
        REQUIRE(design.units.size() == 2);

        const auto *arch1 = std::get_if<ast::Architecture>(design.units.data());
        REQUIRE(arch1 != nullptr);
        CHECK(arch1->name == "RTL");

        const auto *arch2 = std::get_if<ast::Architecture>(&design.units[1]);
        REQUIRE(arch2 != nullptr);
        CHECK(arch2->name == "Behavioral");
        CHECK(arch2->entity_name == "Counter");
    }
}
