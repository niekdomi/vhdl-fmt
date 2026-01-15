#ifndef TESTS_TEST_UTILS_HPP
#define TESTS_TEST_UTILS_HPP

#include "ast/node.hpp"

#include <algorithm>
#include <cstddef>
#include <ranges>
#include <span>
#include <string_view>
#include <variant>
#include <vector>

namespace test_utils {

/// @brief Extract comment texts from a trivia span
/// @param tv Span of trivia items
/// @return Vector of comment text views
inline auto getComments(std::span<const ast::Trivia> tv) -> std::vector<std::string_view>
{
    return tv
         | std::views::filter(
             [](const ast::Trivia& t) -> bool { return std::holds_alternative<ast::Comment>(t); })
         | std::views::transform([](const ast::Trivia& t) -> std::string_view {
               return std::get<ast::Comment>(t).text;
           })
         | std::ranges::to<std::vector<std::string_view>>();
}

/// @brief Counts of different trivia types
struct TriviaCounts
{
    std::size_t comments{0};        ///< Number of comment trivia items
    std::size_t newlines_items{0};  ///< Number of Break trivia items
    unsigned int newline_breaks{0}; ///< Total blank lines across all Break items
};

/// @brief Tally different types of trivia in a span
/// @param tv Span of trivia items to count
/// @return Counts of comments and newlines
inline auto tallyTrivia(std::span<const ast::Trivia> tv) -> TriviaCounts
{
    return std::ranges::fold_left(
      tv, TriviaCounts{}, [](TriviaCounts c, const ast::Trivia& t) -> TriviaCounts {
          if (std::holds_alternative<ast::Comment>(t)) {
              ++c.comments;
          } else if (const auto* pb = std::get_if<ast::Break>(&t)) {
              ++c.newlines_items;
              // Convert blank_lines to newline count (newlines = blank_lines + 1)
              // e.g., 1 blank line visually requires 2 \n characters
              c.newline_breaks += pb->blank_lines + 1;
          }
          return c;
      });
}

} // namespace test_utils

#endif /* TESTS_TEST_UTILS_HPP */
