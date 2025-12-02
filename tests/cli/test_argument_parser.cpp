#include "cli/argument_parser.hpp"

#include <catch2/catch_message.hpp>
#include <catch2/catch_test_macros.hpp>
#include <catch2/generators/catch_generators.hpp>
#include <filesystem>
#include <format>
#include <fstream>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace {

auto createArgs(const std::vector<std::string_view> &args) -> std::vector<char *>
{
    std::vector<char *> c_args;
    c_args.reserve(args.size());

    for (const auto &arg : args) {
        // NOLINTNEXTLINE( cppcoreguidelines-pro-type-const-cast)
        c_args.emplace_back(const_cast<char *>(arg.data()));
    }

    return c_args;
}

} // namespace

TEST_CASE("ArgumentParser with valid arguments including all options", "[argument_parser]")
{
    const std::filesystem::path temp_input
      = std::filesystem::temp_directory_path() / "test_input_all_options.vhd";
    const std::filesystem::path temp_config
      = std::filesystem::temp_directory_path() / "test_config_all_options.yaml";

    {
        // Create temporary files
        std::ofstream temp_input_file{ temp_input };
        temp_input_file << "entity test is end entity;";
    }
    {
        std::ofstream temp_config_file{ temp_config };
        temp_config_file << "line_length: 120";
    }

    const std::string file_path_str = temp_input.string();
    const std::string config_path_str = temp_config.string();
    const std::vector<std::string_view> args
      = { "vhdl-fmt", "--write", "--check", "--location", config_path_str, file_path_str };

    const auto c_args = createArgs(args);
    const std::span<const char *const> args_span{ c_args };

    const cli::ArgumentParser parser{ args_span };

    REQUIRE(parser.getInputPath() == std::filesystem::canonical(temp_input));
    REQUIRE(parser.getConfigPath().has_value());
    REQUIRE(parser.getConfigPath().value() == std::filesystem::canonical(temp_config));
    REQUIRE(parser.isFlagSet(cli::ArgumentFlag::WRITE));
    REQUIRE(parser.isFlagSet(cli::ArgumentFlag::CHECK));

    // Cleanup
    std::filesystem::remove(temp_input);
    std::filesystem::remove(temp_config);
}

TEST_CASE("ArgumentParser with valid arguments minimal options", "[argument_parser]")
{
    const std::filesystem::path temp_input
      = std::filesystem::temp_directory_path() / "test_input_minimal.vhd";

    {
        // Create temporary file
        std::ofstream temp_input_file{ temp_input };
        temp_input_file << "entity test is end entity;";
    }

    const std::string file_path_str = temp_input.string();
    const std::vector<std::string_view> args = { "vhdl-fmt", file_path_str };

    const auto c_args = createArgs(args);
    const std::span<const char *const> args_span{ c_args };

    const cli::ArgumentParser parser{ args_span };

    REQUIRE(parser.getInputPath() == std::filesystem::canonical(temp_input));
    REQUIRE_FALSE(parser.getConfigPath().has_value());
    REQUIRE_FALSE(parser.isFlagSet(cli::ArgumentFlag::WRITE));
    REQUIRE_FALSE(parser.isFlagSet(cli::ArgumentFlag::CHECK));

    // Cleanup
    std::filesystem::remove(temp_input);
}

TEST_CASE("ArgumentParser with non-existent vhdl file path", "[argument_parser]")
{
    const std::filesystem::path non_existent
      = std::filesystem::temp_directory_path() / "non_existent.vhd";

    const std::string file_path_str = non_existent.string();
    const std::vector<std::string_view> args = { "vhdl-fmt", file_path_str };

    const auto c_args = createArgs(args);
    const std::span<const char *const> args_span{ c_args };

    REQUIRE_THROWS(cli::ArgumentParser{ args_span });
}

TEST_CASE("ArgumentParser with non-existent config file path", "[argument_parser]")
{
    const std::filesystem::path temp_input
      = std::filesystem::temp_directory_path() / "test_input_nonexistent_cfg.vhd";
    const std::filesystem::path non_existent_config
      = std::filesystem::temp_directory_path() / "non_existent.yaml";

    {
        // Create temporary input file
        std::ofstream temp_input_file{ temp_input };
        temp_input_file << "entity test is end entity;";
    }

    const std::string file_path_str = temp_input.string();
    const std::string config_path_str = non_existent_config.string();
    const std::vector<std::string_view> args
      = { "vhdl-fmt", file_path_str, "--location", config_path_str };

    const auto c_args = createArgs(args);
    const std::span<const char *const> args_span{ c_args };

    REQUIRE_THROWS(cli::ArgumentParser{ args_span });

    // Cleanup
    std::filesystem::remove(temp_input);
}

TEST_CASE("ArgumentParser with config file path that is not a regular file", "[argument_parser]")
{
    const std::filesystem::path temp_input
      = std::filesystem::temp_directory_path() / "test_input_cfg_not_file.vhd";
    const std::filesystem::path temp_dir = std::filesystem::temp_directory_path() / "temp_dir";

    std::filesystem::create_directories(temp_dir);

    {
        // Create temporary input file
        std::ofstream temp_input_file{ temp_input };
        temp_input_file << "entity test is end entity;";
    }

    const std::string file_path_str = temp_input.string();
    const std::string config_path_str = temp_dir.string();
    const std::vector<std::string_view> args
      = { "vhdl-fmt", file_path_str, "--location", config_path_str };

    const auto c_args = createArgs(args);
    const std::span<const char *const> args_span{ c_args };

    REQUIRE_THROWS(cli::ArgumentParser{ args_span });

    // Cleanup
    std::filesystem::remove(temp_input);
    std::filesystem::remove_all(temp_dir);
}

TEST_CASE("ArgumentParser with missing input argument", "[argument_parser]")
{
    const std::vector<std::string_view> args = { "vhdl-fmt" };
    const auto c_args = createArgs(args);
    const std::span<const char *const> args_span{ c_args };

    REQUIRE_THROWS(cli::ArgumentParser{ args_span });
}

TEST_CASE("ArgumentParser with flags set correctly", "[argument_parser]")
{
    const auto [flags, write_set, check_set]
      = GENERATE(table<std::vector<std::string_view>, bool, bool>({
        { {},                       false, false },
        { { "--write" },            true,  false },
        { { "--check" },            false, true  },
        { { "--write", "--check" }, true,  true  }
    }));

    const std::filesystem::path temp_input
      = std::filesystem::temp_directory_path() / "test_input_flags.vhd";

    {
        // Create temporary file
        std::ofstream temp_input_file{ temp_input };
        temp_input_file << "entity test is end entity;";
    }

    const std::string file_path_str = temp_input.string();
    std::vector<std::string_view> args = { "vhdl-fmt", file_path_str };
    args.insert(args.cend(), flags.cbegin(), flags.cend());

    const auto c_args = createArgs(args);
    const std::span<const char *const> args_span(c_args);

    const cli::ArgumentParser parser{ args_span };

    INFO(std::format(
      "Expected WRITE: {}, got: {}", write_set, parser.isFlagSet(cli::ArgumentFlag::WRITE)));
    INFO(std::format(
      "Expected CHECK: {}, got: {}", check_set, parser.isFlagSet(cli::ArgumentFlag::CHECK)));

    REQUIRE(parser.isFlagSet(cli::ArgumentFlag::WRITE) == write_set);
    REQUIRE(parser.isFlagSet(cli::ArgumentFlag::CHECK) == check_set);

    // Cleanup
    std::filesystem::remove(temp_input);
}
