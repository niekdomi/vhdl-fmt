// #include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
// #include <string_view>

TEST_CASE("Interface Packages (VHDL-2008)", "[design_units][interface_package]")
{
    // Note: VHDL-2008 allows 'package' declarations inside the generic clause.
    // This is used for "Generic Packages" or Dependency Injection.
    // Standard VHDL-93/2002 only allows Constants in the generic clause.

    // SECTION("As Generic Parameter")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity MyEntity is\n"
    //         "    generic (package IntPkg is new GenericPkg generic map (<>));\n"
    //         "    port (clk : in std_logic);\n"
    //         "end MyEntity;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check interface package node
    // }

    // SECTION("With Box Notation (<>)")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "library ieee;\n"
    //         "use ieee.std_logic_1164.all;\n"
    //         "entity Processor is\n"
    //         "    -- (<>) means the defaults from the original package are used\n"
    //         "    generic (package MathPkg is new GenericMathPkg generic map (<>));\n"
    //         "    port (data : in std_logic_vector(7 downto 0));\n"
    //         "end Processor;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    // }

    // SECTION("Multiple Interface Packages")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity MultiPkgEntity is\n"
    //         "    generic (\n"
    //         "        package MathPkg is new GenericMathPkg generic map (<>);\n"
    //         "        package IOPkg is new GenericIOPkg generic map (<>)\n"
    //         "    );\n"
    //         "end MultiPkgEntity;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    // }

    // SECTION("Mixed with Regular Generics")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity MixedGenericEntity is\n"
    //         "    generic (\n"
    //         "        WIDTH : integer := 8;\n"
    //         "        package UtilPkg is new GenericUtilPkg generic map (<>);\n"
    //         "        ENABLE_DEBUG : boolean := false\n"
    //         "    );\n"
    //         "end MixedGenericEntity;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    // }
}
