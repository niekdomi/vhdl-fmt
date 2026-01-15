#include "ast/node.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/test_utils.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

using test_utils::getComments;

// ==============================================================================
// BASIC TRIVIA BINDING
// ==============================================================================

TEST_CASE("Entity captures top-level leading comments", "[design_units][trivia]")
{
    const std::string_view file =
      "-- License text\n" "-- Entity declaration for a simple counter\n" "entity MyEntity is end MyEntity;";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());

    REQUIRE(entity != nullptr);
    REQUIRE(entity->hasTrivia());

    const auto texts = getComments(entity->getLeading());

    REQUIRE(texts.size() == 2);
    REQUIRE(texts.front().contains("License text"));
    REQUIRE(texts.back().contains("Entity declaration"));
}

TEST_CASE("Generic captures both leading and inline comments", "[design_units][trivia]")
{
    const std::string_view file =
      "entity Example is\n" "    generic (\n" "        -- Leading for CONST_V\n" "        CONST_V " ": integer := 42  " " -- Inline for " "CONST_V\n" "    " ");\n" "end Example;";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->generic_clause.generics.size() == 1);

    const auto& g = entity->generic_clause.generics[0];

    REQUIRE(g.hasTrivia());

    const auto lead = getComments(g.getLeading());
    const auto in = g.getInlineComment();

    REQUIRE_FALSE(lead.empty());
    REQUIRE(lead.front().contains("Leading for CONST_V"));

    REQUIRE(in.has_value());
    REQUIRE(in->contains("Inline for CONST_V"));
}

TEST_CASE("Ports capture leading, trailing and inline comments", "[design_units][trivia]")
{
    const std::string_view file =
      "entity Example is\n" "    port (\n" "        -- leading clk\n" "        clk : in " "std_logic;  -- inline " "clk\n" "        -- " "trailing clk\n" " " " " " " " " " " " " " " " " "r" "s" "t" " " ":" " " "i" "n" " " "s" "t" "d" "_" "l" "o" "g" "i" "c" " " " " " " "-" "-" " " "i" "n" "l" "i" "n" "e" " " "r" "s" "t" "\n" "        -- trailing rst\n" "    );\n" "end Example;";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);
    REQUIRE(entity->port_clause.ports.size() == 2);

    // 1. Check CLK
    const auto& clk = entity->port_clause.ports.front();
    const auto clk_lead = getComments(clk.getLeading());
    const auto clk_trail = getComments(clk.getTrailing());
    const auto clk_inline = clk.getInlineComment();

    REQUIRE(clk_lead.front().contains("leading clk"));
    REQUIRE(clk_trail.front().contains("trailing clk"));
    REQUIRE(clk_inline.value_or("").contains("inline clk"));

    // 2. Check RST
    const auto& rst = entity->port_clause.ports.back();
    const auto rst_trail = getComments(rst.getTrailing());
    const auto rst_inline = rst.getInlineComment();

    REQUIRE(rst_trail.front().contains("trailing rst"));
    REQUIRE(rst_inline.value_or("").contains("inline rst"));
}

// ==============================================================================
// PARAGRAPH BREAKS
// ==============================================================================

TEST_CASE("Generic captures paragraph breaks (1 blank line)", "[design_units][trivia]")
{
    const std::string_view file =
      "entity ExampleEntity is\n" "    generic (\n" "        one : integer := " "1;\n" "\n" "        -- " "test\n" "\n" " " " " " " " " " " " " " " " " "t" "w" "o" " " ":" " " "i" "n" "t" "e" "g" "e" "r" " " ":" "=" " " "2" "\n" "    );\n" "end ExampleEntity;";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);

    const auto& one = entity->generic_clause.generics[0];
    const auto& two = entity->generic_clause.generics[1];

    REQUIRE(one.hasTrivia());

    const auto trailing = one.getTrailing();
    REQUIRE(trailing.size() == 3); // Break, Comment, Break

    // Break before comment
    REQUIRE(std::holds_alternative<ast::Break>(trailing[0]));
    REQUIRE(std::get<ast::Break>(trailing[0]).blank_lines == 1);

    // Comment
    REQUIRE(std::holds_alternative<ast::Comment>(trailing[1]));
    REQUIRE(std::get<ast::Comment>(trailing[1]).text.contains("test"));

    // Break after comment
    REQUIRE(std::holds_alternative<ast::Break>(trailing[2]));
    REQUIRE(std::get<ast::Break>(trailing[2]).blank_lines == 1);

    // Ensure 'two' didn't steal the trailing trivia as leading
    REQUIRE(two.getLeading().empty());
}

