#include "builder/ast_builder.hpp"
#include "builder/translator.hpp"
#include "builder/verifier.hpp"
#include "common/config.hpp"
#include "emit/pretty_printer.hpp"
#include "nodes/design_file.hpp"

#include <antlr4-runtime/BailErrorStrategy.h>
#include <antlr4-runtime/atn/ParserATNSimulator.h>
#include <antlr4-runtime/atn/PredictionMode.h>
#include <catch2/benchmark/catch_benchmark.hpp>
#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>

TEST_CASE("Toolchain Performance Breakdown", "[benchmark]")
{
    constexpr std::string_view STRESS_TEST_VHDL = R"(
entity benchmark_entity is
    generic (
        WIDTH : integer := 32
    );
    port (
        clk      : in  bit;
        rst      : in  bit;
        data_in  : in  bit;
        data_out : out bit
    );
end benchmark_entity;

architecture Behavioral of benchmark_entity is
    signal sig1 : bit;
    signal sig2 : bit;
    signal sig3 : bit;
begin
    process
    begin
        if clk = '1' then
            if rst = '1' then
                sig1 <= '0';
                sig2 <= '0';
                sig3 <= '0';
                data_out <= '0';
            else
                sig1 <= data_in;
                sig2 <= sig1;
                sig3 <= sig2;
                data_out <= sig3;
            end if;
        end if;
    end process;
end Behavioral;
)";

    common::Config default_config;

    // ==============================================================================
    // PREPARATION (Warm-up & Data Generation)
    // ==============================================================================

    // 1. Create a "Golden" Context for reuse
    auto golden_ctx = builder::createContext(STRESS_TEST_VHDL);

    // 2. Pre-calculate CST (for Translation benchmark)
    golden_ctx.parser->setBuildParseTree(true);
    auto *golden_tree = golden_ctx.parser->design_file();

    // 3. Pre-calculate AST (for PrettyPrinter benchmark)
    ast::DesignFile golden_ast;
    {
        builder::Translator translator(*golden_ctx.tokens);
        translator.buildDesignFile(golden_ast, golden_tree);
    }

    // 4. Pre-calculate Formatted Output (for Verification benchmark)
    std::string formatted_output;
    {
        const emit::PrettyPrinter printer{};
        auto doc = printer.visit(golden_ast);
        formatted_output = doc.render(default_config);
    }

    // ==============================================================================
    // BENCHMARKS
    // ==============================================================================

    // 1. RAW PARSING (CST Generation)
    BENCHMARK("Stage 1: Parsing (SLL Mode)")
    {
        golden_ctx.tokens->seek(0);

        auto *interpreter = golden_ctx.parser->getInterpreter<antlr4::atn::ParserATNSimulator>();
        interpreter->setPredictionMode(antlr4::atn::PredictionMode::SLL);
        golden_ctx.parser->setErrorHandler(std::make_shared<antlr4::BailErrorStrategy>());

        return golden_ctx.parser->design_file();
    };

    // 2. AST TRANSLATION
    BENCHMARK("Stage 2: AST Translation")
    {
        ast::DesignFile ast{};
        builder::Translator translator(*golden_ctx.tokens);
        translator.buildDesignFile(ast, golden_tree);
        return ast;
    };

    // 3. PRETTY PRINTING (Doc Generation)
    BENCHMARK("Stage 3: Doc Generation (Visitor)")
    {
        const emit::PrettyPrinter printer{};
        return printer.visit(golden_ast);
    };

    // 4. RENDERING
    BENCHMARK("Stage 4: Rendering to String")
    {
        const emit::PrettyPrinter printer{};
        auto doc = printer.visit(golden_ast);
        return doc.render(default_config);
    };

    // 5. VERIFICATION (Safety Check)
    BENCHMARK("Stage 5: Verification")
    {
        auto output_ctx = builder::createContext(std::string_view{ formatted_output });

        const auto verify_result
          = builder::verify::ensureSafety(*golden_ctx.tokens, *output_ctx.tokens);

        // The sample code has to be correct, so any failure is unexpected
        if (!verify_result) [[unlikely]] {
            throw std::runtime_error(verify_result.error().message);
        }

        return output_ctx;
    };
}
