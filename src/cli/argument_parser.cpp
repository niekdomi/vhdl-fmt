#include "argument_parser.hpp"

#include "version.hpp"

#include <argparse/argparse.hpp>
#include <bitset>
#include <cstddef>
#include <exception>
#include <filesystem>
#include <format>
#include <iostream>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace cli {

namespace {

constexpr std::string_view FLAG_WRITE{"--write"};
constexpr std::string_view FLAG_CHECK{"--check"};
constexpr std::string_view FLAG_LOCATION{"--location"};

} // namespace

ArgumentParser::ArgumentParser(std::span<const char* const> args)
{
    parseArguments(args);
}

auto ArgumentParser::getConfigPath() const noexcept -> const std::optional<std::filesystem::path>&
{
    return config_file_path_;
}

auto ArgumentParser::getInputPath() const noexcept -> const std::filesystem::path&
{
    return input_path_;
}

auto ArgumentParser::isFlagSet(ArgumentFlag flag) const noexcept -> bool
{
    return used_flags_.test(static_cast<std::size_t>(flag));
}

auto ArgumentParser::parseArguments(std::span<const char* const> args) -> void
{
    argparse::ArgumentParser program{std::string(common::PROJECT_NAME),
                                     std::string(common::PROJECT_VERSION)};

    program.add_description("A VHDL formatter for beautifying and standardizing VHDL code.");
    program.add_epilog(
      "For more information, visit the project documentation.\n" "https://github.com/niekdomi/vhdl-fmt");

    program.add_argument("input")
      .help("VHDL file or directory to format")
      .metavar("file.vhd")
      .action([this](std::string_view location) -> void {
          const std::filesystem::path input_path{location};

          if (!std::filesystem::exists(input_path)) {
              throw std::runtime_error(std::format("Input path does not exist: {}", location));
          }

          if (!std::filesystem::is_regular_file(input_path)
              && !std::filesystem::is_directory(input_path))
          {
              throw std::runtime_error(
                std::format("Input path is not a regular file or directory: {}", location));
          }

          input_path_ = std::filesystem::canonical(input_path);
      });

    program.add_argument("-w", FLAG_WRITE)
      .help("Overwrites the input file with formatted content")
      .default_value(false)
      .implicit_value(true);

    program.add_argument("-c", FLAG_CHECK)
      .help("Checks if the file is formatted correctly without modifying it")
      .default_value(false)
      .implicit_value(true);

    program.add_argument("-l", FLAG_LOCATION)
      .help("Path to the configuration file (e.g., /path/to/vhdl-fmt.yaml)")
      .action([this](std::string_view location) -> void {
          const std::filesystem::path config_path{location};

          if (!std::filesystem::exists(config_path)) {
              throw std::runtime_error(
                std::format("Configuration file does not exist: {}", location));
          }

          if (!std::filesystem::is_regular_file(config_path)) {
              throw std::runtime_error(
                std::format("Configuration path is not a regular file: {}", location));
          }

          config_file_path_ = std::filesystem::canonical(config_path);
      });

    try {
        std::vector<std::string> c_args;
        c_args.reserve(args.size());

        // parse_args expects a c-style array
        for (const auto* const arg : args) {
            c_args.emplace_back(arg);
        }

        program.parse_args(c_args);

        used_flags_.set(static_cast<std::size_t>(ArgumentFlag::WRITE), program.is_used(FLAG_WRITE));
        used_flags_.set(static_cast<std::size_t>(ArgumentFlag::CHECK), program.is_used(FLAG_CHECK));
    }
    catch (const std::exception& err) {
        std::cerr << std::format("Error parsing arguments: {}\n", err.what());
        std::cerr << program << '\n';
        throw;
    }
}

} // namespace cli
