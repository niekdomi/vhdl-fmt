#include "builder/ast_builder.hpp"
#include "builder/verifier.hpp"
#include "cli/argument_parser.hpp"
#include "cli/config_reader.hpp"
#include "common/logger.hpp"
#include "emit/format.hpp"
#include "emit/pretty_printer/renderer.hpp"

#include <cstdlib>
#include <exception>
#include <fstream>
#include <iostream>
#include <iterator>
#include <ranges>
#include <span>
#include <string>
#include <string_view>

namespace {
auto getPeakMemoryMb() -> double
{
    std::ifstream status("/proc/self/status");
    std::string line;
    while (std::getline(status, line)) {
        if (line.starts_with("VmHWM:")) {
            // VmHWM is peak RSS in kB
            std::istringstream iss(line.substr(6));
            std::size_t kb = 0;
            iss >> kb;
            return static_cast<double>(kb) / 1024.0; // Convert to MB
        }
    }
    return 0.0;
}
} // namespace

auto main(int argc, char* argv[]) -> int
{
    auto& logger = common::Logger::instance();

    try {
        const cli::ArgumentParser argparser{
          std::ranges::subrange{argv, std::next(argv, argc)}
        };

        cli::ConfigReader config_reader{argparser.getConfigPath()};
        const auto mem_before_config_reader = getPeakMemoryMb();
        const auto config = config_reader.readConfigFile().value();
        const auto mem_after_config_reader = getPeakMemoryMb();

        // 1. Create Context (keeps tokens alive)
        const auto mem_before_create_context = getPeakMemoryMb();
        auto ctx_orig = builder::createContext(argparser.getInputPath());
        const auto mem_after_create_context = getPeakMemoryMb();

        // 2. Build AST
        const auto mem_before_build_ast = getPeakMemoryMb();
        const auto root = builder::build(ctx_orig);
        const auto mem_after_build_ast = getPeakMemoryMb();

        // 3. Format
        const auto mem_before_format = getPeakMemoryMb();
        const std::string formatted_code = emit::format(root, config);
        const auto mem_after_format = getPeakMemoryMb();

        // 4. Verify Safety
        const auto mem_before_verifier = getPeakMemoryMb();
        const auto ctx_fmt = builder::createContext(std::string_view{formatted_code});
        const auto mem_after_verifier = getPeakMemoryMb();

        const auto result = builder::verify::ensureSafety(*ctx_orig.tokens, *ctx_fmt.tokens);

        std::cout << "Memory usage (MB):\n";
        std::cout
          << "  ConfigReader: "
          << (mem_after_config_reader - mem_before_config_reader)
          << "\n";
        std::cout
          << "  CreateContext: "
          << (mem_after_create_context - mem_before_create_context)
          << "\n";
        std::cout << "  Build AST: " << (mem_after_build_ast - mem_before_build_ast) << "\n";
        std::cout << "  Format: " << (mem_after_format - mem_before_format) << "\n";
        std::cout << "  Verify: " << (mem_after_verifier - mem_before_verifier) << "\n";

        if (!result) {
            logger.critical("Formatter corrupted the code semantics.");
            logger.critical("{}", result.error().message);
            logger.info("Aborting write to prevent data loss.");

            return EXIT_FAILURE;
        }

        // 5. Output
        if (argparser.isFlagSet(cli::ArgumentFlag::WRITE)) {
            std::ofstream out_file(argparser.getInputPath());
            out_file << formatted_code;
        } else {
            // std::cout << formatted_code;
        }
    }
    catch (const std::exception& e) {
        logger.error("Error: {}", e.what());
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
