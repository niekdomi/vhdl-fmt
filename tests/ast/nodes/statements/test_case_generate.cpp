// #include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Case Generate (VHDL-2008)", "[statements][case_generate]")
{
    // Note: 'case ... generate' is strictly VHDL-2008.
    // Earlier versions only supported 'if ... generate' and 'for ... generate'.

    // Common libraries
    constexpr std::string_view PRELUDE = "library ieee;\n"
                                         "use ieee.std_logic_1164.all;\n";

    // SECTION("Simple Case Generate")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "library ieee;\n"
    //         "use ieee.std_logic_1164.all;\n"
    //         "entity Test is end Test;\n"
    //         "architecture RTL of Test is\n"
    //         "    constant selector : std_logic_vector(1 downto 0) := \"00\";\n"
    //         "begin\n"
    //         "    gen_case: case selector generate\n"
    //         "        when \"00\" =>\n"
    //         "            -- VHDL-2008 allows local decls, but 'begin' is required if they
    //         exist\n" "            signal sig1 : std_logic;\n" "        begin\n" "            sig1
    //         <= '0';\n" "        when \"01\" =>\n" "            signal sig2 : std_logic;\n" "
    //         begin\n" "            sig2 <= '1';\n" "    end generate;\n" "end RTL;";

    //     // auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Enable when parser supports VHDL-2008 case-generate
    // }

    // SECTION("Case Generate with Others")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "library ieee;\n"
    //         "use ieee.std_logic_1164.all;\n"
    //         "entity Test is end Test;\n"
    //         "architecture RTL of Test is\n"
    //         "    constant selector : std_logic_vector(1 downto 0) := \"11\";\n"
    //         "begin\n"
    //         "    gen_case: case selector generate\n"
    //         "        when \"00\" =>\n"
    //         "            signal sig1 : std_logic;\n"
    //         "        begin\n"
    //         "            sig1 <= '0';\n"
    //         "        when \"01\" =>\n"
    //         "            signal sig2 : std_logic;\n"
    //         "        begin\n"
    //         "            sig2 <= '1';\n"
    //         "        when others =>\n"
    //         "            signal sig3 : std_logic;\n"
    //         "        begin\n"
    //         "            sig3 <= 'Z';\n"
    //         "    end generate;\n"
    //         "end RTL;";

    //     // auto design = builder::buildFromString(VHDL_FILE);
    // }
}
