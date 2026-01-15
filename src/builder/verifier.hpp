#ifndef BUILDER_VERIFIER_HPP
#define BUILDER_VERIFIER_HPP

#include "CommonTokenStream.h"
#include "Token.h"

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <expected>
#include <format>
#include <ranges>
#include <string>

namespace builder::verify {

namespace detail {

// Semantic check: Is this token meaningful for comparison?
constexpr auto IS_SEMANTIC = [](const antlr4::Token *t) -> bool {
    return t
        != nullptr
        && t->getChannel()
        == antlr4::Token::DEFAULT_CHANNEL
        && t->getType()
        != antlr4::Token::EOF;
};

// Case-insensitive string comparison predicate
constexpr auto EQUALS = [](const std::string &a, const std::string &b) -> bool {
    return std::ranges::equal(a, b, [](unsigned char c1, unsigned char c2) -> bool {
        return std::tolower(c1) == std::tolower(c2);
    });
};

} // namespace detail

/// @brief Aggregate to represent an error found during token stream verification.
struct VerificationError
{
    std::string message;
    antlr4::Token *expected{ nullptr };
    antlr4::Token *actual{ nullptr };

    enum class Kind : std::uint8_t
    {
        EXTRA_TOKEN,
        MISSING_TOKEN,
        TYPE_MISMATCH,
        TEXT_MISMATCH
    } kind;
};

/// @brief Verifies that two token streams are strictly equivalent semantically.
inline auto ensureSafety(antlr4::CommonTokenStream &original, antlr4::CommonTokenStream &formatted)
  -> std::expected<void, VerificationError>
{
    // Create lazy views of the semantic tokens
    auto orig_view = original.getTokens() | std::views::filter(detail::IS_SEMANTIC);
    auto fmt_view = formatted.getTokens() | std::views::filter(detail::IS_SEMANTIC);

    // Predicate: Do these two tokens match?
    auto token_match = [](antlr4::Token *t1, antlr4::Token *t2) -> bool {
        return t1->getType() == t2->getType() && detail::EQUALS(t1->getText(), t2->getText());
    };

    // Find the first point of divergence
    auto [it_orig, it_fmt] = std::ranges::mismatch(orig_view, fmt_view, token_match);

    // If both iterators reached the end, the streams are identical
    if ((it_orig == orig_view.end()) && (it_fmt == fmt_view.end())) {
        return {}; // Success
    }

    // Determine the type of error based on which iterator stopped early
    if (it_orig == orig_view.end()) {
        return std::unexpected(VerificationError{
          .message = std::format("Formatted output has extra content. Unexpected token: '{}'",
                                 (*it_fmt)->getText()),
          .expected = nullptr,
          .actual = *it_fmt,
          .kind = VerificationError::Kind::EXTRA_TOKEN });
    }

    if (it_fmt == fmt_view.end()) {
        return std::unexpected(VerificationError{
          .message = std::format("Formatted output is truncated. Missing expected token: '{}'",
                                 (*it_orig)->getText()),
          .expected = *it_orig,
          .actual = nullptr,
          .kind = VerificationError::Kind::MISSING_TOKEN });
    }

    // If we are here, both iterators pointed to tokens that didn't match.
    // We inspect the tokens to generate the specific error message (Type vs Text).
    auto *t_orig = *it_orig;
    auto *t_fmt = *it_fmt;

    if (t_orig->getType() != t_fmt->getType()) {
        return std::unexpected(VerificationError{
          .message = std::format("Token Type Mismatch!\n"
                                 "  Original:  '{}' (Type: {}, Line: {})\n"
                                 "  Formatted: '{}' (Type: {}, Line: {})",
                                 t_orig->getText(),
                                 t_orig->getType(),
                                 t_orig->getLine(),
                                 t_fmt->getText(),
                                 t_fmt->getType(),
                                 t_fmt->getLine()),
          .expected = t_orig,
          .actual = t_fmt,
          .kind = VerificationError::Kind::TYPE_MISMATCH,
        });
    }

    // Must be a text mismatch if types were equal
    return std::unexpected(VerificationError{
      .message = std::format("Token Text Mismatch!\n"
                             "  Original:  '{}' (Line: {})\n"
                             "  Formatted: '{}' (Line: {})",
                             t_orig->getText(),
                             t_orig->getLine(),
                             t_fmt->getText(),
                             t_fmt->getLine()),
      .expected = t_orig,
      .actual = t_fmt,
      .kind = VerificationError::Kind::TEXT_MISMATCH,
    });
}

} // namespace builder::verify

#endif /* BUILDER_VERIFIER_HPP */
