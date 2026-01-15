#include "ast/nodes/design_units.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <optional>
#include <string>
#include <string_view>

TEST_CASE("Architecture Rendering", "[pretty_printer][design_units][architecture]")
{
    // Common setup
    ast::Architecture arch{.name = "rtl", .entity_name = "test_unit"};

    SECTION("Basic Structure")
    {
        const std::string result = emit::test::render(arch);
        const std::string_view expected = "architecture rtl of test_unit is\n" "begin\n" "end;";
        REQUIRE(result == expected);
    }

    SECTION("End Syntax Variations")
    {
        SECTION("Minimal: end;")
        {
            arch.has_end_architecture_keyword = false;
            arch.end_label = std::nullopt;

            REQUIRE(emit::test::render(arch) == "architecture rtl of test_unit is\nbegin\nend;");
        }

        SECTION("Keyword Only: end architecture;")
        {
            arch.has_end_architecture_keyword = true;
            arch.end_label = std::nullopt;

            REQUIRE(emit::test::render(arch)
                    == "architecture rtl of test_unit is\nbegin\nend architecture;");
        }

        SECTION("Label Only: end <name>;")
        {
            arch.has_end_architecture_keyword = false;
            arch.end_label = "rtl";

            REQUIRE(emit::test::render(arch)
                    == "architecture rtl of test_unit is\nbegin\nend rtl;");
        }

        SECTION("Full: end architecture <name>;")
        {
            arch.has_end_architecture_keyword = true;
            arch.end_label = "rtl";

            REQUIRE(emit::test::render(arch)
                    == "architecture rtl of test_unit is\nbegin\nend architecture rtl;");
        }
    }
}

TEST_CASE("Design Unit (Architecture) with Context Clauses",
          "[pretty_printer][design_units][context]")
{
    ast::DesignUnit du{};
    du.unit = ast::Architecture{.name = "rtl", .entity_name = "test_unit"};

    SECTION("Architecture with library clause")
    {
        du.context.emplace_back(ast::LibraryClause{.logical_names = {"work"}});

        const std::string result = emit::test::render(du);
        const std::string_view expected =
          "library work;\n" "architecture rtl of test_unit is\n" "begin\n" "end;";
        REQUIRE(result == expected);
    }
}
