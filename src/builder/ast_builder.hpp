#ifndef BUILDER_AST_BUILDER_HPP
#define BUILDER_AST_BUILDER_HPP

#include "CommonTokenStream.h"
#include "antlr4-runtime/ANTLRInputStream.h"
#include "ast/nodes/design_file.hpp"
#include "vhdlLexer.h"
#include "vhdlParser.h"

#include <filesystem>
#include <memory>
#include <string_view>

namespace builder {

/// @brief Holds the ANTLR state required for parsing.
/// Exposed so clients (like main.cpp) can manage token lifetime for verification.
struct Context
{
    std::unique_ptr<antlr4::ANTLRInputStream> input;
    std::unique_ptr<vhdlLexer> lexer;
    std::unique_ptr<antlr4::CommonTokenStream> tokens;
    std::unique_ptr<vhdlParser> parser;
};

// ============================================================================
// Fine-grained API (For advanced usage / verification)
// ============================================================================

/// @brief Creates a parsing context from a file path.
[[nodiscard]]
auto createContext(const std::filesystem::path& path) -> Context;

/// @brief Creates a parsing context from a string.
[[nodiscard]]
auto createContext(std::string_view source) -> Context;

/// @brief Builds the AST from an existing context.
/// @note This keeps the context alive, allowing access to tokens after build.
[[nodiscard]]
auto build(Context& ctx) -> ast::DesignFile;

// ============================================================================
// High-level API (For standard usage / tests)
// ============================================================================

/// @brief Build AST from a file path (self-contained).
/// @note Creates and destroys the Context internally.
[[nodiscard]]
auto buildFromFile(const std::filesystem::path& path) -> ast::DesignFile;

/// @brief Build AST from a string (self-contained).
/// @note Creates and destroys the Context internally.
[[nodiscard]]
auto buildFromString(std::string_view vhdl_code) -> ast::DesignFile;

} // namespace builder

#endif /* BUILDER_AST_BUILDER_HPP */
