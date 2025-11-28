#include "benchmark_utils.hpp"
#include "builder/ast_builder.hpp"
#include "builder/translator.hpp"
#include "common/config.hpp"
#include "emit/pretty_printer.hpp"
#include "nodes/design_file.hpp"

#include <catch2/benchmark/catch_benchmark.hpp>
#include <catch2/catch_test_macros.hpp>

TEST_CASE("Toolchain Performance Breakdown", "[benchmark]")
{
    // ==============================================================================
    // PREPARATION
    // ==============================================================================
    const auto source = utils::STRESS_TEST_VHDL;
    common::Config default_config;

    // 1. Pre-build CST
    utils::ParsingContext context(source);
    context.parse(false); // Force LL for the 'Translation' baseline for accuracy

    // 2. Pre-build AST
    ast::DesignFile ast;
    {
        builder::Translator translator(*context.tokens);
        translator.buildDesignFile(ast, context.tree);
    }

    // 3. Pre-build Doc
    const emit::PrettyPrinter printer{};
    const auto doc = printer.visit(ast);

    // ==============================================================================
    // BENCHMARKS
    // ==============================================================================
    BENCHMARK("End-to-End: buildFromString (SLL)")
    {
        return builder::buildFromString(source);
    };

    BENCHMARK("Internal: Parsing SLL")
    {
        // Lexer + TokenStream + Parser Creation + SLL Execution
        return utils::benchmarkRawParse(source, true);
    };

    BENCHMARK("Internal: Parsing LL")
    {
        // Lexer + TokenStream + Parser Creation + LL Execution
        return utils::benchmarkRawParse(source, false);
    };

    BENCHMARK("Internal: AST Translation")
    {
        ast::DesignFile root;
        builder::Translator translator(*context.tokens);

        translator.buildDesignFile(root, context.tree);
        return root;
    };

    BENCHMARK("Internal: PrettyPrinter Visit")
    {
        const emit::PrettyPrinter printer;
        return printer.visit(ast);
    };

    BENCHMARK("Internal: PrettyPrinter Render")
    {
        return doc.render(default_config);
    };
}
