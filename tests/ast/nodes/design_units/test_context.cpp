// #include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
// #include <string_view>

TEST_CASE("Context Declarations (VHDL-2008)", "[design_unit][context]")
{
    // Note: 'context' design units are strictly VHDL-2008.
    // They act as containers for library and use clauses.

    // SECTION("Basic Context Declaration")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "context MyContext is\n"
    //         "    library IEEE;\n"
    //         "    use IEEE.std_logic_1164.all;\n"
    //         "end context MyContext;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Verify Context node creation
    //     // REQUIRE(design.units.size() == 1);
    //     // auto *ctx = std::get_if<ast::Context>(&design.units[0]);
    //     // REQUIRE(ctx != nullptr);
    //     // REQUIRE(ctx->name == "MyContext");
    // }

    // SECTION("Context with Multiple Clauses")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "context IEEEContext is\n"
    //         "    library IEEE;\n"
    //         "    use IEEE.std_logic_1164.all;\n"
    //         "    use IEEE.numeric_std.all;\n"
    //         "    use IEEE.math_real.all;\n"
    //         "end context IEEEContext;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Verify multiple clauses are parsed
    // }

    // SECTION("referencing Other Contexts")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "context ExtendedContext is\n"
    //         "    -- You can include other contexts inside a context\n"
    //         "    context work.BaseContext;\n"
    //         "    library IEEE;\n"
    //         "    use IEEE.numeric_std.all;\n"
    //         "end context ExtendedContext;";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Verify nested context reference
    // }
}
