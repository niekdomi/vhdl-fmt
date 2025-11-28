#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Generate Statements with Local Declarations (VHDL-2008)", "[statements][generate]")
{
    // Common libraries
    constexpr std::string_view PRELUDE =
        "library ieee;\n"
        "use ieee.std_logic_1164.all;\n";

    SECTION("For Generate with Declarations")
    {
        constexpr std::string_view VHDL_FILE =
            "library ieee;\n"
            "use ieee.std_logic_1164.all;\n"
            "entity Test is end Test;\n"
            "architecture RTL of Test is\n"
            "begin\n"
            "    gen_label : for i in 0 to 3 generate\n"
            "        -- Local declaration (VHDL-2008)\n"
            "        signal sig : std_logic;\n"
            "    begin\n"
            "        -- The 'begin' keyword is required if declarations are present\n"
            "        sig <= '0';\n"
            "    end generate;\n"
            "end RTL;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check generate statement structure
    }

    SECTION("If Generate with Declarations")
    {
        constexpr std::string_view VHDL_FILE =
            "library ieee;\n"
            "use ieee.std_logic_1164.all;\n"
            "entity Test is end Test;\n"
            "architecture RTL of Test is\n"
            "    constant condition : boolean := true;\n"
            "begin\n"
            "    gen_if : if condition generate\n"
            "        -- Local declaration\n"
            "        signal sig : std_logic;\n"
            "    begin\n"
            "        -- Mandatory 'begin'\n"
            "        sig <= '1';\n"
            "    end generate;\n"
            "end RTL;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check if-generate statement structure
    }
}
