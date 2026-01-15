#include "config_reader.hpp"

#include "common/config.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <exception>
#include <expected>
#include <filesystem>
#include <format>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <yaml-cpp/exceptions.h>
#include <yaml-cpp/node/node.h>
#include <yaml-cpp/node/parse.h>

namespace cli {

namespace {

//===----------------------------------------------------------------------===//
// Configuration Mappings
//===----------------------------------------------------------------------===//

using PortMapMemberPtr = bool common::PortMapConfig::*;
using DeclarationMemberPtr = bool common::DeclarationConfig::*;
using CasingMemberPtr = common::CaseStyle common::CasingConfig::*;

constexpr std::array<std::pair<std::string_view, common::IndentationStyle>, 2>
  INDENTATION_STYLE_MAP = {
    std::pair{"spaces", common::IndentationStyle::SPACES},
    std::pair{"tabs",   common::IndentationStyle::TABS  },
};

constexpr std::array<std::pair<std::string_view, common::EndOfLine>, 3> EOL_STYLE_MAP = {
  std::pair{"auto", common::EndOfLine::AUTO},
  std::pair{"crlf", common::EndOfLine::CRLF},
  std::pair{"lf",   common::EndOfLine::LF  },
};

constexpr std::array<std::pair<std::string_view, PortMapMemberPtr>, 1> PORT_MAP_ASSIGNMENTS_MAP = {
  std::pair{"align_signals", &common::PortMapConfig::align_signals},
};

constexpr std::array<std::pair<std::string_view, DeclarationMemberPtr>, 3>
  DECLARATION_ASSIGNMENTS_MAP = {
    std::pair{"align_colons",         &common::DeclarationConfig::align_colons        },
    std::pair{"align_types",          &common::DeclarationConfig::align_types         },
    std::pair{"align_initialization", &common::DeclarationConfig::align_initialization},
};

constexpr std::array<std::pair<std::string_view, common::CaseStyle>, 2> CASE_STYLE_MAP = {
  std::pair{"lower_case", common::CaseStyle::LOWER},
  std::pair{"UPPER_CASE", common::CaseStyle::UPPER},
};

constexpr std::array<std::pair<std::string_view, CasingMemberPtr>, 3> CASING_ASSIGNMENTS_MAP = {
  std::pair{"keywords",    &common::CasingConfig::keywords   },
  std::pair{"constants",   &common::CasingConfig::constants  },
  std::pair{"identifiers", &common::CasingConfig::identifiers},
};

//===----------------------------------------------------------------------===//
// Parsing Helpers
//===----------------------------------------------------------------------===//

/// Helper for constexpr lookup in arrays
template<typename T, std::size_t N>
[[nodiscard]]
constexpr auto findInMap(const std::array<std::pair<std::string_view, T>, N>& map,
                         std::string_view key) -> std::optional<T>
{
    for (const auto& [map_key, map_val] : map) {
        if (map_key == key) {
            return map_val;
        }
    }

    return std::nullopt;
}

/// Checks if a node exists and is not null
[[nodiscard]]
constexpr auto isValid(const YAML::Node& node) -> bool
{
    return node && !node.IsNull();
}

/// Helper to get a nested YAML node if it exists and is valid
[[nodiscard]]
constexpr auto getNestedNode(const YAML::Node& parent, std::string_view path) -> YAML::Node
{
    if (!isValid(parent)) {
        return YAML::Node{};
    }

    const YAML::Node node = parent[path];
    return isValid(node) ? node : YAML::Node{};
}

template<typename T>
[[nodiscard]]
constexpr auto tryParseYaml(const YAML::Node& node, std::string_view name) -> std::optional<T>
{
    if (!isValid(node)) {
        return std::nullopt;
    }

    try {
        return node.as<T>();
    }
    catch (const YAML::BadConversion& e) {
        throw std::runtime_error(
          std::format("Invalid value for config field '{}': {}", name, e.what()));
    }
}

template<typename T, std::size_t N, typename KeyType>
[[nodiscard]]
constexpr auto mapValueToConfig(const KeyType& style,
                                const std::array<std::pair<std::string_view, T>, N>& map,
                                std::string_view error_context) -> T
{
    if (const auto result = findInMap(map, style)) {
        return *result;
    }

    throw std::invalid_argument(std::format("Invalid {} config: {}", error_context, style));
}

/// Helper to parse and map a YAML value to a config enum
template<typename T, std::size_t N>
constexpr auto parseAndMapYamlValue(const YAML::Node& node,
                                    std::string_view key,
                                    const std::array<std::pair<std::string_view, T>, N>& map,
                                    std::string_view error_context) -> std::optional<T>
{
    if (const auto value_str = tryParseYaml<std::string>(node[key], key)) {
        return mapValueToConfig(*value_str, map, error_context);
    }
    return std::nullopt;
}

} // namespace

auto ConfigReader::readConfigFile() -> std::expected<common::Config, ConfigReadError>
{
    if (!config_file_path_.has_value()) {
        const auto default_path = std::filesystem::current_path() / "vhdl-fmt.yaml";

        if (!std::filesystem::exists(default_path)) {
            // When no config file location was passed, return the default config
            return common::Config{};
        }

        config_file_path_ = default_path;
    }

    const auto& path_to_read = config_file_path_.value();

    if (!std::filesystem::exists(path_to_read)) {
        return std::unexpected{
          ConfigReadError{.message = "Config file does not exist at the defined location."}};
    }

    YAML::Node root_node{};
    try {
        root_node = YAML::LoadFile(path_to_read.string());
    }
    catch (const YAML::BadFile& e) {
        return std::unexpected{
          ConfigReadError{.message = std::format("Could not load config file: {}", e.what())}};
    }
    catch (const std::exception& e) {
        return std::unexpected{
          ConfigReadError{.message = std::format("Error reading config file: {}", e.what())}};
    }

    if (!root_node.IsNull() && !root_node.IsMap()) {
        return std::unexpected{ConfigReadError{
          .message = "Config file is not a valid yaml file or could not be correctly loaded."}};
    }

    try {
        common::Config config{};

        config.casing = readCasingConfig(root_node, config.casing);
        config.port_map = readPortMapConfig(root_node, config.port_map);
        config.eol_format = readEndOfLine(root_node, config.eol_format);
        config.line_config = readLineconfig(root_node, config.line_config);
        config.indent_style = readIndentationStyle(root_node, config.indent_style);
        config.declarations = readDeclarationConfig(root_node, config.declarations);

        return config;
    }
    catch (const std::exception& e) {
        return std::unexpected{
          ConfigReadError{.message = std::format("Config parsing failed: {}", e.what())}};
    }
}

//===----------------------------------------------------------------------===//
// Config Readers
//===----------------------------------------------------------------------===//

constexpr auto ConfigReader::readLineconfig(const YAML::Node& root_node,
                                            const common::LineConfig& defaults)
  -> common::LineConfig
{
    auto line_config = defaults;

    if (const auto value = tryParseYaml<std::uint16_t>(root_node["line_length"], "line_length")) {
        line_config.line_length = *value;
    }

    const auto indent_node = getNestedNode(root_node, "indentation");

    if (isValid(indent_node)) {
        if (const auto value = tryParseYaml<std::uint8_t>(indent_node["size"], "indentation.size"))
        {
            line_config.indent_size = *value;
        }
    }

    const common::LineLength length_to_validate{.length = line_config.line_length};
    const common::IndentSize size_to_validate{.size = line_config.indent_size};
    common::LineConfig::validateLineConfig(length_to_validate, size_to_validate);

    return line_config;
}

constexpr auto ConfigReader::readIndentationStyle(const YAML::Node& root_node,
                                                  const common::IndentationStyle& defaults)
  -> common::IndentationStyle
{
    auto indent_style = defaults;

    const auto indent_node = getNestedNode(root_node, "indentation");

    if (isValid(indent_node)) {
        if (const auto result = parseAndMapYamlValue<common::IndentationStyle, 2>(
              indent_node, "style", INDENTATION_STYLE_MAP, "indentation style"))
        {
            indent_style = *result;
        }
    }

    return indent_style;
}

constexpr auto ConfigReader::readEndOfLine(const YAML::Node& root_node,
                                           const common::EndOfLine& defaults) -> common::EndOfLine
{
    auto eol = defaults;

    if (const auto result = parseAndMapYamlValue<common::EndOfLine, 3>(
          root_node, "end_of_line", EOL_STYLE_MAP, "end of line style"))
    {
        eol = *result;
    }

    return eol;
}

constexpr auto ConfigReader::readPortMapConfig(const YAML::Node& root_node,
                                               const common::PortMapConfig& defaults)
  -> common::PortMapConfig
{
    auto port_map = defaults;

    const auto formatting_node = getNestedNode(root_node, "formatting");
    const auto port_map_node = getNestedNode(formatting_node, "port_map");

    if (isValid(port_map_node)) {
        for (const auto& [key, member_ptr] : PORT_MAP_ASSIGNMENTS_MAP) {
            if (const auto value = tryParseYaml<bool>(port_map_node[key], key)) {
                port_map.*member_ptr = *value;
            }
        }
    }

    return port_map;
}

constexpr auto ConfigReader::readDeclarationConfig(const YAML::Node& root_node,
                                                   const common::DeclarationConfig& defaults)
  -> common::DeclarationConfig
{
    auto declarations = defaults;

    const auto formatting_node = getNestedNode(root_node, "formatting");
    const auto declarations_node = getNestedNode(formatting_node, "declarations");

    if (isValid(declarations_node)) {
        for (const auto& [key, member_ptr] : DECLARATION_ASSIGNMENTS_MAP) {
            if (const auto value = tryParseYaml<bool>(declarations_node[key], key)) {
                declarations.*member_ptr = *value;
            }
        }
    }

    return declarations;
}

constexpr auto ConfigReader::readCasingConfig(const YAML::Node& root_node,
                                              const common::CasingConfig& defaults)
  -> common::CasingConfig
{
    auto casing = defaults;

    const auto formatting_node = getNestedNode(root_node, "formatting");
    const auto casing_node = getNestedNode(formatting_node, "casing");

    if (isValid(casing_node)) {
        for (const auto& [key, member_ptr] : CASING_ASSIGNMENTS_MAP) {
            if (const auto result = parseAndMapYamlValue<common::CaseStyle, 2>(
                  casing_node, key, CASE_STYLE_MAP, "casing"))
            {
                casing.*member_ptr = *result;
            }
        }
    }

    return casing;
}

} // namespace cli
