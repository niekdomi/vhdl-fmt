#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Architecture: Simple empty architecture", "[design_units][architecture]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture Empty of E is
        begin
        end Empty;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.name == "Empty");
    REQUIRE(arch.entity_name == "E");
    REQUIRE(arch.decls.empty());
    REQUIRE(arch.stmts.empty());
}

TEST_CASE("Architecture: Architecture with declarations", "[design_units][architecture]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture RTL of E is
            constant WIDTH : integer := 8;
            signal temp : std_logic;
        begin
        end RTL;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.name == "RTL");
    REQUIRE(arch.entity_name == "E");
    REQUIRE(arch.decls.size() == 2);
    REQUIRE(arch.stmts.empty());
}

TEST_CASE("Architecture: Architecture with concurrent statements", "[design_units][architecture]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a, b : in std_logic; y : out std_logic);
        end E;
        architecture Behavioral of E is
        begin
            y <= a and b;

            process(a, b)
            begin
                y <= a or b;
            end process;
        end Behavioral;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.name == "Behavioral");
    REQUIRE(arch.entity_name == "E");
    REQUIRE(arch.stmts.size() == 2);
}
