#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Disconnect Specifications", "[declarations][disconnect]")
{
    // Common prelude for time units and std_logic
    constexpr std::string_view PRELUDE = "library ieee;\n"
                                         "use ieee.std_logic_1164.all;\n";

    SECTION("Basic Disconnect Specification")
    {
        constexpr std::string_view VHDL_FILE
          = "entity E is end E;\n"
            "architecture A of E is\n"
            "    signal s : integer;\n"
            "    -- Syntax: disconnect <signal> : <type> after <time>;\n"
            "    disconnect s : integer after 10 ns;\n"
            "begin\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check disconnect specification node
    }

    SECTION("Disconnect for std_logic (Guarded Signals)")
    {
        // Note: Disconnect usually applies to guarded signals, but syntax allows it here.
        constexpr std::string_view VHDL_FILE = "library ieee;\n"
                                               "use ieee.std_logic_1164.all;\n"
                                               "entity E is end E;\n"
                                               "architecture A of E is\n"
                                               "    signal my_sig : std_logic;\n"
                                               "    disconnect my_sig : std_logic after 10 ns;\n"
                                               "begin\n"
                                               "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check disconnect with time
    }

    SECTION("Disconnect for Multiple Signals")
    {
        constexpr std::string_view VHDL_FILE = "library ieee;\n"
                                               "use ieee.std_logic_1164.all;\n"
                                               "entity E is end E;\n"
                                               "architecture A of E is\n"
                                               "    signal sig1, sig2 : std_logic;\n"
                                               "    disconnect sig1, sig2 : std_logic after 5 ns;\n"
                                               "begin\n"
                                               "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check disconnect list
    }

    SECTION("Disconnect in Block Statement")
    {
        // Fixed:
        // 1. Added label 'my_block' (mandatory for blocks).
        // 2. Moved 'disconnect' to declarative part (before 'begin').
        constexpr std::string_view VHDL_FILE
          = "library ieee;\n"
            "use ieee.std_logic_1164.all;\n"
            "entity E is end E;\n"
            "architecture A of E is\n"
            "begin\n"
            "    my_block : block\n"
            "        signal int_sig : std_logic;\n"
            "        -- Declarations go here:\n"
            "        disconnect int_sig : std_logic after 1 us;\n"
            "    begin\n"
            "        -- Concurrent statements go here\n"
            "    end block;\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check disconnect inside block
    }
}
