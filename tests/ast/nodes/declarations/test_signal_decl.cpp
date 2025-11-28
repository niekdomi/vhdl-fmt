#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("SignalDecl: Simple signal declaration", "[declarations][signal]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal clk : std_logic;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &signal = std::get<ast::SignalDecl>(arch.decls[0]);
    REQUIRE(signal.names.size() == 1);
    REQUIRE(signal.names[0] == "clk");
    REQUIRE(signal.type_name == "std_logic");
    REQUIRE_FALSE(signal.has_bus_kw);
    REQUIRE_FALSE(signal.init_expr.has_value());
}

TEST_CASE("SignalDecl: Signal with initialization", "[declarations][signal]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal counter : integer := 0;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &signal = std::get<ast::SignalDecl>(arch.decls[0]);
    REQUIRE(signal.names.size() == 1);
    REQUIRE(signal.names[0] == "counter");
    REQUIRE(signal.type_name == "integer");
    REQUIRE(signal.init_expr.has_value());
}

TEST_CASE("SignalDecl: Signal with vector type and constraint", "[declarations][signal]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal data : std_logic_vector(7 downto 0);
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.decls.size() == 1);

    const auto &signal = std::get<ast::SignalDecl>(arch.decls[0]);
    REQUIRE(signal.names.size() == 1);
    REQUIRE(signal.names[0] == "data");
    REQUIRE(signal.type_name == "std_logic_vector");
    REQUIRE(signal.constraint.has_value());
}
