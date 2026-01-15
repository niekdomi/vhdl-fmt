#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <utility>

TEST_CASE("Entity Rendering", "[pretty_printer][design_units][entity]")
{
    // Common setup for all sections
    ast::Entity entity{ .context = {},
                        .name = "test_unit",
                        .generic_clause = {},
                        .port_clause = {},
                        .decls = {},
                        .stmts = {},
                        .end_label = std::nullopt,
                        .has_end_entity_keyword = false };

    SECTION("Header Definitions")
    {
        SECTION("Minimal (No Generics, No Ports)")
        {
            const std::string result = emit::test::render(entity);
            constexpr std::string_view EXPECTED = "entity test_unit is\n"
                                                  "end;";
            REQUIRE(result == EXPECTED);
        }

        SECTION("Generics Only")
        {
            ast::GenericParam param{
                .names = { "WIDTH" },
                .subtype = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                          .type_mark = "positive",
                          .constraint = std::nullopt },
                .default_expr = ast::TokenExpr{ .text = "8" }
            };
            entity.generic_clause.generics.emplace_back(std::move(param));

            const std::string result = emit::test::render(entity);
            constexpr std::string_view EXPECTED = "entity test_unit is\n"
                                                  "  generic ( WIDTH : positive := 8 );\n"
                                                  "end;";
            REQUIRE(result == EXPECTED);
        }

        SECTION("Ports Only")
        {
            entity.port_clause.ports.emplace_back(ast::Port{
              .names = { "clk" },
              .mode = "in",
              .subtype = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                        .type_mark = "std_logic",
                        .constraint = std::nullopt },
              .default_expr = std::nullopt
            });
            entity.port_clause.ports.emplace_back(ast::Port{
              .names = { "count" },
              .mode = "out",
              .subtype = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                        .type_mark = "natural",
                        .constraint = std::nullopt },
              .default_expr = std::nullopt
            });

            const std::string result = emit::test::render(entity);
            constexpr std::string_view EXPECTED
              = "entity test_unit is\n"
                "  port ( clk : in std_logic; count : out natural );\n"
                "end;";
            REQUIRE(result == EXPECTED);
        }

        SECTION("Generics and Ports with Constraints")
        {
            // Generic
            entity.generic_clause.generics.emplace_back(ast::GenericParam{
              .names = { "DEPTH" },
              .subtype = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                        .type_mark = "positive",
                        .constraint = std::nullopt },
              .default_expr = ast::TokenExpr{ .text = "16" }
            });

            // Port Constraint Construction
            auto left = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "7" });
            auto right = std::make_unique<ast::Expr>(ast::TokenExpr{ .text = "0" });
            ast::IndexConstraint idx_constraint;
            idx_constraint.ranges.children.emplace_back(ast::BinaryExpr{
              .left = std::move(left), .op = "downto", .right = std::move(right) });

            // Port
            entity.port_clause.ports.emplace_back(ast::Port{
              .names = { "data_in" },
              .mode = "in",
              .subtype
              = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                        .type_mark = "std_logic_vector",
                        .constraint = ast::Constraint(std::move(idx_constraint)) },
              .default_expr = std::nullopt
            });

            const std::string result = emit::test::render(entity);
            constexpr std::string_view EXPECTED
              = "entity test_unit is\n"
                "  generic ( DEPTH : positive := 16 );\n"
                "  port ( data_in : in std_logic_vector(7 downto 0) );\n"
                "end;";
            REQUIRE(result == EXPECTED);
        }
    }

    SECTION("End Syntax Variations")
    {
        SECTION("Minimal: end;")
        {
            entity.has_end_entity_keyword = false;
            entity.end_label = std::nullopt;

            REQUIRE(emit::test::render(entity) == "entity test_unit is\nend;");
        }

        SECTION("Keyword Only: end entity;")
        {
            entity.has_end_entity_keyword = true;
            entity.end_label = std::nullopt;

            REQUIRE(emit::test::render(entity) == "entity test_unit is\nend entity;");
        }

        SECTION("Label Only: end <name>;")
        {
            entity.has_end_entity_keyword = false;
            entity.end_label = "test_unit";

            REQUIRE(emit::test::render(entity) == "entity test_unit is\nend test_unit;");
        }

        SECTION("Full: end entity <name>;")
        {
            entity.has_end_entity_keyword = true;
            entity.end_label = "test_unit";

            REQUIRE(emit::test::render(entity) == "entity test_unit is\nend entity test_unit;");
        }
    }
}

