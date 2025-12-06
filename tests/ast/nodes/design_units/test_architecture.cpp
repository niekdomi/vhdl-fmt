#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Architecture: With component declarations", "[design_units][architecture][component]")
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

    auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    auto *comp = std::get_if<ast::ComponentDecl>(arch->decls.data());
    REQUIRE(comp != nullptr);
    REQUIRE(comp->name == "my_comp");
    REQUIRE(comp->generic_clause.generics.size() == 1);
    REQUIRE(comp->port_clause.ports.size() == 1);
}

TEST_CASE("Architecture: Basic architecture without statements", "[design_units][architecture]")
{
    constexpr std::string_view VHDL_FILE = R"(
        architecture RTL of MyEntity is
            signal temp : std_logic;
        begin
            temp <= '1';
        end RTL;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 1);

    const auto *arch = std::get_if<ast::Architecture>(design.units.data());
    REQUIRE(arch != nullptr);
    REQUIRE(arch->name == "RTL");
    REQUIRE(arch->entity_name == "MyEntity");
    REQUIRE_FALSE(arch->decls.empty());
    REQUIRE_FALSE(arch->stmts.empty());
}

TEST_CASE("Architecture: Multiple architectures for same entity", "[design_units][architecture]")
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
    REQUIRE(arch1->name == "RTL");
    REQUIRE(arch1->entity_name == "Counter");

    const auto *arch2 = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch2 != nullptr);
    REQUIRE(arch2->name == "Behavioral");
    REQUIRE(arch2->entity_name == "Counter");
}
