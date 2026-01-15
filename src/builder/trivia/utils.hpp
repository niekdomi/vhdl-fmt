#ifndef BUILDER_TRIVIA_COMMENT_SINK_HPP
#define BUILDER_TRIVIA_COMMENT_SINK_HPP

#include "Token.h"

#include <vhdlLexer.h>

namespace builder {

[[nodiscard]]
inline auto isComment(const antlr4::Token* t) noexcept -> bool
{
    return (t != nullptr) && (t->getChannel() == vhdlLexer::COMMENTS);
}

[[nodiscard]]
inline auto isNewline(const antlr4::Token* t) noexcept -> bool
{
    return (t != nullptr) && (t->getChannel() == vhdlLexer::NEWLINES);
}

} // namespace builder

#endif /* BUILDER_TRIVIA_COMMENT_SINK_HPP */
