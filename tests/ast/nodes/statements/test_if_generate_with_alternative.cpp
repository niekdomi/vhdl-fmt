// #include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("If-Generate with Alternatives (VHDL-2008)", "[statements][if_generate]")
{
    // Note: 'else generate' and 'elsif generate' are strictly VHDL-2008 features.
    // In VHDL-93, you had to use disjoint 'if' statements.

    constexpr std::string_view PRELUDE = "library ieee;\n"
                                         "use ieee.std_logic_1164.all;\n";

    // SECTION("If-Else Generate")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "library ieee;\n"
    //         "use ieee.std_logic_1164.all;\n"
    //         "entity Test is end Test;\n"
    //         "architecture RTL of Test is\n"
    //         "    constant condition : boolean := true;\n"
    //         "begin\n"
    //         "    gen_if: if condition generate\n"
    //         "        signal sig1 : std_logic;\n"
    //         "    begin  -- Mandatory BEGIN because sig1 was declared\n"
    //         "        sig1 <= '1';\n"
    //         "    else generate\n"
    //         "        signal sig2 : std_logic;\n"
    //         "    begin  -- Mandatory BEGIN because sig2 was declared\n"
    //         "        sig2 <= '0';\n"
    //         "    end generate;\n"
    //         "end RTL;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check if generate with else
    // }

    // SECTION("If-Elsif-Else Generate")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "library ieee;\n"
    //         "use ieee.std_logic_1164.all;\n"
    //         "entity Test is end Test;\n"
    //         "architecture RTL of Test is\n"
    //         "    constant cond1 : boolean := false;\n"
    //         "    constant cond2 : boolean := true;\n"
    //         "begin\n"
    //         "    gen_if: if cond1 generate\n"
    //         "        signal sig1 : std_logic;\n"
    //         "    begin\n"
    //         "        sig1 <= '1';\n"
    //         "    elsif cond2 generate\n"
    //         "        signal sig2 : std_logic;\n"
    //         "    begin\n"
    //         "        sig2 <= '1';\n"
    //         "    else generate\n"
    //         "        signal sig3 : std_logic;\n"
    //         "    begin\n"
    //         "        sig3 <= '0';\n"
    //         "    end generate;\n"
    //         "end RTL;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check if-elsif-else structure
    // }
}
