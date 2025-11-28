#include "../../test_utils.hpp"
#include "ast/node.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <variant>

using test_utils::getComments;

TEST_CASE("Entity captures top-level leading comments", "[design_units][comments]")
{
    constexpr std::string_view VHDL_FILE = R"(
        -- License text
        -- Entity declaration for a simple counter
        entity MyEntity is end MyEntity;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.hasTrivia());

    const auto *trivia = entity.trivia.get();
    const auto texts = getComments(trivia->leading);
    REQUIRE(texts.size() == 2);
    REQUIRE(texts.front().contains("License text"));
    REQUIRE(texts.back().contains("Entity declaration"));
}

TEST_CASE("Generic captures both leading and inline comments", "[design_units][comments]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Example is
            generic (
                -- Leading for CONST_V
                CONST_V : integer := 42   -- Inline for CONST_V
            );
        end Example;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.generic_clause.generics.size() == 1);

    const auto &g = entity.generic_clause.generics[0];
    REQUIRE(g.hasTrivia());

    const auto *trivia = g.trivia.get();
    const auto lead = getComments(trivia->leading);
    REQUIRE_FALSE(lead.empty());
    REQUIRE(lead.front().contains("Leading for CONST_V"));

    const auto in = trivia->inline_comment->text;
    REQUIRE_FALSE(in.empty());
    REQUIRE(in.contains("Inline for CONST_V"));
}

TEST_CASE("Ports capture leading, trailing and inline comments", "[design_units][comments]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity Example is
            port (
                -- leading clk
                clk : in std_logic;  -- inline clk
                -- trailing clk
                rst : in std_logic   -- inline rst
                -- trailing rst
            );
        end Example;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.port_clause.ports.size() == 2);

    const auto &clk = entity.port_clause.ports.front();
    const auto *clk_trivia = clk.trivia.get();
    const auto &clk_lead = getComments(clk_trivia->leading);
    const auto &clk_trail = getComments(clk_trivia->trailing);
    const auto &clk_inline = clk_trivia->inline_comment->text;

    REQUIRE(clk_lead.front().contains("leading clk"));
    REQUIRE(clk_trail.front().contains("trailing clk"));
    REQUIRE(clk_inline.contains("inline clk"));

    const auto &rst = entity.port_clause.ports.back();
    const auto *rst_trivia = rst.trivia.get();
    const auto &rst_lead = getComments(rst_trivia->leading);
    const auto &rst_trail = getComments(rst_trivia->trailing);
    const auto &rst_inline = rst_trivia->inline_comment->text;

    REQUIRE(rst_trail.front().contains("trailing rst"));
    REQUIRE(rst_inline.contains("inline rst"));
}

TEST_CASE("Generic captures paragraph breaks after comments with blank lines",
          "[design_units][comments]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity ExampleEntity is
            generic (
                one : integer := 1;

                -- test

                two : integer := 2
            );
        end ExampleEntity;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.generic_clause.generics.size() == 2);

    const auto &one = entity.generic_clause.generics[0];
    const auto &two = entity.generic_clause.generics[1];

    // 'one' should have trailing trivia with: paragraph break, comment, paragraph break
    REQUIRE(one.hasTrivia());
    const auto *one_trivia = one.trivia.get();

    // Should have 3 elements: ParagraphBreak, Comment, ParagraphBreak
    REQUIRE(one_trivia->trailing.size() == 3);

    // First should be a paragraph break (blank line before comment)
    REQUIRE(std::holds_alternative<ast::Break>(one_trivia->trailing[0]));
    const auto &para_before = std::get<ast::Break>(one_trivia->trailing[0]);
    REQUIRE(para_before.blank_lines == 1);

    // Second should be the comment
    REQUIRE(std::holds_alternative<ast::Comment>(one_trivia->trailing[1]));
    const auto &comment = std::get<ast::Comment>(one_trivia->trailing[1]);
    REQUIRE(comment.text.contains("test"));

    // Third should be a paragraph break (blank line after comment)
    REQUIRE(std::holds_alternative<ast::Break>(one_trivia->trailing[2]));
    const auto &para_after = std::get<ast::Break>(one_trivia->trailing[2]);
    REQUIRE(para_after.blank_lines == 1);

    // 'two' should have no leading trivia (it was captured by 'one's trailing)
    if (two.hasTrivia()) {
        const auto *two_trivia = two.trivia.get();
        REQUIRE(two_trivia->leading.empty());
    }
}

