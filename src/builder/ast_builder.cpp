#include "builder/ast_builder.hpp"

#include "ast/nodes/design_file.hpp"
#include "builder/translator.hpp"
#include "vhdlLexer.h"
#include "vhdlParser.h"

#include <ANTLRInputStream.h>
#include <CommonTokenStream.h>
#include <antlr4-runtime/BailErrorStrategy.h>
#include <antlr4-runtime/ConsoleErrorListener.h>
#include <antlr4-runtime/DefaultErrorStrategy.h>
#include <antlr4-runtime/Exceptions.h>
#include <antlr4-runtime/atn/ParserATNSimulator.h>
#include <antlr4-runtime/atn/PredictionMode.h>
#include <filesystem>
#include <fstream>
#include <istream>
#include <memory>
#include <stdexcept>
#include <string_view>
#include <utility>

namespace builder {

namespace {

struct ParsingContext
{
    std::unique_ptr<antlr4::ANTLRInputStream> input;
    std::unique_ptr<vhdlLexer> lexer;
    std::unique_ptr<antlr4::CommonTokenStream> tokens;
    std::unique_ptr<vhdlParser> parser;
    vhdlParser::Design_fileContext *tree{};
};

auto createParsingContext(std::unique_ptr<antlr4::ANTLRInputStream> input_stream) -> ParsingContext
{
    ParsingContext ctx;
    ctx.input = std::move(input_stream);
    ctx.lexer = std::make_unique<vhdlLexer>(ctx.input.get());
    ctx.tokens = std::make_unique<antlr4::CommonTokenStream>(ctx.lexer.get());
    ctx.tokens->fill();
    ctx.parser = std::make_unique<vhdlParser>(ctx.tokens.get());

    return ctx;
}

void executeParse(ParsingContext &ctx)
{
    auto *interpreter = ctx.parser->getInterpreter<antlr4::atn::ParserATNSimulator>();

    // Preemptive SLL Parsing Attempt
    interpreter->setPredictionMode(antlr4::atn::PredictionMode::SLL);

    // Replace default error strategy with BailErrorStrategy (throws on first error)
    ctx.parser->setErrorHandler(std::make_shared<antlr4::BailErrorStrategy>());
    ctx.parser->removeErrorListeners(); // Silence console errors during fast pass

    try {
        ctx.tree = ctx.parser->design_file();
    } catch (const antlr4::ParseCancellationException &) {
        // SLL failed. Rewind stream and reset parser for full LL analysis.
        (*ctx.tokens).reset();
        (*ctx.parser).reset();

        // Restore default error handling so user sees useful error messages
        ctx.parser->addErrorListener(&antlr4::ConsoleErrorListener::INSTANCE);
        ctx.parser->setErrorHandler(std::make_shared<antlr4::DefaultErrorStrategy>());

        interpreter->setPredictionMode(antlr4::atn::PredictionMode::LL);
        ctx.tree = ctx.parser->design_file();
    }

    if (ctx.tree == nullptr) {
        throw std::runtime_error("Parser returned null tree. Unknown parsing error.");
    }
}

auto translateToAST(ParsingContext &ctx) -> ast::DesignFile
{
    ast::DesignFile root{};
    Translator translator(*ctx.tokens);
    translator.buildDesignFile(root, ctx.tree);
    return root;
}

} // namespace

auto buildFromFile(const std::filesystem::path &path) -> ast::DesignFile
{
    std::ifstream file(path);
    if (!file) {
        throw std::runtime_error("Failed to open input file: " + path.string());
    }
    return buildFromStream(file);
}

auto buildFromStream(std::istream &input) -> ast::DesignFile
{
    auto antlr_input = std::make_unique<antlr4::ANTLRInputStream>(input);
    auto ctx = createParsingContext(std::move(antlr_input));

    executeParse(ctx);

    return translateToAST(ctx);
}

auto buildFromString(std::string_view vhdl_code) -> ast::DesignFile
{
    auto antlr_input = std::make_unique<antlr4::ANTLRInputStream>(vhdl_code);
    auto ctx = createParsingContext(std::move(antlr_input));

    executeParse(ctx);

    return translateToAST(ctx);
}

} // namespace builder
