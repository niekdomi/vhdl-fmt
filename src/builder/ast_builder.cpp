#include "builder/ast_builder.hpp"

#include "builder/translator.hpp"
#include "common/logger.hpp"
#include "nodes/design_file.hpp"

#include <antlr4-runtime/ANTLRInputStream.h>
#include <antlr4-runtime/BailErrorStrategy.h>
#include <antlr4-runtime/BaseErrorListener.h>
#include <antlr4-runtime/CommonTokenStream.h>
#include <antlr4-runtime/DefaultErrorStrategy.h>
#include <antlr4-runtime/Exceptions.h>
#include <antlr4-runtime/Recognizer.h>
#include <antlr4-runtime/Token.h>
#include <antlr4-runtime/atn/ParserATNSimulator.h>
#include <antlr4-runtime/atn/PredictionMode.h>
#include <cstddef>
#include <exception>
#include <filesystem>
#include <format>
#include <fstream>
#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vhdlLexer.h>
#include <vhdlParser.h>

namespace builder {

namespace {

// Internal helper to wire up the ANTLR pipeline
void initializeContext(Context &ctx, std::unique_ptr<antlr4::ANTLRInputStream> input)
{
    ctx.input = std::move(input);
    ctx.lexer = std::make_unique<vhdlLexer>(ctx.input.get());

    // Silence console noise
    ctx.lexer->removeErrorListeners();

    ctx.tokens = std::make_unique<antlr4::CommonTokenStream>(ctx.lexer.get());
    ctx.tokens->fill();

    ctx.parser = std::make_unique<vhdlParser>(ctx.tokens.get());
}

class ThrowingErrorListener final : public antlr4::BaseErrorListener
{
  public:
    void syntaxError(antlr4::Recognizer * /*recognizer*/,
                     antlr4::Token * /*offendingSymbol*/,
                     const std::size_t line,
                     const std::size_t char_position_in_line,
                     const std::string &msg,
                     std::exception_ptr /*e*/) override
    {
        throw std::runtime_error(
          std::format("Parser error at line {}:{} - {}", line, char_position_in_line, msg));
    }
};

} // namespace

// --- Fine-grained Implementation ---

auto createContext(const std::filesystem::path &path) -> Context
{
    std::ifstream file(path);
    if (!file) {
        throw std::runtime_error(std::format("Failed to open input file: {}", path.string()));
    }

    Context ctx{};
    auto input = std::make_unique<antlr4::ANTLRInputStream>(file);
    initializeContext(ctx, std::move(input));
    return ctx;
}

auto createContext(std::string_view source) -> Context
{
    Context ctx{};
    auto input = std::make_unique<antlr4::ANTLRInputStream>(source);
    initializeContext(ctx, std::move(input));
    return ctx;
}

auto build(Context &ctx) -> ast::DesignFile
{
    auto *interpreter = ctx.parser->getInterpreter<antlr4::atn::ParserATNSimulator>();

    // 1. Try SLL
    interpreter->setPredictionMode(antlr4::atn::PredictionMode::SLL);
    ctx.parser->setErrorHandler(std::make_shared<antlr4::BailErrorStrategy>());
    ctx.parser->removeErrorListeners();

    vhdlParser::Design_fileContext *tree = nullptr;

    try {
        tree = ctx.parser->design_file();
    } catch (const antlr4::ParseCancellationException &) {
        common::Logger::instance().trace(
          "SLL parsing failed (ambiguity). Falling back to LL mode.");

        // 2. Fallback to LL
        (*ctx.tokens).reset();
        (*ctx.parser).reset();

        ctx.parser->removeErrorListeners();

        // Add custom ThrowingListener (aborts immediately on error)
        ThrowingErrorListener throwing_listener;
        ctx.parser->addErrorListener(&throwing_listener);

        ctx.parser->setErrorHandler(std::make_shared<antlr4::DefaultErrorStrategy>());
        interpreter->setPredictionMode(antlr4::atn::PredictionMode::LL);

        tree = ctx.parser->design_file();
    }

    if (tree == nullptr) {
        throw std::runtime_error("Parser returned null tree.");
    }

    ast::DesignFile root{};
    Translator translator(*ctx.tokens);
    translator.buildDesignFile(root, tree);

    return root;
}

// --- High-level Wrapper Implementation ---

auto buildFromFile(const std::filesystem::path &path) -> ast::DesignFile
{
    auto ctx = createContext(path);
    return build(ctx);
}

auto buildFromString(std::string_view vhdl_code) -> ast::DesignFile
{
    auto ctx = createContext(vhdl_code);
    return build(ctx);
}

} // namespace builder
