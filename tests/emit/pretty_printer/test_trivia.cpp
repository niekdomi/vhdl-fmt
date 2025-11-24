#include "ast/node.hpp"
#include "ast/nodes/declarations.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("withTrivia: Empty/No trivia", "[pretty_printer][trivia]")
{
    const ast::GenericParam param{ .names = { "WIDTH" }, .type_name = "integer", .is_last = true };

    const auto result = emit::test::render(param);
    REQUIRE(result == "WIDTH : integer");
}

TEST_CASE("withTrivia: Single leading comment", "[pretty_printer][trivia]")
{
    ast::GenericParam param{ .names = { "WIDTH" }, .type_name = "integer", .is_last = true };

    param.addLeading(ast::Comment{ "-- a leading comment" });

    const auto result = emit::test::render(param);
    REQUIRE(result == "-- a leading comment\nWIDTH : integer");
}

TEST_CASE("withTrivia: Multiple leading comments", "[pretty_printer][trivia]")
{
    ast::GenericParam param{ .names = { "WIDTH" }, .type_name = "integer", .is_last = true };

    param.addLeading(ast::Comment{ "-- line 1" });
    param.addLeading(ast::Comment{ "-- line 2" });

    const auto result = emit::test::render(param);
    REQUIRE(result == "-- line 1\n-- line 2\nWIDTH : integer");
}

TEST_CASE("withTrivia: Leading paragraph break (1 blank line)", "[pretty_printer][trivia]")
{
    ast::GenericParam param{ .names = { "WIDTH" }, .type_name = "integer", .is_last = true };

    param.addLeading(ast::Break{ .blank_lines = 1 });

    const auto result = emit::test::render(param);
    REQUIRE(result == "\nWIDTH : integer");
}

TEST_CASE("withTrivia: Leading paragraph break (2 blank lines)", "[pretty_printer][trivia]")
{
    ast::GenericParam param{ .names = { "WIDTH" }, .type_name = "integer", .is_last = true };

    param.addLeading(ast::Break{ .blank_lines = 2 });

    const auto result = emit::test::render(param);
    REQUIRE(result == "\n\nWIDTH : integer");
}

TEST_CASE("withTrivia: Leading comments and newlines", "[pretty_printer][trivia]")
{
    ast::GenericParam param{ .names = { "WIDTH" }, .type_name = "integer", .is_last = true };

    param.addLeading(ast::Comment{ "-- header" });
    param.addLeading(ast::Break{ .blank_lines = 1 });
    param.addLeading(ast::Comment{ "-- description" });

    const auto result = emit::test::render(param);
    constexpr std::string_view EXPECTED = "-- header\n"
                                          "\n"
                                          "-- description\n"
                                          "WIDTH : integer";
    REQUIRE(result == EXPECTED);
}

TEST_CASE("withTrivia: Inline comment only", "[pretty_printer][trivia]")
{
    ast::GenericParam param{ .names = { "WIDTH" }, .type_name = "integer", .is_last = true };

    // Helper accepts the string text directly
    param.setInlineComment("-- inline");

    const auto result = emit::test::render(param);
    REQUIRE(result == "WIDTH : integer -- inline");
}

TEST_CASE("withTrivia: Single trailing comment", "[pretty_printer][trivia]")
{
    ast::GenericParam param{ .names = { "WIDTH" }, .type_name = "integer", .is_last = true };

    param.addTrailing(ast::Comment{ "-- inline comment" });

    const auto result = emit::test::render(param);
    REQUIRE(result == "WIDTH : integer\n-- inline comment");
}

TEST_CASE("withTrivia: Leading and trailing comments", "[pretty_printer][trivia]")
{
    ast::GenericParam param{ .names = { "WIDTH" }, .type_name = "integer", .is_last = true };

    param.addLeading(ast::Comment{ "-- leading" });
    param.addTrailing(ast::Comment{ "-- trailing" });

    const auto result = emit::test::render(param);
    REQUIRE(result == "-- leading\nWIDTH : integer\n-- trailing");
}

TEST_CASE("withTrivia: Complex mix", "[pretty_printer][trivia]")
{
    ast::GenericParam param{ .names = { "WIDTH" }, .type_name = "integer", .is_last = true };

    // Leading
    param.addLeading(ast::Comment{ "-- header comment" });
    param.addLeading(ast::Break{ .blank_lines = 2 });
    param.addLeading(ast::Comment{ "-- description" });

    // Inline
    param.setInlineComment("-- inline comment");

    // Trailing
    param.addTrailing(ast::Comment{ "-- trailing comment" });
    param.addTrailing(ast::Break{ .blank_lines = 2 });
    param.addTrailing(ast::Comment{ "-- footer comment" });

    const auto result = emit::test::render(param);
    constexpr std::string_view EXPECTED = "-- header comment\n"
                                          "\n"
                                          "\n"
                                          "-- description\n"
                                          "WIDTH : integer -- inline comment\n"
                                          "-- trailing comment\n"
                                          "\n"
                                          "\n"
                                          "-- footer comment";
    REQUIRE(result == EXPECTED);
}
