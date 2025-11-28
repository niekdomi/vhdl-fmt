// #include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
// #include <string_view>

TEST_CASE("Matching Relational Operators (VHDL-2008)", "[expressions][matching_rel]")
{
    // SECTION("Matching Equality (?=)")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable a, b : bit := '0';\n"
    //         "        variable result : bit;\n"
    //         "    begin\n"
    //         "        result := a ?= b;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check matching equality node
    // }

    // SECTION("Matching Inequality (?/=)")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable a, b : bit := '0';\n"
    //         "        variable result : bit;\n"
    //         "    begin\n"
    //         "        result := a ?/= b;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check matching inequality node
    // }

    // SECTION("Matching Less Than (?<)")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable a, b : bit := '0';\n"
    //         "        variable result : bit;\n"
    //         "    begin\n"
    //         "        result := a ?< b;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check matching less than
    // }

    // SECTION("Matching Greater Than (?>)")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable a, b : bit := '0';\n"
    //         "        variable result : bit;\n"
    //         "    begin\n"
    //         "        result := a ?> b;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check matching greater than
    // }

    // SECTION("Matching Less or Equal (?<=)")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable a, b : bit := '0';\n"
    //         "        variable result : bit;\n"
    //         "    begin\n"
    //         "        result := a ?<= b;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    // }

    // SECTION("Matching Greater or Equal (?>=)")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable a, b : bit := '0';\n"
    //         "        variable result : bit;\n"
    //         "    begin\n"
    //         "        result := a ?>= b;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    // }
}
