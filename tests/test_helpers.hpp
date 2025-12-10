#ifndef TESTS_TEST_HELPERS_HPP
#define TESTS_TEST_HELPERS_HPP

#include "ast/node.hpp"
#include "ast/nodes/declarations.hpp"
#include "ast/nodes/declarations/objects.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "builder/ast_builder.hpp"

#include <algorithm>
#include <cstddef>
#include <format>
#include <ranges>
#include <span>
#include <string_view>
#include <variant>
#include <vector>

namespace test_helpers {

// =============================================================================
// Trivia Helpers
// =============================================================================

/// @brief Extract comment texts from a trivia span
/// @param tv Span of trivia items
/// @return Vector of comment text views
inline auto getComments(std::span<const ast::Trivia> tv) -> std::vector<std::string_view>
{
    return tv
         | std::views::filter(
             [](const ast::Trivia &t) -> bool { return std::holds_alternative<ast::Comment>(t); })
         | std::views::transform([](const ast::Trivia &t) -> std::string_view {
               return std::get<ast::Comment>(t).text;
           })
         | std::ranges::to<std::vector<std::string_view>>();
}

/// @brief Counts of different trivia types
struct TriviaCounts
{
    std::size_t comments{ 0 };        ///< Number of comment trivia items
    std::size_t newlines_items{ 0 };  ///< Number of Break trivia items
    unsigned int newline_breaks{ 0 }; ///< Total blank lines across all Break items
};

/// @brief Tally different types of trivia in a span
/// @param tv Span of trivia items to count
/// @return Counts of comments and newlines
inline auto tallyTrivia(std::span<const ast::Trivia> tv) -> TriviaCounts
{
    return std::ranges::fold_left(
      tv, TriviaCounts{}, [](TriviaCounts c, const ast::Trivia &t) -> TriviaCounts {
          if (std::holds_alternative<ast::Comment>(t)) {
              ++c.comments;
          } else if (const auto *pb = std::get_if<ast::Break>(&t)) {
              ++c.newlines_items;
              c.newline_breaks += pb->blank_lines + 1;
          }
          return c;
      });
}

// =============================================================================
// Parsing Helpers
// =============================================================================

/// Internal helper to parse a full design and extract the architecture
inline auto parseArchitectureWrapper(std::string_view code) -> const ast::Architecture *
{
    static ast::DesignFile design{};
    design = builder::buildFromString(code);

    if (design.units.size() < 2) {
        return nullptr;
    }
    return std::get_if<ast::Architecture>(&design.units[1]);
}

/// Parse a VHDL declaration string into a specific AST node.
template<typename T>
inline auto parseDecl(std::string_view decl_str) -> const T *
{
    const auto vhdl = std::format(R"(
        entity E is end E;
        architecture A of E is
            {}
        begin
        end A;
    )",
                                  decl_str);

    const auto *arch = parseArchitectureWrapper(vhdl);
    if ((arch == nullptr) || arch->decls.empty()) {
        return nullptr;
    }

    return std::get_if<T>(&arch->decls.front());
}

/// Parse VHDL expression from a signal initialization
inline auto parseExpr(std::string_view init_expr) -> const ast::Expr *
{
    const auto vhdl = std::format(R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := {};
        begin
        end A;
    )",
                                  init_expr);

    const auto *arch = parseArchitectureWrapper(vhdl);
    if ((arch == nullptr) || arch->decls.empty()) {
        return nullptr;
    }

    const auto *signal = std::get_if<ast::SignalDecl>(&arch->decls.front());
    if ((signal == nullptr) || !signal->init_expr.has_value()) {
        return nullptr;
    }
    return &(*signal->init_expr);
}

/// @brief Wraps a sequential statement string in a process and parses it.
template<typename T>
inline auto parseSequentialStmt(std::string_view stmt) -> const T *
{
    const auto code = std::format(
      "entity E is end; architecture A of E is begin process begin {}\n end process; end A;", stmt);

    const auto *arch = parseArchitectureWrapper(code);
    if ((arch == nullptr) || arch->stmts.empty()) {
        return nullptr;
    }

    // 1. Get the ConcurrentStatement wrapper
    const auto &proc_wrapper = arch->stmts.front();

    // 2. Extract the Process body (Logic)
    const auto *proc = std::get_if<ast::Process>(&proc_wrapper.kind);
    if ((proc == nullptr) || proc->body.empty()) {
        return nullptr;
    }

    // 3. Get the SequentialStatement wrapper from the body
    const auto &seq_wrapper = proc->body.front();

    // 4. Return the specific sequential logic (Variant)
    return std::get_if<T>(&seq_wrapper.kind);
}

/// @brief Wraps a concurrent statement string in an architecture and parses it.
template<typename T>
inline auto parseConcurrentStmt(std::string_view stmt) -> const T *
{
    const auto code
      = std::format("entity E is end; architecture A of E is begin {}\n end A;", stmt);

    const auto *arch = parseArchitectureWrapper(code);
    if ((arch == nullptr) || arch->stmts.empty()) {
        return nullptr;
    }

    // 1. Get the ConcurrentStatement wrapper
    const auto &wrapper = arch->stmts.front();

    // 2. Return the specific concurrent logic (Variant)
    return std::get_if<T>(&wrapper.kind);
}

/// Parse a VHDL type declaration string into an AST node.
inline auto parseType(std::string_view type_decl_str) -> const ast::TypeDecl *
{
    // Reuses parseDecl logic as TypeDecl is just a declaration
    return parseDecl<ast::TypeDecl>(type_decl_str);
}

/// Parse a single design unit from code string.
template<typename T>
inline auto parseDesignUnit(std::string_view code) -> const T *
{
    static ast::DesignFile design;
    design = builder::buildFromString(code);
    if (design.units.empty()) {
        return nullptr;
    }
    return std::get_if<T>(&design.units.front());
}

/// @brief Wraps a statement in an architecture and returns the Architecture node.
/// Useful for testing wrappers/labels where we need the container, not just the inner kind.
inline auto parseArchitectureWithStmt(std::string_view stmt) -> const ast::Architecture *
{
    const auto code = std::format(
      "entity E is end; architecture A of E is begin {}\n end A;", stmt);

    return parseDesignUnit<ast::Architecture>(code);
}

} // namespace test_helpers

#endif // TESTS_TEST_HELPERS_HPP
