#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Attribute Declarations and Specifications", "[declarations][attribute]")
{
    SECTION("Basic Attribute Declaration")
    {
        constexpr std::string_view VHDL_FILE = "package P is\n"
                                               "    attribute KEEP : boolean;\n"
                                               "end P;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check attribute declaration when implemented
    }

    SECTION("Multiple Attribute Declarations")
    {
        constexpr std::string_view VHDL_FILE = "package P is\n"
                                               "    attribute KEEP : boolean;\n"
                                               "    attribute MARK_DEBUG : string;\n"
                                               "end P;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check multiple attributes when implemented
    }

    SECTION("Attribute Specification on Signal")
    {
        constexpr std::string_view VHDL_FILE = "entity E is end E;\n"
                                               "architecture A of E is\n"
                                               "    signal my_signal : std_logic;\n"
                                               "    \n"
                                               "    -- 1. Declaration\n"
                                               "    attribute KEEP : boolean;\n"
                                               "    -- 2. Specification\n"
                                               "    attribute KEEP of my_signal : signal is true;\n"
                                               "begin\n"
                                               "end A;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check attribute specification when implemented
    }

    SECTION("Attribute Specification on Type")
    {
        constexpr std::string_view VHDL_FILE
          = "package P is\n"
            "    type MyType is range 0 to 255;\n"
            "    \n"
            "    -- 1. Declaration\n"
            "    attribute USER_MAX : integer;\n"
            "    \n"
            "    -- 2. Specification (must be a value expression, not a range)\n"
            "    attribute USER_MAX of MyType : type is 255;\n"
            "end P;";

        auto design = builder::buildFromString(VHDL_FILE);
        // TODO(someone): Check attribute on type when implemented
    }
}
