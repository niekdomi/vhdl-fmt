#ifndef AST_NODES_STATEMENTS_HPP
#define AST_NODES_STATEMENTS_HPP

#include "ast/node.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/sequential.hpp"

#include <optional>
#include <string>
#include <variant>

namespace ast {

// Concurrent Statements
using ConcurrentStmtKind =
  std::variant<ConditionalConcurrentAssign, SelectedConcurrentAssign, Process>;

struct ConcurrentStatement final : NodeBase
{
    std::optional<std::string> label; ///< Optional label (e.g. "label: entity...")
    ConcurrentStmtKind kind;          ///< The actual statement logic
};

// Sequential Statements
using SequentialStmtKind = std::variant<VariableAssign,
                                        SignalAssign,
                                        IfStatement,
                                        CaseStatement,
                                        ForLoop,
                                        WhileLoop,
                                        Loop,
                                        NullStatement>;

struct SequentialStatement final : NodeBase
{
    std::optional<std::string> label; ///< Optional label (e.g. "label: entity...")
    SequentialStmtKind kind;          ///< The actual statement logic
};

} // namespace ast

#endif /* AST_NODES_STATEMENTS_HPP */
