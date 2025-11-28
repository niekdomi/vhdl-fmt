// #include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
// #include <string_view>

TEST_CASE("Package Instantiation (VHDL-2008)", "[design_units][package_instantiation]")
{
    // Note: 'package ... is new ...' is strictly VHDL-2008.
    // It is used to instantiate a package that was defined with a 'generic' clause.

    // SECTION("Basic Instantiation")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "package IntPkg is new GenericPkg generic map (dtype => integer);";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Verify PackageInstantiation node
    //     // REQUIRE(design.units.size() == 1);
    //     // auto *pkg_inst = std::get_if<ast::PackageInstantiation>(&design.units[0]);
    //     // REQUIRE(pkg_inst != nullptr);
    //     // REQUIRE(pkg_inst->name == "IntPkg");
    // }

    // SECTION("With Multiple Generic Parameters")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "package CustomPkg is new GenericPkg\n"
    //         "    generic map (\n"
    //         "        dtype => std_logic_vector,\n"
    //         "        WIDTH => 32,\n"
    //         "        SIGNED => true\n"
    //         "    );";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Verify params
    // }

    // SECTION("With Qualified Package Name")
    // {
    //     constexpr std::string_view VHDL_FILE =
    //         "package MyIntPkg is new work.GenericPkg generic map (dtype => integer);";

    //     auto design = builder::buildFromString(VHDL_FILE);
    //     // TODO(someone): Verify qualified reference
    // }
}
