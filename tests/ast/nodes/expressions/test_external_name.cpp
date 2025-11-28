// #include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("External Names (VHDL-2008)", "[expressions][external_name]")
{
    // Note: The syntax << class path : type >> is strictly VHDL-2008.
    // It allows referencing items (signals, constants, variables)
    // anywhere in the design hierarchy.

    constexpr std::string_view PRELUDE =
        "library ieee;\n"
        "use ieee.std_logic_1164.all;\n";

    // SECTION("External Signal Reference")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "library ieee;\n"
    //         "use ieee.std_logic_1164.all;\n"
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable val : std_logic;\n"
    //         "    begin\n"
    //         "        -- Syntax: << signal absolute.path : type >>\n"
    //         "        val := <<signal .testbench.dut.internal_signal : std_logic>>;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check external signal reference
    // }

    // SECTION("External Constant Reference")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable val : integer;\n"
    //         "    begin\n"
    //         "        val := <<constant .testbench.dut.max_value : integer>>;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check external constant reference
    // }

    // SECTION("External Variable Reference")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable local_val : integer;\n"
    //         "    begin\n"
    //         "        -- Accessing a variable inside another process/hierarchy\n"
    //         "        local_val := <<variable .testbench.dut.proc_name.shared_var : integer>>;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check external variable reference
    // }

    // SECTION("External Name in Assignment (Force)")
    // {
    //     // VHDL-2008 allows writing to external signals (effectively 'forcing' them)\n"
    //     constexpr std::string_view VHDL_FILE =
    //         "library ieee;\n"
    //         "use ieee.std_logic_1164.all;\n"
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    -- Assigning to an external signal\n"
    //         "    <<signal .testbench.dut.output_signal : std_logic>> <= '1';\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check external name on LHS
    // }
}
