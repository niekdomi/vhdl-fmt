#ifndef BUILDER_VERIFIER_HPP
#define BUILDER_VERIFIER_HPP

#include "CommonTokenStream.h"
#include "Token.h"

#include <algorithm>
#include <cctype>
#include <format>
#include <ranges>
#include <stdexcept>

namespace builder::verify {

namespace detail {

// Filter out comments (Hidden Channel) and EOF
inline auto isSemantic(antlr4::Token *t) -> bool
{
    return t
        != nullptr
        && t->getChannel()
        == antlr4::Token::DEFAULT_CHANNEL
        && t->getType()
        != antlr4::Token::EOF;
}

// Case-insensitive character comparison (VHDL is case-insensitive)
inline auto charEquals(char a, char b) -> bool
{
    return std::tolower(static_cast<unsigned char>(a))
        == std::tolower(static_cast<unsigned char>(b));
}

} // namespace detail

/// @brief Verifies that two token streams are strictly equivalent semantically.
/// Ignores whitespace (channels) and case, but enforces 1:1 token matching.
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

        // 1. Check Token Type match
        if (t_orig->getType() != t_fmt->getType()) {
            throw std::runtime_error(std::format("Token Type Mismatch!\n"
                                                 "  Original:  '{}' (Type: {}, Line: {})\n"
                                                 "  Formatted: '{}' (Type: {}, Line: {})",
                                                 t_orig->getText(),
                                                 t_orig->getType(),
                                                 t_orig->getLine(),
                                                 t_fmt->getText(),
                                                 t_fmt->getType(),
                                                 t_fmt->getLine()));
        }

        // 2. Check Text Content match (Case-Insensitive)
        // We assume the formatter might change casing (e.g., entity -> ENTITY),
        // so we use case-insensitive comparison.
        if (!std::ranges::equal(t_orig->getText(), t_fmt->getText(), detail::charEquals)) {
            throw std::runtime_error(std::format("Token Text Mismatch!\n"
                                                 "  Original:  '{}' (Line: {})\n"
                                                 "  Formatted: '{}' (Line: {})",
                                                 t_orig->getText(),
                                                 t_orig->getLine(),
                                                 t_fmt->getText(),
                                                 t_fmt->getLine()));
        }

        ++it_orig;
        ++it_fmt;
    }

    // 3. Ensure both streams finished at the same time
    if (it_orig != end_orig) {
        throw std::runtime_error(std::format(
          "Formatted output is truncated. Missing expected token: '{}'", (*it_orig)->getText()));
    }

    if (it_fmt != end_fmt) {
        throw std::runtime_error(std::format(
          "Formatted output has extra content. Unexpected token: '{}'", (*it_fmt)->getText()));
    }
}

} // namespace builder::verify

#endif /* BUILDER_VERIFIER_HPP */
