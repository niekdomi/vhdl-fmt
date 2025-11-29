// #include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
// #include <string_view>

TEST_CASE("Reduction Operators (VHDL-2008)", "[expressions][reduction]")
{
    // Note: Unary reduction operators (and, or, xor, nand, nor, xnor)
    // applied to arrays (std_logic_vector, bit_vector) are strictly VHDL-2008.

    // SECTION("AND Reduction")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "    signal data : bit_vector(7 downto 0);\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable result : bit;\n"
    //         "    begin\n"
    //         "        -- Unary AND reduces all bits to one\n"
    //         "        result := and data;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Check UnaryExpr node with op=AND
    // }

    // SECTION("OR Reduction")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "    signal data : bit_vector(7 downto 0);\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable result : bit;\n"
    //         "    begin\n"
    //         "        result := or data;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    // }

    // SECTION("XOR Reduction")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "    signal data : bit_vector(7 downto 0);\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable result : bit;\n"
    //         "    begin\n"
    //         "        result := xor data;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    // }

    // SECTION("NAND Reduction")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "entity E is end E;\n"
    //         "architecture A of E is\n"
    //         "    signal data : bit_vector(7 downto 0);\n"
    //         "begin\n"
    //         "    process\n"
    //         "        variable result : bit;\n"
    //         "    begin\n"
    //         "        result := nand data;\n"
    //         "    end process;\n"
    //         "end A;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    // }
}