TEST_CASE("Architecture Rendering", "[pretty_printer][design_units][architecture]")
{
    // Common setup
    ast::Architecture arch{ .context = {},
                            .name = "rtl",
                            .entity_name = "test_unit",
                            .decls = {},
                            .stmts = {},
                            .end_label = std::nullopt,
                            .has_end_architecture_keyword = false };

    SECTION("Basic Structure")
    {
        const std::string result = emit::test::render(arch);
        constexpr std::string_view EXPECTED = "architecture rtl of test_unit is\n"
                                              "begin\n"
                                              "end;";
        REQUIRE(result == EXPECTED);
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

TEST_CASE("Library Clause Rendering", "[pretty_printer][design_units][context]")
{
    SECTION("Single library name")
    {
        const ast::LibraryClause lib{ .logical_names = { "ieee" } };
        const std::string result = emit::test::render(lib);
        REQUIRE(result == "library ieee;");
    }

    SECTION("Multiple library names")
    {
        const ast::LibraryClause lib{
            .logical_names = { "ieee", "std", "work" }
        };
        const std::string result = emit::test::render(lib);
        REQUIRE(result == "library ieee, std, work;");
    }
}

TEST_CASE("Use Clause Rendering", "[pretty_printer][design_units][context]")
{
    SECTION("Single use clause")
    {
        const ast::UseClause use{ .selected_names = { "ieee.std_logic_1164.all" } };
        const std::string result = emit::test::render(use);
        REQUIRE(result == "use ieee.std_logic_1164.all;");
    }

    SECTION("Multiple use clauses in one statement")
    {
        const ast::UseClause use{
            .selected_names = { "ieee.std_logic_1164.all", "ieee.numeric_std.all" }
        };
        const std::string result = emit::test::render(use);
        REQUIRE(result == "use ieee.std_logic_1164.all, ieee.numeric_std.all;");
    }
}

TEST_CASE("Entity with Context Clauses", "[pretty_printer][design_units][context]")
{
    SECTION("Entity with library clause")
    {
        ast::Entity entity{ .context = {},
                            .name = "test_unit",
                            .generic_clause = {},
                            .port_clause = {},
                            .decls = {},
                            .stmts = {},
                            .end_label = std::nullopt,
                            .has_end_entity_keyword = false };
        entity.context.emplace_back(ast::LibraryClause{ .logical_names = { "ieee" } });

        const std::string result = emit::test::render(entity);
        constexpr std::string_view EXPECTED = "library ieee;\n"
                                              "entity test_unit is\n"
                                              "end;";
        REQUIRE(result == EXPECTED);
    }

    SECTION("Entity with library and use clauses")
    {
        ast::Entity entity{ .context = {},
                            .name = "test_unit",
                            .generic_clause = {},
                            .port_clause = {},
                            .decls = {},
                            .stmts = {},
                            .end_label = std::nullopt,
                            .has_end_entity_keyword = false };
        entity.context.emplace_back(ast::LibraryClause{ .logical_names = { "ieee" } });
        entity.context.emplace_back(
          ast::UseClause{ .selected_names = { "ieee.std_logic_1164.all" } });
        entity.context.emplace_back(ast::UseClause{ .selected_names = { "ieee.numeric_std.all" } });

        const std::string result = emit::test::render(entity);
        constexpr std::string_view EXPECTED = "library ieee;\n"
                                              "use ieee.std_logic_1164.all;\n"
                                              "use ieee.numeric_std.all;\n"
                                              "entity test_unit is\n"
                                              "end;";
        REQUIRE(result == EXPECTED);
    }

    SECTION("Entity with multiple libraries")
    {
        ast::Entity entity{ .context = {},
                            .name = "test_unit",
                            .generic_clause = {},
                            .port_clause = {},
                            .decls = {},
                            .stmts = {},
                            .end_label = std::nullopt,
                            .has_end_entity_keyword = false };
        entity.context.emplace_back(ast::LibraryClause{ .logical_names = { "ieee" } });
        entity.context.emplace_back(
          ast::UseClause{ .selected_names = { "ieee.std_logic_1164.all" } });
        entity.context.emplace_back(ast::LibraryClause{ .logical_names = { "work" } });
        entity.port_clause.ports.emplace_back(ast::Port{
          .names = { "clk" },
          .mode = "in",
          .subtype = ast::SubtypeIndication{ .resolution_func = std::nullopt,
                    .type_mark = "std_logic",
                    .constraint = std::nullopt },
          .default_expr = std::nullopt
        });

        const std::string result = emit::test::render(entity);
        constexpr std::string_view EXPECTED = "library ieee;\n"
                                              "use ieee.std_logic_1164.all;\n"
                                              "library work;\n"
                                              "entity test_unit is\n"
                                              "  port ( clk : in std_logic );\n"
                                              "end;";
        REQUIRE(result == EXPECTED);
    }
}

TEST_CASE("Architecture with Context Clauses", "[pretty_printer][design_units][context]")
{
    SECTION("Architecture with library clause")
    {
        ast::Architecture arch{ .context = {},
                                .name = "rtl",
                                .entity_name = "test_unit",
                                .decls = {},
                                .stmts = {},
                                .end_label = std::nullopt,
                                .has_end_architecture_keyword = false };
        arch.context.emplace_back(ast::LibraryClause{ .logical_names = { "work" } });

        const std::string result = emit::test::render(arch);
        constexpr std::string_view EXPECTED = "library work;\n"
                                              "architecture rtl of test_unit is\n"
                                              "begin\n"
                                              "end;";
        REQUIRE(result == EXPECTED);
    }

    SECTION("Architecture without context clauses")
    {
        const ast::Architecture arch{ .context = {},
                                      .name = "rtl",
                                      .entity_name = "test_unit",
                                      .decls = {},
                                      .stmts = {},
                                      .end_label = std::nullopt,
                                      .has_end_architecture_keyword = false };

        const std::string result = emit::test::render(arch);
        constexpr std::string_view EXPECTED = "architecture rtl of test_unit is\n"
                                              "begin\n"
                                              "end;";
        REQUIRE(result == EXPECTED);
    }
}
