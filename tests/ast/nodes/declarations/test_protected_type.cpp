#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Protected Types (VHDL-2000+)", "[declarations][protected_type]")
{
    // Note: Protected types are used for shared variables and concurrency.
    // Syntax: type <Name> is protected ... end protected;

    SECTION("Protected Type Declaration")
    {
        constexpr std::string_view VHDL_FILE = "package P is\n"
                                               "    type SharedData is protected\n"
                                               "        procedure Set(v : integer);\n"
                                               "        impure function Get return integer;\n"
                                               "    end protected;\n"
                                               "end P;";

        // auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Enable when parser supports Protected Types
    }

    SECTION("Protected Type Body")
    {
        constexpr std::string_view VHDL_FILE = "package body P is\n"
                                               "    type SharedData is protected body\n"
                                               "        variable val : integer := 0;\n"
                                               "        \n"
                                               "        procedure Set(v : integer) is\n"
                                               "        begin\n"
                                               "            val := v;\n"
                                               "        end procedure;\n"
                                               "        \n"
                                               "        impure function Get return integer is\n"
                                               "        begin\n"
                                               "            return val;\n"
                                               "        end function;\n"
                                               "    end protected body;\n"
                                               "end P;";

        // auto design = builder::buildFromString(VHDL_FILE);
    }
}
