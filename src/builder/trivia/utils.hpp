#ifndef BUILDER_TRIVIA_COMMENT_SINK_HPP
#define BUILDER_TRIVIA_COMMENT_SINK_HPP

#include "Token.h"

#include <vhdlLexer.h>

namespace builder {

[[nodiscard]]
static auto isComment(const antlr4::Token *t) noexcept -> bool
{
    return (t != nullptr) && (t->getChannel() == vhdlLexer::COMMENTS);
}

[[nodiscard]]
static auto isNewline(const antlr4::Token *t) noexcept -> bool
{
    return (t != nullptr) && (t->getChannel() == vhdlLexer::NEWLINES);
}

// [[nodiscard]]
// static auto isDefault(const antlr4::Token *t) noexcept -> bool
// {
//     return (t != nullptr) && (t->getChannel() == vhdlLexer::DEFAULT_TOKEN_CHANNEL);
// }

} // namespace builder

#endif /* BUILDER_TRIVIA_COMMENT_SINK_HPP */
