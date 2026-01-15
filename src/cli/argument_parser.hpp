#ifndef CLI_ARGUMENT_PARSER_HPP
#define CLI_ARGUMENT_PARSER_HPP

#include <bitset>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <optional>
#include <span>

namespace cli {

enum class ArgumentFlag : std::uint8_t
{
    WRITE = 0,
    CHECK = 1,
    FLAG_COUNT = 2, // Required for flag count
};

class ArgumentParser final
{
  public:
    explicit ArgumentParser(std::span<const char* const> args);

    [[nodiscard]]
    auto getConfigPath() const noexcept -> const std::optional<std::filesystem::path>&;

    [[nodiscard]]
    auto getInputPath() const noexcept -> const std::filesystem::path&;

    [[nodiscard]]
    auto isFlagSet(ArgumentFlag flag) const noexcept -> bool;

  private:
    auto parseArguments(std::span<const char* const> args) -> void;

    std::optional<std::filesystem::path> config_file_path_;
    std::filesystem::path input_path_;
    std::bitset<static_cast<std::size_t>(ArgumentFlag::FLAG_COUNT)> used_flags_;
};

} // namespace cli

#endif /* CLI_ARGUMENT_PARSER_HPP */
