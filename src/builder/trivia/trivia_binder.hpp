#ifndef BUILDER_TRIVIA_TRIVIA_BINDER_HPP
#define BUILDER_TRIVIA_TRIVIA_BINDER_HPP

#include "ast/node.hpp"

#include <cstddef>
#include <span>
#include <vector>

namespace antlr4 {
class CommonTokenStream;
class ParserRuleContext;
class Token;
} // namespace antlr4

namespace builder {

class TriviaBinder final
{
  public:
    explicit TriviaBinder(antlr4::CommonTokenStream &ts);

    ~TriviaBinder() = default;

    TriviaBinder(const TriviaBinder &) = delete;
    auto operator=(const TriviaBinder &) -> TriviaBinder & = delete;
    TriviaBinder(TriviaBinder &&) = delete;
    auto operator=(TriviaBinder &&) -> TriviaBinder & = delete;

    /// @brief Binds collected trivia to the specified AST node.
    void bind(ast::NodeBase &node, const antlr4::ParserRuleContext &ctx);

  private:
    antlr4::CommonTokenStream &tokens_;
    std::vector<bool> used_;

    // Returns a vector of trivia from a specific range of tokens
    [[nodiscard]]
    auto extractTrivia(std::span<antlr4::Token *const> range) -> std::vector<ast::Trivia>;

    // Finds the index of the last meaningful token in the context
    [[nodiscard]]
    auto findContextEnd(const antlr4::ParserRuleContext &ctx) const -> std::size_t;

    // Checks if a token is already taken
    [[nodiscard]]
    auto isUsed(const antlr4::Token *token) const -> bool;

    // Marks a token as used
    auto markAsUsed(const antlr4::Token *token) -> void;
};

} // namespace builder

#endif
