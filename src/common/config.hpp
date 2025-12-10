#ifndef COMMON_CONFIG_HPP
#define COMMON_CONFIG_HPP

#include <cstdint>
#include <format>
#include <stdexcept>

namespace common {

/// Line length wrapper for type safety
struct LineLength final
{
    std::uint16_t length;
};

/// Indentation size wrapper for type safety
struct IndentSize final
{
    std::uint8_t size;
};

/// Indentation style used for formatting
enum class IndentationStyle : std::uint8_t
{
    SPACES,
    TABS
};

/// End of line character sequence configuration
enum class EndOfLine : std::uint8_t
{
    LF,
    CRLF,
    AUTO
};

/// Port map signal alignment configuration
struct PortMapConfig final
{
    bool align_signals{ true };
};

/// Declaration alignment configuration
struct DeclarationConfig final
{
    bool align_colons{ true };
    bool align_types{ true };
    bool align_initialization{ true };
};

/// Casing conventions for identifiers
enum class CaseStyle : std::uint8_t
{
    LOWER,
    UPPER
};

/// Specific casing configuration that overwrites the default casing
struct CasingConfig final
{
    CaseStyle keywords{ CaseStyle::LOWER };
    CaseStyle constants{ CaseStyle::UPPER };
    CaseStyle identifiers{ CaseStyle::LOWER };
};

/// General configuration for line wrapping and indentation
struct LineConfig final
{
    // Public constants for external validation/UI
    static constexpr std::uint16_t DEFAULT_LINE_LENGTH{ 100 };
    static constexpr std::uint8_t DEFAULT_INDENT_SIZE{ 4 };

    static constexpr std::uint16_t MIN_LINE_LENGTH{ 10 };
    static constexpr std::uint16_t MAX_LINE_LENGTH{ 200 };

    static constexpr std::uint8_t MIN_INDENT_SIZE{ 1 };
    static constexpr std::uint8_t MAX_INDENT_SIZE{ 16 };

    std::uint16_t line_length{ DEFAULT_LINE_LENGTH };
    std::uint8_t indent_size{ DEFAULT_INDENT_SIZE };

    /// Validate line configuration (throws on invalid values)
    static auto validateLineConfig(const LineLength length, const IndentSize size) -> void
    {
        if (length.length < MIN_LINE_LENGTH || length.length > MAX_LINE_LENGTH) {
            throw std::invalid_argument(std::format(
              "Line length must be between {} and {}", MIN_LINE_LENGTH, MAX_LINE_LENGTH));
        }

        if (size.size < MIN_INDENT_SIZE || size.size > MAX_INDENT_SIZE) {
            throw std::invalid_argument(std::format(
              "Indent size must be between {} and {}", MIN_INDENT_SIZE, MAX_INDENT_SIZE));
        }
    }
};

/// Main configuration structure containing all formatter settings
struct Config final
{
    LineConfig line_config{};
    IndentationStyle indent_style{ IndentationStyle::SPACES };
    EndOfLine eol_format{ EndOfLine::AUTO };
    PortMapConfig port_map{};
    DeclarationConfig declarations{};
    CasingConfig casing{};
};

}; // namespace common

#endif /* COMMON_CONFIG_HPP */
