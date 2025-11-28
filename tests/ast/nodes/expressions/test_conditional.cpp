#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Conditional Expressions (VHDL-2008)", "[expressions][conditional]")
{
    // Note: Usage of 'when...else' in variable initialization
    // is specifically a VHDL-2008 feature.

    // SECTION("Simple when-else (Variable Init)")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    process\n"
    //         "        constant val_true  : integer := 10;\n"
    //         "        constant val_false : integer := 20;\n"
    //         "        variable cond      : boolean := true;\n"
    //         "        -- VHDL-2008 syntax\n"
    //         "        variable result    : integer := val_true when cond else val_false;\n"
    //         "    begin\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check conditional expression
    // }

    // SECTION("Multiple Conditions (Else If)")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable x : integer := 1;\n"
    //         "        variable a, b, c : integer := 0;\n"
    //         "        variable result : integer;\n"
    //         "    begin\n"
    //         "        -- VHDL-2008 syntax\n"
    //         "        result := a when x = 1 else\n"
    //         "                  b when x = 2 else\n"
    //         "                  c;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check multiple conditions
    // }

    SECTION("Conditional Signal Assignment (Valid VHDL-93)")
    {
        // This specific case is valid in older VHDL (93/2002) because
        // it is a Concurrent Signal Assignment, not a variable assignment.
        constexpr std::string_view VHDL_FILE =
            "entity E is end E;\n"
            "architecture A of E is\n"
            "    signal output : std_logic;\n"
            "    signal sel : std_logic := '0';\n"
            "begin\n"
            "    output <= '1' when sel = '1' else '0';\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check conditional in signal assignment
    }

    // SECTION("Nested Conditionals")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable cond1, cond2 : boolean := false;\n"
    //         "        variable a, b, c : integer := 0;\n"
    //         "        variable result : integer;\n"
    //         "    begin\n"
    //         "        -- VHDL-2008 syntax with parentheses grouping\n"
    //         "        result := (a when cond1 else b) when cond2 else c;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check nested conditionals
    // }
}
