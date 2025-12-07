#include "ast/nodes/declarations.hpp"
#include "ast/nodes/types.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("TypeDecl: Array", "[pretty_printer][type][array]")
{
    ast::TypeDecl type_decl;
    type_decl.name = "mem_t";

    ast::ArrayTypeDef array_def;
    array_def.element_type = "std_logic";

    SECTION("Unconstrained array")
    {
        array_def.index_types = { "natural range <>" };
        type_decl.type_def = std::move(array_def);

        REQUIRE(emit::test::render(type_decl)
                == "type mem_t is array(natural range <>) of std_logic;");
    }

    SECTION("Constrained array (range)")
    {
        array_def.index_types = { "0 to 1023" };
        type_decl.type_def = std::move(array_def);

        REQUIRE(emit::test::render(type_decl) == "type mem_t is array(0 to 1023) of std_logic;");
    }

    SECTION("Multi-dimensional array")
    {
        array_def.index_types = { "0 to 3", "0 to 3" };
        type_decl.type_def = std::move(array_def);

        REQUIRE(emit::test::render(type_decl)
                == "type mem_t is array(0 to 3, 0 to 3) of std_logic;");
    }
}
