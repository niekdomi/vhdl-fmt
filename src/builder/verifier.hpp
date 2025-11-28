#ifndef BUILDER_VERIFIER_HPP
#define BUILDER_VERIFIER_HPP

#include "CommonTokenStream.h"
#include "Token.h"

#include <algorithm>
#include <cctype>
#include <format>
#include <ranges>
#include <stdexcept>
#include <string>

namespace builder::verify {

namespace detail {

// Semantic check: Is this token meaningful for comparison?
constexpr auto IS_SEMANTIC = [](antlr4::Token *t) -> bool {
    return t
        != nullptr
        && t->getChannel()
        == antlr4::Token::DEFAULT_CHANNEL
        && t->getType()
        != antlr4::Token::EOF;
};

// Case-insensitive string comparison predicate
constexpr auto IEQUALS = [](const std::string &a, const std::string &b) -> bool {
    return std::ranges::equal(a, b, [](unsigned char c1, unsigned char c2) -> bool {
        return std::tolower(c1) == std::tolower(c2);
    });
};

} // namespace detail

/// @brief Verifies that two token streams are strictly equivalent semantically.
inline void ensureSafety(antlr4::CommonTokenStream &original, antlr4::CommonTokenStream &formatted)
{
    // Create lazy views of the semantic tokens
    auto orig_view = original.getTokens() | std::views::filter(detail::IS_SEMANTIC);
    auto fmt_view = formatted.getTokens() | std::views::filter(detail::IS_SEMANTIC);

    // Predicate: Do these two tokens match?
    auto token_match = [](antlr4::Token *t1, antlr4::Token *t2) -> bool {
        return t1->getType() == t2->getType() && detail::IEQUALS(t1->getText(), t2->getText());
    };

    // Find the first point of divergence
    auto [it_orig, it_fmt] = std::ranges::mismatch(orig_view, fmt_view, token_match);

    // If both iterators reached the end, the streams are identical
    if (it_orig == orig_view.end() && it_fmt == fmt_view.end()) {
        return;
    }

    // Determine the type of error based on which iterator stopped early
    if (it_orig == orig_view.end()) {
        throw std::runtime_error(std::format(
          "Formatted output has extra content. Unexpected token: '{}'", (*it_fmt)->getText()));
    }

    if (it_fmt == fmt_view.end()) {
        throw std::runtime_error(std::format(
          "Formatted output is truncated. Missing expected token: '{}'", (*it_orig)->getText()));
    }

    // If we are here, both iterators pointed to tokens that didn't match.
    // We inspect the tokens to generate the specific error message (Type vs Text).
    auto *t_orig = *it_orig;
    auto *t_fmt = *it_fmt;

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

    // Must be a text mismatch if types were equal
    throw std::runtime_error(std::format("Token Text Mismatch!\n"
                                         "  Original:  '{}' (Line: {})\n"
                                         "  Formatted: '{}' (Line: {})",
                                         t_orig->getText(),
                                         t_orig->getLine(),
                                         t_fmt->getText(),
                                         t_fmt->getLine()));
}

} // namespace builder::verify

#endif /* BUILDER_VERIFIER_HPP */
