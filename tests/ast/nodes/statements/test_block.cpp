#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Block Statements", "[statements][block]")
{
    SECTION("Simple Block with Declarations")
    {
        constexpr std::string_view VHDL_FILE
          = "entity Test is end Test;\n"
            "architecture RTL of Test is\n"
            "begin\n"
            "    my_block : block\n"
            "        -- Declarations belong here, BEFORE the begin keyword\n"
            "        signal temp : std_logic;\n"
            "    begin\n"
            "        -- Concurrent statements belong here\n"
            "        temp <= '1';\n"
            "    end block my_block;\n"
            "end RTL;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check block statement when implemented
    }

    SECTION("Guarded Block")
    {
        constexpr std::string_view VHDL_FILE
          = "entity Test is end Test;\n"
            "architecture RTL of Test is\n"
            "    signal enable : std_logic := '0';\n"
            "    signal input  : std_logic := '0';\n"
            "begin\n"
            "    guarded_block : block (enable = '1')\n"
            "        signal temp : std_logic;\n"
            "    begin\n"
            "        -- 'guarded' keyword is optional on assignments inside a guarded block\n"
            "        -- but the syntax requires a valid expression on the RHS.\n"
            "        temp <= input;\n"
            "    end block guarded_block;\n"
            "end RTL;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check block statement when implemented
    }
}
