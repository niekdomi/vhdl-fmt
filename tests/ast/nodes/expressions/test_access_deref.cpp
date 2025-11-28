#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Access Type Dereferencing", "[expressions][access_deref]")
{
    SECTION("Basic Dereference (Reading value)")
    {
        constexpr std::string_view VHDL_FILE
          = "entity E is end E;\n"
            "architecture A of E is\n"
            "begin\n"
            "    process\n"
            "        type int_ptr is access integer;\n"
            "        variable ptr : int_ptr := new integer'(42);\n"
            "        variable val : integer;\n"
            "    begin\n"
            "        val := ptr.all;\n"
            "    end process;\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Verify 'ptr.all' parses as a Dereference expression
    }

    SECTION("Dereference in Assignment (Writing value)")
    {
        constexpr std::string_view VHDL_FILE = "entity E is end E;\n"
                                               "architecture A of E is\n"
                                               "begin\n"
                                               "    process\n"
                                               "        type int_ptr is access integer;\n"
                                               "        variable ptr : int_ptr := new integer;\n"
                                               "    begin\n"
                                               "        ptr.all := 100;\n"
                                               "    end process;\n"
                                               "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Verify 'ptr.all' on LHS is a Dereference expression
    }

    SECTION("Record Access Dereference (Member access)")
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
            "        variable val : integer;\n"
            "    begin\n"
            "        val := ptr.all.a;\n"
            "    end process;\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Verify structure is SelectedName(Dereference(ptr), a)
    }

    SECTION("Dereference within arithmetic expression")
    {
        constexpr std::string_view VHDL_FILE
          = "entity E is end E;\n"
            "architecture A of E is\n"
            "begin\n"
            "    process\n"
            "        type int_ptr is access integer;\n"
            "        variable ptr : int_ptr := new integer'(5);\n"
            "        variable result : integer;\n"
            "    begin\n"
            "        result := ptr.all + 10;\n"
            "    end process;\n"
            "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Verify 'ptr.all' is operand in BinaryExpr
    }
}
