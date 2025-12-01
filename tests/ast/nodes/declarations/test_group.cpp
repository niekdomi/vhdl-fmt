#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Group Declarations", "[declarations][group]")
{
    // Common prelude
    constexpr std::string_view PRELUDE = "library ieee;\n"
                                         "use ieee.std_logic_1164.all;\n";

    SECTION("Group Declaration (Requires a Template)")
    {
        constexpr std::string_view VHDL_FILE
          = "library ieee;\n"
            "use ieee.std_logic_1164.all;\n"
            "entity E is end E;\n"
            "architecture A of E is\n"
            "    -- 1. Define signals to be grouped\n"
            "    signal clk, rst : std_logic;\n"
            "\n"
            "    -- 2. Define the Group Template (a group of signals)\n"
            "    group signal_list is (signal <>);\n"
            "\n"
            "    -- 3. Declare the Group using the Template\n"
            "    group MyGroup : signal_list (clk, rst);\n"
            "begin\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check group declaration node
    }

    SECTION("Group with Multiple Signals")
    {
        constexpr std::string_view VHDL_FILE
          = "library ieee;\n"
            "use ieee.std_logic_1164.all;\n"
            "entity E is end E;\n"
            "architecture A of E is\n"
            "    signal clk, rst, en : std_logic;\n"
            "\n"
            "    -- Template accepting any number of signals\n"
            "    group control_template is (signal <>);\n"
            "\n"
            "    -- Group declaration referencing the template and the signals\n"
            "    group ControlGroup : control_template (clk, rst, en);\n"
            "begin\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check group members
    }

    SECTION("Group Template Declaration (Single Class)")
    {
        constexpr std::string_view VHDL_FILE
          = "package P is\n"
            "    -- Defines a template for groups that contain signals\n"
            "    group pin_group is (signal <>);\n"
            "end P;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check group template declaration
    }

    SECTION("Group Template Declaration (Multiple Classes)")
    {
        constexpr std::string_view VHDL_FILE
          = "package P is\n"
            "    -- Defines a template for groups that contain a signal AND a variable\n"
            "    -- Note: This is a fixed-size tuple style group\n"
            "    group mixed_group is (signal, variable);\n"
            "    \n"
            "    -- Alternatively, unbounded lists of both:\n"
            "    group bus_group is (signal <>, constant <>);\n"
            "end P;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check group template with multiple elements
    }
}
