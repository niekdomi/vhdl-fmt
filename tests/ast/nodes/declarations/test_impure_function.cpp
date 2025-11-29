#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Impure Functions", "[declarations][impure_function]")
{
    SECTION("Impure Function Declaration")
    {
        constexpr std::string_view VHDL_FILE = "package P is\n"
                                               "    impure function GetCount return integer;\n"
                                               "end P;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check impure function
    }

    SECTION("Impure Function with Parameters")
    {
        constexpr std::string_view VHDL_FILE
          = "package P is\n"
            "    impure function Calculate(a, b : integer) return integer;\n"
            "end P;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check impure function with params
    }

    SECTION("Impure Function Body")
    {
        constexpr std::string_view VHDL_FILE = "package body P is\n"
                                               "    impure function GetRandom return integer is\n"
                                               "    begin\n"
                                               "        return 42;\n"
                                               "    end function GetRandom;\n"
                                               "end P;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check impure function body
    }

    /* SECTION("Impure Function in Protected Type (VHDL-2000+)")
    {
        // NOTE: Your parser currently does not support Protected Types.
        // It expects VHDL-93 types (record, array, etc.) only.

        constexpr std::string_view VHDL_FILE =
            "package P is\n"
            "    type Counter is protected\n"
            "        impure function get_value return integer;\n"
            "    end protected;\n"
            "end P;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check impure function in protected type
    }
    */
}
