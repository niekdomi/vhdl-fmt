#include "builder/ast_builder.hpp"
#include "builder/verifier.hpp"
#include "cli/argument_parser.hpp"
#include "cli/config_reader.hpp"
#include "common/logger.hpp"
#include "emit/pretty_printer.hpp"

#include <cstdlib>
#include <fstream>
#include <iostream>

auto main(int argc, char *argv[]) -> int
{
    auto& logger = common::Logger::instance();

    try {
        const cli::ArgumentParser argparser{
            std::span<const char *const>{ argv, static_cast<std::size_t>(argc) }
        };

        cli::ConfigReader config_reader{ argparser.getConfigPath() };
        const auto config = config_reader.readConfigFile().value();

        // 1. Create Context (keeps tokens alive)
        auto ctx_orig = builder::createContext(argparser.getInputPath());

        // 2. Build AST
        const auto root = builder::build(ctx_orig);

        // 3. Format
        const emit::PrettyPrinter printer{};
        const auto doc = printer.visit(root);
        const std::string formatted_code = doc.render(config);

        // 4. Verify Safety
        auto ctx_fmt = builder::createContext(std::string_view{ formatted_code });

        try {
            builder::verify::ensureSafety(*ctx_orig.tokens, *ctx_fmt.tokens);
        } catch (const std::exception &e) {
            logger.critical("FATAL ERROR: Formatter corrupted the code semantics.");
            logger.critical("{}", e.what());
            logger.info("Aborting write to prevent data loss.");
            return EXIT_FAILURE;
        }

        // 5. Output
        if (argparser.isFlagSet(cli::ArgumentFlag::WRITE)) {
            std::ofstream out_file(argparser.getInputPath());
            out_file << formatted_code;
        } else {
            std::cout << formatted_code;
        }

    } catch (const std::exception &e) {
        logger.error("Error: {}", e.what());
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