TEST_CASE("Generic captures paragraph breaks (2 blank lines)", "[design_units][trivia]")
{
    const std::string_view file =
      "entity ExampleEntity is\n" "    generic (\n" "        one : integer := 1;\n" "\n" "\n" "    " "    " "-- " "test" "\n" "\n" "\n" "        two : integer := 2\n" "    );\n" "end ExampleEntity;";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);

    const auto& one = entity->generic_clause.generics[0];

    REQUIRE(one.hasTrivia());
    const auto trailing = one.getTrailing();
    REQUIRE(trailing.size() == 3);

    // Break before (2 blank lines)
    REQUIRE(std::holds_alternative<ast::Break>(trailing[0]));
    REQUIRE(std::get<ast::Break>(trailing[0]).blank_lines == 2);

    // Break after (2 blank lines)
    REQUIRE(std::holds_alternative<ast::Break>(trailing[2]));
    REQUIRE(std::get<ast::Break>(trailing[2]).blank_lines == 2);
}

TEST_CASE("Generic with inline comment + paragraph breaks", "[design_units][trivia]")
{
    const std::string_view file =
      "entity ExampleEntity is\n" "    generic (\n" "        one : integer := 1; -- " "inline\n" "\n" "        -- test\n" "\n" "        two : integer := 2\n" "    );\n" "end ExampleEntity;";

    const auto design = builder::buildFromString(file);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);

    const auto& one = entity->generic_clause.generics[0];

    // 1. Inline Check
    REQUIRE(one.getInlineComment().has_value());
    REQUIRE(one.getInlineComment()->contains("inline"));

    // 2. Trailing Check
    const auto trailing = one.getTrailing();
    REQUIRE(trailing.size() == 3);

    // Ensure inline comment didn't bleed into trailing
    REQUIRE(std::holds_alternative<ast::Break>(trailing[0]));
    REQUIRE(std::get<ast::Break>(trailing[0]).blank_lines == 1);

    REQUIRE(std::holds_alternative<ast::Comment>(trailing[1]));
    REQUIRE(std::get<ast::Comment>(trailing[1]).text.contains("test"));
}

// ==============================================================================
// EDGE CASES
// ==============================================================================

TEST_CASE("Trivia: EOF Inline Comment (No Newline)", "[trivia][edge_case]")
{
    // Scenario: Comment at the very end of the file with no trailing newline
    constexpr std::string_view VHDL = "entity E is end E; -- EOF";

    const auto design = builder::buildFromString(VHDL);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);

    // Should be detected as Inline because it's on the same line as the semicolon
    REQUIRE(entity->hasTrivia());
    REQUIRE(entity->getInlineComment().value_or("") == "-- EOF");
    REQUIRE(entity->getTrailing().empty());
}

TEST_CASE("Trivia: EOF Trailing Comment", "[trivia][edge_case]")
{
    // Scenario: Comment at EOF but on a new line
    constexpr std::string_view VHDL = "entity E is end E;\n" "-- EOF Trailing";

    const auto design = builder::buildFromString(VHDL);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);

    // Should NOT be inline
    REQUIRE_FALSE(entity->getInlineComment().has_value());

    // Should be trailing
    const auto trail = getComments(entity->getTrailing());
    REQUIRE(trail.size() == 1);
    REQUIRE(trail.front() == "-- EOF Trailing");
}

TEST_CASE("Trivia: Mixed Inline and Trailing on same node", "[trivia][edge_case]")
{
    // Scenario: A node has an inline comment AND a comment on the next line
    // This ensures the binder doesn't double-count the inline comment as trailing
    constexpr std::string_view VHDL =
      "entity E is\n" "    port (\n" "        p1 : in bit; -- inline\n" "        -- " "trailing\n" "    " "    " "p2 " ": " "in " "bit" "\n" "    );\n" "end E;";

    const auto design = builder::buildFromString(VHDL);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());
    REQUIRE(entity != nullptr);

    const auto& p1 = entity->port_clause.ports[0];

    // 1. Check Inline
    REQUIRE(p1.hasTrivia());
    REQUIRE(p1.getInlineComment().value_or("") == "-- inline");

    // 2. Check Trailing (Should only have the trailing one)
    const auto trail = getComments(p1.getTrailing());
    REQUIRE(trail.size() == 1);
    REQUIRE(trail.front() == "-- trailing");
}

TEST_CASE("Trivia: Ownership of Gap Comments", "[trivia][behavior]")
{
    // Scenario: A comment sits strictly between two nodes.
    // Behavior: It attaches to the PRECEDING node as trailing trivia.
    constexpr std::string_view VHDL =
      "entity E is\n" "    generic (\n" "        g1 : integer;\n" "        -- Gap Comment\n" "     " "   " "g2 : " "integ" "er\n" "    );\n" "end E;";

    const auto design = builder::buildFromString(VHDL);
    const auto* entity = std::get_if<ast::Entity>(design.units.data());

    const auto& g1 = entity->generic_clause.generics[0];
    const auto& g2 = entity->generic_clause.generics[1];

    // g1 should claim the comment as trailing
    const auto t1 = getComments(g1.getTrailing());
    REQUIRE(!t1.empty());
    REQUIRE(t1.front() == "-- Gap Comment");

    // g2 should NOT have it as leading (avoid duplication)
    const auto l2 = getComments(g2.getLeading());
    REQUIRE(l2.empty());
}
