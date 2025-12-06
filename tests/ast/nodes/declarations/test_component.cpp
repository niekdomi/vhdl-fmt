#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

TEST_CASE("ComponentDecl: Simple component without generics or ports", "[declarations][component]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            component simple_comp
            end component;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *comp = std::get_if<ast::ComponentDecl>(&arch->decls[0]);
    REQUIRE(comp != nullptr);
    REQUIRE(comp->name == "simple_comp");
    REQUIRE_FALSE(comp->has_is_keyword);
    REQUIRE(comp->generic_clause.generics.empty());
    REQUIRE(comp->port_clause.ports.empty());
    REQUIRE_FALSE(comp->end_label.has_value());
}

TEST_CASE("ComponentDecl: Component with IS keyword", "[declarations][component]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            component my_comp is
            end component;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *comp = std::get_if<ast::ComponentDecl>(&arch->decls[0]);
    REQUIRE(comp != nullptr);
    REQUIRE(comp->name == "my_comp");
    REQUIRE(comp->has_is_keyword);
}

TEST_CASE("ComponentDecl: Component with end label", "[declarations][component]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            component my_comp
            end component my_comp;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *comp = std::get_if<ast::ComponentDecl>(&arch->decls[0]);
    REQUIRE(comp != nullptr);
    REQUIRE(comp->name == "my_comp");
    REQUIRE(comp->end_label.has_value());
    REQUIRE(*comp->end_label == "my_comp");
}

TEST_CASE("ComponentDecl: Component with generic clause", "[declarations][component]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            component adder
                generic (
                    WIDTH : integer := 8
                );
            end component;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *comp = std::get_if<ast::ComponentDecl>(&arch->decls[0]);
    REQUIRE(comp != nullptr);
    REQUIRE(comp->name == "adder");
    REQUIRE(comp->generic_clause.generics.size() == 1);
    REQUIRE(comp->generic_clause.generics[0].names.size() == 1);
    REQUIRE(comp->generic_clause.generics[0].names[0] == "WIDTH");
    REQUIRE(comp->generic_clause.generics[0].type_name == "integer");
}

TEST_CASE("ComponentDecl: Component with port clause", "[declarations][component]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            component buffer_comp
                port (
                    data_in  : in  bit;
                    data_out : out bit
                );
            end component;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *comp = std::get_if<ast::ComponentDecl>(&arch->decls[0]);
    REQUIRE(comp != nullptr);
    REQUIRE(comp->name == "buffer_comp");
    REQUIRE(comp->port_clause.ports.size() == 2);
    REQUIRE(comp->port_clause.ports[0].names[0] == "data_in");
    REQUIRE(comp->port_clause.ports[1].names[0] == "data_out");
}

TEST_CASE("ComponentDecl: Component with both generic and port clauses",
          "[declarations][component]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            component full_adder is
                generic (
                    WIDTH : integer := 8;
                    DELAY : time := 1 ns
                );
                port (
                    a    : in  bit_vector(WIDTH-1 downto 0);
                    b    : in  bit_vector(WIDTH-1 downto 0);
                    cin  : in  bit;
                    sum  : out bit_vector(WIDTH-1 downto 0);
                    cout : out bit
                );
            end component full_adder;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 1);

    const auto *comp = std::get_if<ast::ComponentDecl>(&arch->decls[0]);
    REQUIRE(comp != nullptr);
    REQUIRE(comp->name == "full_adder");
    REQUIRE(comp->has_is_keyword);
    REQUIRE(comp->end_label.has_value());
    REQUIRE(*comp->end_label == "full_adder");

    // Check generics
    REQUIRE(comp->generic_clause.generics.size() == 2);
    REQUIRE(comp->generic_clause.generics[0].names[0] == "WIDTH");
    REQUIRE(comp->generic_clause.generics[1].names[0] == "DELAY");

    // Check ports
    REQUIRE(comp->port_clause.ports.size() == 5);
    REQUIRE(comp->port_clause.ports[0].names[0] == "a");
    REQUIRE(comp->port_clause.ports[1].names[0] == "b");
    REQUIRE(comp->port_clause.ports[2].names[0] == "cin");
    REQUIRE(comp->port_clause.ports[3].names[0] == "sum");
    REQUIRE(comp->port_clause.ports[4].names[0] == "cout");
}

TEST_CASE("ComponentDecl: Multiple components in architecture", "[declarations][component]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            component comp1
            end component;

            component comp2
            end component;

            component comp3
            end component;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 3);

    const auto *comp1 = std::get_if<ast::ComponentDecl>(&arch->decls[0]);
    REQUIRE(comp1 != nullptr);
    REQUIRE(comp1->name == "comp1");

    const auto *comp2 = std::get_if<ast::ComponentDecl>(&arch->decls[1]);
    REQUIRE(comp2 != nullptr);
    REQUIRE(comp2->name == "comp2");

    const auto *comp3 = std::get_if<ast::ComponentDecl>(&arch->decls[2]);
    REQUIRE(comp3 != nullptr);
    REQUIRE(comp3->name == "comp3");
}

