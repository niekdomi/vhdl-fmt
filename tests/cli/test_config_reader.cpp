#include "cli/config_reader.hpp"
#include "common/config.hpp"

#include <catch2/catch_message.hpp>
#include <catch2/catch_test_macros.hpp>
#include <catch2/generators/catch_generators.hpp>
#include <cstdint>
#include <filesystem>
#include <format>
#include <fstream>
#include <optional>
#include <string_view>

namespace {

constexpr auto getConfigPath(const std::string_view filename) -> std::filesystem::path
{
    return std::filesystem::path{TEST_DATA_DIR} / "config_file" / filename;
}

} // namespace

TEST_CASE("ConfigReader with valid complete configuration file", "[config]")
{
    const auto config_path = getConfigPath("valid_complete.yaml");
    cli::ConfigReader config_reader{config_path};

    const auto result = config_reader.readConfigFile();

    REQUIRE(result.has_value());
    const auto& config = result.value();

    REQUIRE(config.line_config.line_length == 120);
    REQUIRE(config.line_config.indent_size == 2);
    REQUIRE(config.indent_style == common::IndentationStyle::SPACES);
    REQUIRE(config.eol_format == common::EndOfLine::LF);
    REQUIRE(config.port_map.align_signals);
    REQUIRE(config.declarations.align_colons);
    REQUIRE(config.declarations.align_types);
    REQUIRE(config.declarations.align_initialization);
    REQUIRE(config.casing.keywords == common::CaseStyle::LOWER);
    REQUIRE(config.casing.constants == common::CaseStyle::UPPER);
    REQUIRE(config.casing.identifiers == common::CaseStyle::LOWER);
}

TEST_CASE("ConfigReader with empty configuration file", "[config]")
{
    const auto config_path = getConfigPath("empty.yaml");
    cli::ConfigReader reader{config_path};

    const auto result = reader.readConfigFile();

    REQUIRE(result.has_value());
    const auto& config = result.value();

    REQUIRE(config.line_config.line_length == 100);
    REQUIRE(config.line_config.indent_size == 4);
    REQUIRE(config.indent_style == common::IndentationStyle::SPACES);
    REQUIRE(config.eol_format == common::EndOfLine::AUTO);
    REQUIRE(config.port_map.align_signals);
    REQUIRE(config.declarations.align_colons);
    REQUIRE(config.declarations.align_types);
    REQUIRE(config.declarations.align_initialization);
    REQUIRE(config.casing.keywords == common::CaseStyle::LOWER);
    REQUIRE(config.casing.constants == common::CaseStyle::UPPER);
    REQUIRE(config.casing.identifiers == common::CaseStyle::LOWER);
}

TEST_CASE("ConfigReader with non-existent configuration file", "[config]")
{
    const auto config_path = getConfigPath("non_existent_file.yaml");
    cli::ConfigReader reader{config_path};

    const auto result = reader.readConfigFile();

    REQUIRE_FALSE(result.has_value());
    const auto& error = result.error();
    REQUIRE(error.message == "Config file does not exist at the defined location.");
}

TEST_CASE("ConfigReader with malformed YAML configuration file", "[config]")
{
    const auto config_path = getConfigPath("malformed.yaml");
    cli::ConfigReader reader{config_path};

    const auto result = reader.readConfigFile();

    REQUIRE_FALSE(result.has_value());
    const auto& error = result.error();
    REQUIRE(error.message.contains("Error reading config file"));
}

TEST_CASE("ConfigReader with no config file path and no default config file", "[config]")
{
    // Temporarily change to a directory without vhdl-fmt.yaml
    const auto original_path = std::filesystem::current_path();
    const auto temp_dir = std::filesystem::temp_directory_path() / "test_no_config";

    std::filesystem::create_directories(temp_dir);
    std::filesystem::current_path(temp_dir);

    cli::ConfigReader reader{std::nullopt};
    const auto result = reader.readConfigFile();

    REQUIRE(result.has_value());
    const auto& config = result.value();

    REQUIRE(config.line_config.line_length == 100);
    REQUIRE(config.line_config.indent_size == 4);
    REQUIRE(config.indent_style == common::IndentationStyle::SPACES);
    REQUIRE(config.eol_format == common::EndOfLine::AUTO);

    // Cleanup
    std::filesystem::current_path(original_path);
    std::filesystem::remove_all(temp_dir);
}

TEST_CASE("ConfigReader with invalid configuration parameters", "[config]")
{
    // clang-format off
    const auto [description, content, expected_error] = GENERATE(table<std::string_view, std::string_view, std::string_view>({
        { "line length too small", "line_length: 9",                                         "Line length must be between 10 and 200"          },
        { "line length too large", "line_length: 500",                                       "Line length must be between 10 and 200"          },
        { "indent size too small", "indentation:\n  size: 0",                                "Indent size must be between 1 and 16"            },
        { "indent size too large", "indentation:\n  size: 20",                               "Indent size must be between 1 and 16"            },
        { "invalid indent style",  "indentation:\n  style: \"invalid_style\"",               "Invalid indentation style config: invalid_style" },
        { "invalid end of line",   "end_of_line: \"invalid_eol\"",                           "Invalid end of line style config: invalid_eol"   },
        { "invalid casing style",  "formatting:\n  casing:\n    keywords: \"invalid_case\"", "Invalid casing config: invalid_case"             }
    }));
    // clang-format on

    const auto temp_path = std::filesystem::temp_directory_path() / "test_valid_config.yaml";
    {
        std::ofstream temp_file{temp_path};
        temp_file << content;
    }

    cli::ConfigReader reader{temp_path};
    const auto result = reader.readConfigFile();

    INFO(std::format("Description: {}", description));
    INFO(std::format("Content: {}", content));

    if (result.has_value()) {
        INFO("Unexpectedly succeeded - config was accepted");
        const auto& config = result.value();
        INFO(std::format("Line length: {}", config.line_config.line_length));
        INFO(std::format("Indent size: {}", config.line_config.indent_size));
    }

    REQUIRE_FALSE(result.has_value());
    const auto& error = result.error();
    INFO(std::format("Expected: {}", expected_error));
    INFO(std::format("Actual: {}", error.message));
    REQUIRE(error.message.contains(expected_error));

    // Cleanup
    std::filesystem::remove(temp_path);
}

TEST_CASE("ConfigReader with boundary values for line length and indent size", "[config]")
{
    const auto [content, expected_value, expected_field] =
      GENERATE(table<std::string_view, std::uint8_t, std::string_view>({
        {"line_length: 10",          10,  "line_length"},
        {"line_length: 200",         200, "line_length"},
        {"indentation:\n  size: 1",  1,   "indent_size"},
        {"indentation:\n  size: 16", 16,  "indent_size"}
    }));

    const auto temp_path =
      std::filesystem::temp_directory_path() / std::format("test_{}.yaml", expected_value);
    {
        std::ofstream temp_file{temp_path};
        temp_file << content;
    }

    cli::ConfigReader reader{temp_path};
    const auto result = reader.readConfigFile();

    REQUIRE(result.has_value());
    const auto& config = result.value();

    if (expected_field == "line_length") {
        REQUIRE(config.line_config.line_length == expected_value);
    } else if (expected_field == "indent_size") {
        REQUIRE(config.line_config.indent_size == expected_value);
    }

    // Cleanup
    std::filesystem::remove(temp_path);
}
