#ifndef AST_NODES_STATEMENTS_HPP
#define AST_NODES_STATEMENTS_HPP

#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/sequential.hpp"

#include <variant>

namespace ast {

// Forward declarations
struct ConcurrentStatement;
struct SequentialStatement;

struct ConcurrentStatement final
  : std::variant<ConditionalConcurrentAssign, SelectedConcurrentAssign, Process>
{
    using variant::variant; // Inherit constructors
};

struct SequentialStatement final
  : std::variant<VariableAssign,
                 SignalAssign,
                 IfStatement,
                 CaseStatement,
                 ForLoop,
                 WhileLoop,
                 Loop,
                 NullStatement>
{
    using variant::variant; // Inherit constructors
};

} // namespace ast

#endif /* AST_NODES_STATEMENTS_HPP */
