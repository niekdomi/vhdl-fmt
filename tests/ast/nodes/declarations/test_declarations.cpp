#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("Multiple declaration types in architecture", "[declarations][mixed]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal clk : std_logic;
            constant MAX : integer := 100;
            signal data : std_logic_vector(7 downto 0);
            constant MIN : integer := 0;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 4);

    REQUIRE(std::holds_alternative<ast::SignalDecl>(arch->decls[0]));
    REQUIRE(std::holds_alternative<ast::ConstantDecl>(arch->decls[1]));
    REQUIRE(std::holds_alternative<ast::SignalDecl>(arch->decls[2]));
    REQUIRE(std::holds_alternative<ast::ConstantDecl>(arch->decls[3]));

    const auto *sig1 = std::get_if<ast::SignalDecl>(arch->decls.data());
    REQUIRE(sig1->names[0] == "clk");

    const auto *const1 = std::get_if<ast::ConstantDecl>(&arch->decls[1]);
    REQUIRE(const1->names[0] == "MAX");

    const auto *sig2 = std::get_if<ast::SignalDecl>(&arch->decls[2]);
    REQUIRE(sig2->names[0] == "data");

    const auto *const2 = std::get_if<ast::ConstantDecl>(&arch->decls[3]);
    REQUIRE(const2->names[0] == "MIN");
}

TEST_CASE("Architecture with no declarations", "[declarations][empty]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.empty());
}
