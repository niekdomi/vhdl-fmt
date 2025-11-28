#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Function Call Expressions", "[expressions][function_call]")
{
    SECTION("Simple Function Call")
    {
        constexpr std::string_view VHDL_FILE
          = "entity E is end E;\n"
            "architecture A of E is\n"
            "    function Add(a, b : integer) return integer is\n"
            "    begin return a + b; end function;\n"
            "begin\n"
            "    process\n"
            "        variable a, b : integer := 1;\n"
            "        variable result : integer;\n"
            "    begin\n"
            "        result := Add(a, b);\n"
            "    end process;\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check function call node
    }

    SECTION("Function Call with Conversion (to_integer)")
    {
        constexpr std::string_view VHDL_FILE
          = "library ieee;\n"
            "use ieee.numeric_std.all;\n"
            "entity E is end E;\n"
            "architecture A of E is\n"
            "begin\n"
            "    process\n"
            "        variable value : unsigned(7 downto 0) := (others => '0');\n"
            "        variable result : integer;\n"
            "    begin\n"
            "        result := to_integer(value);\n"
            "    end process;\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check conversion call
    }

    SECTION("Function Call with No Parameters")
    {
        // Fixed: Removed '()' after GetRandom.
        // VHDL syntax forbids empty parentheses for calls.
        constexpr std::string_view VHDL_FILE = "entity E is end E;\n"
                                               "architecture A of E is\n"
                                               "    impure function GetRandom return integer is\n"
                                               "    begin return 42; end function;\n"
                                               "begin\n"
                                               "    process\n"
                                               "        variable result : integer;\n"
                                               "    begin\n"
                                               "        -- Syntax is 'Name', not 'Name()'\n"
                                               "        result := GetRandom;\n"
                                               "    end process;\n"
                                               "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check function call with no params
    }

    SECTION("Nested Function Calls")
    {
        constexpr std::string_view VHDL_FILE
          = "entity E is end E;\n"
            "architecture A of E is\n"
            "    function Add(a, b : integer) return integer is begin return a+b; end;\n"
            "    function Multiply(a, b : integer) return integer is begin return a*b; end;\n"
            "begin\n"
            "    process\n"
            "        variable x, y, z : integer := 2;\n"
            "        variable result : integer;\n"
            "    begin\n"
            "        result := Add(Multiply(x, y), z);\n"
            "    end process;\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check nested function calls
    }
}
