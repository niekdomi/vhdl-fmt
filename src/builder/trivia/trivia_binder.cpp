#include "builder/trivia/trivia_binder.hpp"

#include "CommonTokenStream.h"
#include "ParserRuleContext.h"
#include "Token.h"
#include "ast/node.hpp"
#include "builder/trivia/utils.hpp"

#include <algorithm>
#include <cstddef>
#include <memory>
#include <optional>
#include <ranges>
#include <span>
#include <utility>
#include <vector>

namespace builder {

TriviaBinder::TriviaBinder(antlr4::CommonTokenStream &ts) : tokens_(ts), used_(ts.size(), false) {}

auto TriviaBinder::extractTrivia(std::span<antlr4::Token *const> range) -> std::vector<ast::Trivia>
{
    constexpr uint8_t BREAK_BREAKOFF = 2U; // Minimum newlines to register a Break trivia

    std::vector<ast::Trivia> result{};

    unsigned int pending_newlines{ 0 };

    for (auto *token : range | std::views::filter([this](auto *t) { return !isUsed(t); })) {
        markAsUsed(token);

        if (isNewline(token)) {
            ++pending_newlines;
            continue;
        }

        if (isComment(token)) {
            if (pending_newlines >= BREAK_BREAKOFF) {
                result.emplace_back(ast::Break{ .blank_lines = pending_newlines - 1 });
            }
            pending_newlines = 0;

            result.emplace_back(ast::Comment{ token->getText() });
        }
    }

    if (pending_newlines >= BREAK_BREAKOFF) {
        result.emplace_back(ast::Break{ .blank_lines = pending_newlines - 1 });
    }

    return result;
}

auto TriviaBinder::findContextEnd(const antlr4::ParserRuleContext *ctx) const -> std::size_t
{
    const auto stop = ctx->getStop()->getTokenIndex();
    const auto line = tokens_.get(stop)->getLine();

    const auto indices = std::views::iota(stop + 1, tokens_.size());

    const auto it = std::ranges::find_if(indices, [this, line](std::size_t i) -> bool {
        auto *token = tokens_.get(i);
        return !isDefault(token) || (token->getLine() != line);
    });

    return (it != indices.end()) ? (*it - 1) : stop;
}

void TriviaBinder::bind(ast::NodeBase &node, const antlr4::ParserRuleContext *ctx)
{
    if (ctx == nullptr) {
        return;
    }

    const auto start_idx = ctx->getStart()->getTokenIndex();
    const auto stop_idx = findContextEnd(ctx);

    // Extract Inline (Immediate Right of stop)
    std::optional<ast::Comment> inline_comment{};
    if (stop_idx + 1 < tokens_.size()) {
        if (const auto *token = tokens_.get(stop_idx + 1); isComment(token) && !isUsed(token)) {
            inline_comment = ast::Comment{ token->getText() };
            markAsUsed(token);
        }
    }

    auto leading = extractTrivia(tokens_.getHiddenTokensToLeft(start_idx));
    auto trailing = extractTrivia(tokens_.getHiddenTokensToRight(stop_idx));

    // Commit to Node
    if (!leading.empty() || !trailing.empty() || inline_comment.has_value()) {
        node.trivia = std::make_unique<ast::NodeTrivia>(
          ast::NodeTrivia{ .leading = std::move(leading),
                           .trailing = std::move(trailing),
                           .inline_comment = std::move(inline_comment) });
    }
}

auto TriviaBinder::isUsed(const antlr4::Token *token) const -> bool
{
    return used_[token->getTokenIndex()];
}

auto TriviaBinder::markAsUsed(const antlr4::Token *token) -> void
{
    used_[token->getTokenIndex()] = true;
}

} // namespace builder