TEST_CASE("ComponentDecl: Order preserved - constant, component, signal",
          "[declarations][component][order]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            constant MAX_VALUE : integer := 100;

            component my_comp
                port (clk : in bit);
            end component;

            signal counter : integer;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 3);

    // First item should be constant
    const auto *decl1 = std::get_if<ast::Declaration>(&arch->decls[0]);
    REQUIRE(decl1 != nullptr);
    const auto *const1 = std::get_if<ast::ConstantDecl>(decl1);
    REQUIRE(const1 != nullptr);
    REQUIRE(const1->names[0] == "MAX_VALUE");

    // Second item should be component
    const auto *comp = std::get_if<ast::ComponentDecl>(&arch->decls[1]);
    REQUIRE(comp != nullptr);
    REQUIRE(comp->name == "my_comp");

    // Third item should be signal
    const auto *decl3 = std::get_if<ast::Declaration>(&arch->decls[2]);
    REQUIRE(decl3 != nullptr);
    const auto *sig = std::get_if<ast::SignalDecl>(decl3);
    REQUIRE(sig != nullptr);
    REQUIRE(sig->names[0] == "counter");
}

TEST_CASE("ComponentDecl: Order preserved - signal, component, constant",
          "[declarations][component][order]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            signal enable : bit;

            component uart
                generic (BAUD_RATE : integer := 9600);
            end component;

            constant TIMEOUT : integer := 50;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 3);

    // First item should be signal
    const auto *decl1 = std::get_if<ast::Declaration>(&arch->decls[0]);
    REQUIRE(decl1 != nullptr);
    const auto *sig = std::get_if<ast::SignalDecl>(decl1);
    REQUIRE(sig != nullptr);
    REQUIRE(sig->names[0] == "enable");

    // Second item should be component
    const auto *comp = std::get_if<ast::ComponentDecl>(&arch->decls[1]);
    REQUIRE(comp != nullptr);
    REQUIRE(comp->name == "uart");

    // Third item should be constant
    const auto *decl3 = std::get_if<ast::Declaration>(&arch->decls[2]);
    REQUIRE(decl3 != nullptr);
    const auto *const3 = std::get_if<ast::ConstantDecl>(decl3);
    REQUIRE(const3 != nullptr);
    REQUIRE(const3->names[0] == "TIMEOUT");
}

TEST_CASE("ComponentDecl: Complex interleaved declarations", "[declarations][component][order]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is end E;
        architecture A of E is
            constant C1 : integer := 1;
            signal S1 : bit;

            component COMP1
                port (a : in bit);
            end component;

            constant C2 : integer := 2;

            component COMP2
                port (b : out bit);
            end component;

            signal S2 : bit;
            constant C3 : integer := 3;
        begin
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    REQUIRE(arch != nullptr);
    REQUIRE(arch->decls.size() == 7);

    // Verify exact order
    auto get_const = [](const ast::DeclarativeItem &item) -> const ast::ConstantDecl * {
        if (auto *decl = std::get_if<ast::Declaration>(&item)) {
            return std::get_if<ast::ConstantDecl>(decl);
        }
        return nullptr;
    };

    auto get_signal = [](const ast::DeclarativeItem &item) -> const ast::SignalDecl * {
        if (auto *decl = std::get_if<ast::Declaration>(&item)) {
            return std::get_if<ast::SignalDecl>(decl);
        }
        return nullptr;
    };

    // C1
    const auto *c1 = get_const(arch->decls[0]);
    REQUIRE(c1 != nullptr);
    REQUIRE(c1->names[0] == "C1");

    // S1
    const auto *s1 = get_signal(arch->decls[1]);
    REQUIRE(s1 != nullptr);
    REQUIRE(s1->names[0] == "S1");

    // COMP1
    const auto *comp1 = std::get_if<ast::ComponentDecl>(&arch->decls[2]);
    REQUIRE(comp1 != nullptr);
    REQUIRE(comp1->name == "COMP1");

    // C2
    const auto *c2 = get_const(arch->decls[3]);
    REQUIRE(c2 != nullptr);
    REQUIRE(c2->names[0] == "C2");

    // COMP2
    const auto *comp2 = std::get_if<ast::ComponentDecl>(&arch->decls[4]);
    REQUIRE(comp2 != nullptr);
    REQUIRE(comp2->name == "COMP2");

    // S2
    const auto *s2 = get_signal(arch->decls[5]);
    REQUIRE(s2 != nullptr);
    REQUIRE(s2->names[0] == "S2");

    // C3
    const auto *c3 = get_const(arch->decls[6]);
    REQUIRE(c3 != nullptr);
    REQUIRE(c3->names[0] == "C3");
}
