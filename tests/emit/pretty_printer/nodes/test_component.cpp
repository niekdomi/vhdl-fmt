#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_units.hpp"
#include "emit/test_utils.hpp"
#include "nodes/expressions.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string>
#include <string_view>
#include <utility>

TEST_CASE("ComponentDecl: Simple component without generics or ports",
          "[pretty_printer][component]")
{
    ast::ComponentDecl comp;
    comp.name = "simple_comp";
    comp.has_is_keyword = false;

    const std::string result = emit::test::render(comp);
    constexpr std::string_view EXPECTED = "component simple_comp\n"
                                          "end component;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("ComponentDecl: Component with IS keyword", "[pretty_printer][component]")
{
    ast::ComponentDecl comp;
    comp.name = "my_comp";
    comp.has_is_keyword = true;

    const std::string result = emit::test::render(comp);
    constexpr std::string_view EXPECTED = "component my_comp is\n"
                                          "end component;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("ComponentDecl: Component with end label", "[pretty_printer][component]")
{
    ast::ComponentDecl comp;
    comp.name = "my_comp";
    comp.has_is_keyword = false;
    comp.end_label = "my_comp";

    const std::string result = emit::test::render(comp);
    constexpr std::string_view EXPECTED = "component my_comp\n"
                                          "end component my_comp;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("ComponentDecl: Component with generic clause", "[pretty_printer][component]")
{
    ast::ComponentDecl comp;
    comp.name = "adder";
    comp.has_is_keyword = false;

    ast::GenericParam gen;
    gen.names = { "WIDTH" };
    gen.type_name = "integer";
    gen.default_expr = ast::TokenExpr{ .text = "8" };
    comp.generic_clause.generics.push_back(std::move(gen));

    const std::string result = emit::test::render(comp);
    constexpr std::string_view EXPECTED = "component adder\n"
                                          "  generic ( WIDTH : integer := 8 );\n"
                                          "end component;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("ComponentDecl: Component with port clause", "[pretty_printer][component]")
{
    ast::ComponentDecl comp;
    comp.name = "buffer_comp";
    comp.has_is_keyword = false;

    ast::Port port1;
    port1.names = { "data_in" };
    port1.mode = "in";
    port1.type_name = "bit";
    comp.port_clause.ports.push_back(std::move(port1));

    ast::Port port2;
    port2.names = { "data_out" };
    port2.mode = "out";
    port2.type_name = "bit";
    comp.port_clause.ports.push_back(std::move(port2));

    const std::string result = emit::test::render(comp);
    constexpr std::string_view EXPECTED = "component buffer_comp\n"
                                          "  port ( data_in : in bit; data_out : out bit );\n"
                                          "end component;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("ComponentDecl: Component with both generic and port clauses",
          "[pretty_printer][component]")
{
    ast::ComponentDecl comp;
    comp.name = "full_adder";
    comp.has_is_keyword = true;
    comp.end_label = "full_adder";

    ast::GenericParam gen;
    gen.names = { "WIDTH" };
    gen.type_name = "integer";
    gen.default_expr = ast::TokenExpr{ .text = "8" };
    comp.generic_clause.generics.push_back(std::move(gen));

    ast::Port port1;
    port1.names = { "a" };
    port1.mode = "in";
    port1.type_name = "bit";
    comp.port_clause.ports.push_back(std::move(port1));

    ast::Port port2;
    port2.names = { "b" };
    port2.mode = "in";
    port2.type_name = "bit";
    comp.port_clause.ports.push_back(std::move(port2));

    ast::Port port3;
    port3.names = { "sum" };
    port3.mode = "out";
    port3.type_name = "bit";
    comp.port_clause.ports.push_back(std::move(port3));

    const std::string result = emit::test::render(comp);
    constexpr std::string_view EXPECTED = "component full_adder is\n"
                                          "  generic ( WIDTH : integer := 8 );\n"
                                          "  port ( a : in bit; b : in bit; sum : out bit );\n"
                                          "end component full_adder;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("Architecture: Order preserved - constant, component, signal",
          "[pretty_printer][component][order]")
{
    ast::Architecture arch;
    arch.name = "rtl";
    arch.entity_name = "test_entity";

    // Add constant
    ast::ConstantDecl const_decl;
    const_decl.names = { "MAX_VALUE" };
    const_decl.type_name = "integer";
    const_decl.init_expr = ast::TokenExpr{ .text = "100" };
    arch.decls.emplace_back(ast::Declaration(std::move(const_decl)));

    // Add component
    ast::ComponentDecl comp;
    comp.name = "my_comp";
    comp.has_is_keyword = false;
    arch.decls.emplace_back(std::move(comp));

    // Add signal
    ast::SignalDecl sig_decl;
    sig_decl.names = { "counter" };
    sig_decl.type_name = "integer";
    arch.decls.emplace_back(ast::Declaration(std::move(sig_decl)));

    const std::string result = emit::test::render(arch);
    constexpr std::string_view EXPECTED = "architecture rtl of test_entity is\n"
                                          "  constant MAX_VALUE : integer := 100;\n"
                                          "  component my_comp\n"
                                          "  end component;\n"
                                          "  signal counter : integer;\n"
                                          "begin\n"
                                          "end;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("Architecture: Order preserved - signal, component, constant",
          "[pretty_printer][component][order]")
{
    ast::Architecture arch;
    arch.name = "rtl";
    arch.entity_name = "test_entity";

    // Add signal
    ast::SignalDecl sig_decl;
    sig_decl.names = { "enable" };
    sig_decl.type_name = "bit";
    arch.decls.emplace_back(ast::Declaration(std::move(sig_decl)));

    // Add component
    ast::ComponentDecl comp;
    comp.name = "uart";
    comp.has_is_keyword = false;
    arch.decls.emplace_back(std::move(comp));

    // Add constant
    ast::ConstantDecl const_decl;
    const_decl.names = { "TIMEOUT" };
    const_decl.type_name = "integer";
    const_decl.init_expr = ast::TokenExpr{ .text = "50" };
    arch.decls.emplace_back(ast::Declaration(std::move(const_decl)));

    const std::string result = emit::test::render(arch);
    constexpr std::string_view EXPECTED = "architecture rtl of test_entity is\n"
                                          "  signal enable : bit;\n"
                                          "  component uart\n"
                                          "  end component;\n"
                                          "  constant TIMEOUT : integer := 50;\n"
                                          "begin\n"
                                          "end;";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("Architecture: Complex interleaved declarations", "[pretty_printer][component][order]")
{
    ast::Architecture arch;
    arch.name = "rtl";
    arch.entity_name = "test_entity";

    // C1
    ast::ConstantDecl c1;
    c1.names = { "C1" };
    c1.type_name = "integer";
    c1.init_expr = ast::TokenExpr{ .text = "1" };
    arch.decls.emplace_back(ast::Declaration(std::move(c1)));

    // S1
    ast::SignalDecl s1;
    s1.names = { "S1" };
    s1.type_name = "bit";
    arch.decls.emplace_back(ast::Declaration(std::move(s1)));

    // COMP1
    ast::ComponentDecl comp1;
    comp1.name = "COMP1";
    arch.decls.emplace_back(std::move(comp1));

    // C2
    ast::ConstantDecl c2;
    c2.names = { "C2" };
    c2.type_name = "integer";
    c2.init_expr = ast::TokenExpr{ .text = "2" };
    arch.decls.emplace_back(ast::Declaration(std::move(c2)));

    // COMP2
    ast::ComponentDecl comp2;
    comp2.name = "COMP2";
    arch.decls.emplace_back(std::move(comp2));

    // S2
    ast::SignalDecl s2;
    s2.names = { "S2" };
    s2.type_name = "bit";
    arch.decls.emplace_back(ast::Declaration(std::move(s2)));

    // C3
    ast::ConstantDecl c3;
    c3.names = { "C3" };
    c3.type_name = "integer";
    c3.init_expr = ast::TokenExpr{ .text = "3" };
    arch.decls.emplace_back(ast::Declaration(std::move(c3)));

    const std::string result = emit::test::render(arch);

    // Verify exact order by checking positions
    const auto c1_pos = result.find("constant C1");
    const auto s1_pos = result.find("signal S1");
    const auto comp1_pos = result.find("component COMP1");
    const auto c2_pos = result.find("constant C2");
    const auto comp2_pos = result.find("component COMP2");
    const auto s2_pos = result.find("signal S2");
    const auto c3_pos = result.find("constant C3");

    REQUIRE(c1_pos != std::string::npos);
    REQUIRE(s1_pos != std::string::npos);
    REQUIRE(comp1_pos != std::string::npos);
    REQUIRE(c2_pos != std::string::npos);
    REQUIRE(comp2_pos != std::string::npos);
    REQUIRE(s2_pos != std::string::npos);
    REQUIRE(c3_pos != std::string::npos);

    REQUIRE(c1_pos < s1_pos);
    REQUIRE(s1_pos < comp1_pos);
    REQUIRE(comp1_pos < c2_pos);
    REQUIRE(c2_pos < comp2_pos);
    REQUIRE(comp2_pos < s2_pos);
    REQUIRE(s2_pos < c3_pos);
}
