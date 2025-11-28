// #include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Force and Release Statements (VHDL-2008)", "[statements][force_release]")
{
    // Common prelude
    constexpr std::string_view PRELUDE = "library ieee;\n"
                                         "use ieee.std_logic_1164.all;\n";

    // SECTION("Force Statement")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "library ieee;\n"
    //         "use ieee.std_logic_1164.all;\n"
    //         "entity Test is end Test;\n"
    //         "architecture RTL of Test is\n"
    //         "begin\n"
    //         "    -- Syntax: force <external_name> <= <expression>;\n"
    //         "    force <<signal .tb.dut.internal_sig : std_logic>> <= '1';\n"
    //         "end RTL;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check force statement node
    // }

    // SECTION("Release Statement")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "library ieee;\n"
    //         "use ieee.std_logic_1164.all;\n"
    //         "entity Test is end Test;\n"
    //         "architecture RTL of Test is\n"
    //         "begin\n"
    //         "    -- Syntax: release <external_name>;\n"
    //         "    release <<signal .tb.dut.internal_sig : std_logic>>;\n"
    //         "end RTL;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check release statement node
    // }
}