TEST_CASE("Generic with inline comment captures paragraph breaks correctly",
          "[design_units][comments]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity ExampleEntity is
            generic (
                one : integer := 1; -- inline

                -- test

                two : integer := 2
            );
        end ExampleEntity;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.generic_clause.generics.size() == 2);

    const auto &one = entity.generic_clause.generics[0];
    const auto &two = entity.generic_clause.generics[1];

    // 'one' should have an inline comment AND trailing trivia with: paragraph break, comment,
    // paragraph break
    REQUIRE(one.hasTrivia());
    const auto *one_trivia = one.trivia.get();

    // Check inline comment
    REQUIRE(one_trivia->inline_comment.has_value());
    REQUIRE(one_trivia->inline_comment->text.contains("inline"));

    // Should have 3 elements in trailing: ParagraphBreak, Comment, ParagraphBreak
    REQUIRE(one_trivia->trailing.size() == 3);

    // First should be a paragraph break (blank line before comment)
    REQUIRE(std::holds_alternative<ast::Break>(one_trivia->trailing[0]));
    const auto &para_before = std::get<ast::Break>(one_trivia->trailing[0]);
    REQUIRE(para_before.blank_lines == 1);

    // Second should be the comment
    REQUIRE(std::holds_alternative<ast::Comment>(one_trivia->trailing[1]));
    const auto &comment = std::get<ast::Comment>(one_trivia->trailing[1]);
    REQUIRE(comment.text.contains("test"));

    // Third should be a paragraph break (blank line after comment)
    REQUIRE(std::holds_alternative<ast::Break>(one_trivia->trailing[2]));
    const auto &para_after = std::get<ast::Break>(one_trivia->trailing[2]);
    REQUIRE(para_after.blank_lines == 1);

    // 'two' should have no leading trivia (it was captured by 'one's trailing)
    if (two.hasTrivia()) {
        const auto *two_trivia = two.trivia.get();
        REQUIRE(two_trivia->leading.empty());
    }
}

TEST_CASE("Generic captures paragraph breaks after comments with 2 blank lines",
          "[design_units][comments]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity ExampleEntity is
            generic (
                one : integer := 1;


                -- test


                two : integer := 2
            );
        end ExampleEntity;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    const auto &entity = std::get<ast::Entity>(design.units[0]);
    REQUIRE(entity.generic_clause.generics.size() == 2);

    const auto &one = entity.generic_clause.generics[0];
    const auto &two = entity.generic_clause.generics[1];

    // 'one' should have trailing trivia with: paragraph break, comment, paragraph break
    REQUIRE(one.hasTrivia());
    const auto *one_trivia = one.trivia.get();

    // Should have 3 elements: ParagraphBreak, Comment, ParagraphBreak
    REQUIRE(one_trivia->trailing.size() == 3);

    // First should be a paragraph break (blank line before comment)
    REQUIRE(std::holds_alternative<ast::Break>(one_trivia->trailing[0]));
    const auto &para_before = std::get<ast::Break>(one_trivia->trailing[0]);
    REQUIRE(para_before.blank_lines == 2);

    // Second should be the comment
    REQUIRE(std::holds_alternative<ast::Comment>(one_trivia->trailing[1]));
    const auto &comment = std::get<ast::Comment>(one_trivia->trailing[1]);
    REQUIRE(comment.text.contains("test"));

    // Third should be a paragraph break (blank line after comment)
    REQUIRE(std::holds_alternative<ast::Break>(one_trivia->trailing[2]));
    const auto &para_after = std::get<ast::Break>(one_trivia->trailing[2]);
    REQUIRE(para_after.blank_lines == 2);

    // 'two' should have no leading trivia (it was captured by 'one's trailing)
    if (two.hasTrivia()) {
        const auto *two_trivia = two.trivia.get();
        REQUIRE(two_trivia->leading.empty());
    }
}
