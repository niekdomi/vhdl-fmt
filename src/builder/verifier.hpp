#ifndef BUILDER_VERIFIER_HPP
#define BUILDER_VERIFIER_HPP

#include "CommonTokenStream.h"
#include "Token.h"
#include "vhdlLexer.h"

#include <algorithm>
#include <cctype>
#include <format>
#include <ranges>
#include <stdexcept>

namespace builder::verify {

namespace detail {

// Filter out comments and EOF, keep everything else
inline auto isSemantic(antlr4::Token *t) -> bool
{
    return t
        != nullptr
        && t->getChannel()
        == antlr4::Token::DEFAULT_CHANNEL
        && t->getType()
        != antlr4::Token::EOF;
}

inline auto charEquals(char a, char b) -> bool
{
    return std::tolower(static_cast<unsigned char>(a))
        == std::tolower(static_cast<unsigned char>(b));
}

/// @brief Returns true if the token is a keyword that is syntactically optional
/// in the grammar and might be inserted by the formatter for standardization.
inline auto isOptionalKeyword(size_t type) -> bool
{
    switch (type) {
        // End Identifiers
        case vhdlLexer::ENTITY:
        case vhdlLexer::ARCHITECTURE:
        case vhdlLexer::PACKAGE:
        case vhdlLexer::BODY:
        case vhdlLexer::CONFIGURATION:
        case vhdlLexer::PROCEDURE:
        case vhdlLexer::FUNCTION:

        // Declarations / Modes
        case vhdlLexer::IN:        // mode defaults to 'in' if missing
        case vhdlLexer::IS:        // optional in process/block
        case vhdlLexer::COMPONENT: // optional in instantiation
        case vhdlLexer::VARIABLE:  // optional in shared variables/interfaces
        case vhdlLexer::CONSTANT:  // optional in generic interfaces
            return true;

        default:
            return false;
    }
}

} // namespace detail

/// @brief Verifies that two token streams are semantically equivalent.
/// Tolerates safe stylistic insertions but catches corruption.
inline void ensureSafety(antlr4::CommonTokenStream &original, antlr4::CommonTokenStream &formatted)
{
    auto orig_view = original.getTokens() | std::views::filter(detail::isSemantic);
    auto fmt_view = formatted.getTokens() | std::views::filter(detail::isSemantic);

    auto it_orig = orig_view.begin();
    auto it_fmt = fmt_view.begin();
    const auto end_orig = orig_view.end();
    const auto end_fmt = fmt_view.end();

    while (it_orig != end_orig && it_fmt != end_fmt) {
        auto *const t_orig = *it_orig;
        auto *const t_fmt = *it_fmt;

        // 1. Check for Match (Type + Text Case-Insensitive)
        const bool type_match = (t_orig->getType() == t_fmt->getType());
        const bool text_match
          = std::ranges::equal(t_orig->getText(), t_fmt->getText(), detail::charEquals);

        if (type_match && text_match) {
            ++it_orig;
            ++it_fmt;
            continue;
        }

        // 2. Handle Safe Insertions
        // If the formatted stream has an optional keyword that the original doesn't,
        // we skip it in the formatted stream and try to match the next token.
        if (detail::isOptionalKeyword(t_fmt->getType())) {
            ++it_fmt;
            continue;
        }

        // 3. Handle End Label Insertion (Heuristic)
        // If formatted has an identifier where original has a semicolon/eof, it's likely an end
        // label. Original:  END; Formatted: END entity Name;
        //            ^ matched
        //                ^ skipped (optional keyword)
        //                       ^ mismatch (Identifier vs Semi) -> SKIP
        if (t_fmt->getType()
            == vhdlLexer::BASIC_IDENTIFIER
            && t_orig->getType()
            != vhdlLexer::BASIC_IDENTIFIER) {
            ++it_fmt;
            continue;
        }

        // 4. Fatal Mismatch
        throw std::runtime_error(std::format("Semantic mismatch detected!\n"
                                             "  Original:  '{}' (Type: {}, Line: {})\n"
                                             "  Formatted: '{}' (Type: {}, Line: {})",
                                             t_orig->getText(),
                                             t_orig->getType(),
                                             t_orig->getLine(),
                                             t_fmt->getText(),
                                             t_fmt->getType(),
                                             t_fmt->getLine()));
    }

    // Drain remaining optional keywords from formatted stream
    while (it_fmt != end_fmt && detail::isOptionalKeyword((*it_fmt)->getType())) {
        ++it_fmt;
    }

    // Ensure both streams are fully consumed
    if (it_orig != end_orig) {
        throw std::runtime_error(std::format(
          "Formatted output is missing content. Next expected: '{}'", (*it_orig)->getText()));
    }
    if (it_fmt != end_fmt) {
        throw std::runtime_error(
          std::format("Formatted output has unexpected extra content: '{}'", (*it_fmt)->getText()));
    }
}

} // namespace builder::verify

#endif /* BUILDER_VERIFIER_HPP */
