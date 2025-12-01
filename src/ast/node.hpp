#ifndef AST_NODE_HPP
#define AST_NODE_HPP

#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <utility>
#include <variant>
#include <vector>

namespace ast {

struct Comment
{
    std::string text;
};

/// @brief Represents intentional vertical spacing (1+ blank lines) between code elements.
/// Only captured when there are 2+ newlines (which creates 1+ visible blank lines).
/// Used to preserve user's intentional grouping while allowing the formatter to normalize spacing.
struct Break
{
    unsigned int blank_lines{ 1 }; ///< Number of visible blank lines
};

/// @brief A variant representing either a comment or a paragraph break to preserve order.
using Trivia = std::variant<Comment, Break>;

/// @brief Container for leading and trailing trivia (Newlines are only counted leading).
struct NodeTrivia
{
    std::vector<Trivia> leading;
    std::vector<Trivia> trailing;
    std::optional<Comment> inline_comment;
};

/// @brief Abstract base class for all AST nodes - Do not instantiate directly.
/// @note There is no virtual destructor to leverage aggregate initialization.
struct NodeBase
{
    std::unique_ptr<NodeTrivia> trivia;

    void addLeading(Trivia t) { getOrCreateTrivia().leading.emplace_back(std::move(t)); }

    void addTrailing(Trivia t) { getOrCreateTrivia().trailing.emplace_back(std::move(t)); }

    void setInlineComment(std::string text)
    {
        getOrCreateTrivia().inline_comment = Comment{ std::move(text) };
    }

    /// @brief Returns a view of leading trivia. Returns empty span if no trivia exists.
    [[nodiscard]]
    auto getLeading() const -> std::span<const Trivia>
    {
        if (trivia) {
            return trivia->leading;
        }
        return {}; // Returns an empty span (size 0)
    }

    /// @brief Returns a view of trailing trivia. Returns empty span if no trivia exists.
    [[nodiscard]]
    auto getTrailing() const -> std::span<const Trivia>
    {
        if (trivia) {
            return trivia->trailing;
        }
        return {};
    }

    /// @brief Returns the inline comment text if it exists, otherwise nullopt.
    [[nodiscard]]
    auto getInlineComment() const -> std::optional<std::string_view>
    {
        if (trivia && trivia->inline_comment) {
            return trivia->inline_comment->text;
        }
        return std::nullopt;
    }

    /// @brief Checks if any trivia exists without allocating.
    [[nodiscard]]
    auto hasTrivia() const -> bool
    {
        return trivia != nullptr;
    }

  private:
    // Internal helper to handle the lazy allocation logic
    auto getOrCreateTrivia() -> NodeTrivia &
    {
        if (!trivia) {
            trivia = std::make_unique<NodeTrivia>();
        }
        return *trivia;
    }
};

} // namespace ast

#endif /* AST_NODE_HPP */
