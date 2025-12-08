#ifndef TESTS_AST_NODES_STATEMENTS_STMT_UTILS_HPP
#define TESTS_AST_NODES_STATEMENTS_STMT_UTILS_HPP

#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "builder/ast_builder.hpp"

#include <format>
#include <string_view>
#include <variant>

namespace stmt_utils {

/// @brief Wraps a sequential statement string in a process and parses it.
template<typename T>
inline auto parseSequential(std::string_view stmt) -> const T *
{
    const auto code = std::format(
      "entity E is end; architecture A of E is begin process begin {}\n end process; end A;", stmt);

    static ast::DesignFile design;
    design = builder::buildFromString(code);

    // Get Architecture
    if (design.units.size() < 2) {
        return nullptr;
    }
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    if ((arch == nullptr) || arch->stmts.empty()) {
        return nullptr;
    }

    // Get Process (It's the first concurrent statement)
    const auto *proc = std::get_if<ast::Process>(&arch->stmts.front());
    if ((proc == nullptr) || proc->body.empty()) {
        return nullptr;
    }

    // Get Sequential Statement
    const auto *seq_stmt_variant = &proc->body.front();

    return std::get_if<T>(seq_stmt_variant);
}

/// @brief Wraps a concurrent statement string in an architecture and parses it.
template<typename T>
inline auto parseConcurrent(std::string_view stmt) -> const T *
{
    const auto code
      = std::format("entity E is end; architecture A of E is begin {}\n end A;", stmt);

    static ast::DesignFile design;
    design = builder::buildFromString(code);

    // Get Architecture
    if (design.units.size() < 2) {
        return nullptr;
    }
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    if ((arch == nullptr) || arch->stmts.empty()) {
        return nullptr;
    }

    // Get Concurrent Statement
    const auto *conc_stmt_variant = &arch->stmts.front();

    return std::get_if<T>(conc_stmt_variant);
}

} // namespace stmt_utils

#endif // TESTS_AST_NODES_STATEMENTS_STMT_UTILS_HPP
