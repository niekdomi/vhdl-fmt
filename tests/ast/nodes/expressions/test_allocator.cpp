#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Allocator Expressions", "[expressions][allocator]")
{
    SECTION("New with Qualified Expression")
    {
        constexpr std::string_view VHDL_FILE
          = "entity E is end E;\n"
            "architecture A of E is\n"
            "begin\n"
            "    process\n"
            "        -- Must define access type first\n"
            "        type int_ptr is access integer;\n"
            "        variable ptr : int_ptr := new integer'(42);\n"
            "    begin\n"
            "    end process;\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check allocator with qualified expression when implemented
    }

    SECTION("New with Subtype")
    {
        constexpr std::string_view VHDL_FILE
          = "entity E is end E;\n"
            "architecture A of E is\n"
            "    subtype SmallInt is integer range 0 to 255;\n"
            "begin\n"
            "    process\n"
            "        type small_ptr is access SmallInt;\n"
            "        variable ptr : small_ptr := new SmallInt'(100);\n"
            "    begin\n"
            "    end process;\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check allocator with subtype when implemented
    }

    SECTION("New for Record")
    {
        constexpr std::string_view VHDL_FILE
          = "entity E is end E;\n"
            "architecture A of E is\n"
            "    type MyRecord is record\n"
            "        a : integer;\n"
            "        b : std_logic;\n"
            "    end record;\n"
            "begin\n"
            "    process\n"
            "        type rec_ptr is access MyRecord;\n"
            "        variable ptr : rec_ptr := new MyRecord'(a => 1, b => '0');\n"
            "    begin\n"
            "    end process;\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check allocator for record when implemented
    }

    SECTION("New without Initial Value")
    {
        constexpr std::string_view VHDL_FILE = "entity E is end E;\n"
                                               "architecture A of E is\n"
                                               "begin\n"
                                               "    process\n"
                                               "        type int_ptr is access integer;\n"
                                               "        variable ptr : int_ptr := new integer;\n"
                                               "    begin\n"
                                               "    end process;\n"
                                               "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check allocator without initial value when implemented
    }
}
