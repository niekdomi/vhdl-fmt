#include "builder/ast_builder.hpp"
#include "builder/verifier.hpp"
#include "cli/argument_parser.hpp"
#include "cli/config_reader.hpp"
#include "common/logger.hpp"
#include "emit/format.hpp"
#include "emit/pretty_printer/renderer.hpp"

#include <algorithm>
#include <cstdlib>
#include <exception>
#include <execution>
#include <fstream>
#include <iostream>
#include <span>
#include <string>
#include <string_view>

namespace {
auto formatFile(const std::filesystem::path &file,
                const auto &config,
                const cli::ArgumentParser &argparser) -> void
{
    auto &logger = common::Logger::instance();

    try {
        logger.info("Processing file: {}", file.string());

        // 1. Create Context (keeps tokens alive)
        auto ctx_orig = builder::createContext(file);

        // 2. Build AST
        const auto root = builder::build(ctx_orig);

        // 3. Format
        const std::string formatted_code = emit::format(root, config);

        // 4. Verify Safety
        const auto ctx_fmt = builder::createContext(std::string_view{ formatted_code });
        const auto result = builder::verify::ensureSafety(*ctx_orig.tokens, *ctx_fmt.tokens);

        if (!result) {
            logger.critical("Formatter corrupted the code semantics.");
            logger.critical("{}", result.error().message);
            logger.info("Aborting write to prevent data loss.");
        }

        // 5. Output
        if (argparser.isFlagSet(cli::ArgumentFlag::WRITE)) {
            std::ofstream out_file(file);
            out_file << formatted_code;
        } else {
            std::cout << formatted_code;
        }
    } catch (const std::exception &e) {
        logger.error("Error processing file '{}': {}", file.string(), e.what());
        logger.warn("Skipping file due to error");
        // Don't throw - just skip this file and continue with others
    }
}
} // namespace

auto main(int argc, char *argv[]) -> int
{
    auto &logger = common::Logger::instance();

    try {
        const cli::ArgumentParser argparser{
            std::span<const char *const>{ argv, static_cast<std::size_t>(argc) }
        };

        cli::ConfigReader config_reader{ argparser.getConfigFilePath() };
        const auto config = config_reader.readConfigFile().value();

        const auto files_to_format = argparser.getFilesToFormat();

        std::for_each(
          std::execution::par,
          files_to_format.begin(),
          files_to_format.end(),
          [&config, &argparser](const auto &file) { formatFile(file, config, argparser); });

    } catch (const std::exception &e) {
        logger.error("Error: {}", e.what());
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
