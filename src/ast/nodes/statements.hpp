#ifndef AST_NODES_STATEMENTS_HPP
#define AST_NODES_STATEMENTS_HPP

#include "ast/node.hpp"
#include "ast/nodes/declarations.hpp"
#include "ast/nodes/expressions.hpp"

#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace ast {

// Forward declarations
struct ConditionalConcurrentAssign;
struct SelectedConcurrentAssign;
struct VariableAssign;
struct SignalAssign;
struct IfStatement;
struct CaseStatement;
struct Process;
struct ForLoop;
struct WhileLoop;

/// Variant type for concurrent statements (outside processes)
using ConcurrentStatement
  = std::variant<ConditionalConcurrentAssign, SelectedConcurrentAssign, Process>;

/// Variant type for sequential statements (inside processes)
using SequentialStatement
  = std::variant<VariableAssign, SignalAssign, IfStatement, CaseStatement, ForLoop, WhileLoop>;

// Matches 'conditional_signal_assignment' rule
// target <= val WHEN cond ELSE val;
struct ConditionalConcurrentAssign : NodeBase
{
    Expr target;
    struct Waveform
    {
        Expr value;
        std::optional<Expr> condition;
    };
    std::vector<Waveform> waveforms;
};

// Matches 'selected_signal_assignment' rule
// WITH sel SELECT target <= val WHEN choice;
struct SelectedConcurrentAssign : NodeBase
{
    Expr target;
    Expr selector; // The "WITH expression" part
    struct Selection
    {
        Expr value;
        std::vector<Expr> choices;
    };
    std::vector<Selection> selections;
};

/// @brief Variable Assignment: target := expr;
struct VariableAssign : NodeBase
{
    Expr target;
    Expr value;
};

/// @brief Signal Assignment: target <= expr;
struct SignalAssign : NodeBase
{
    Expr target;
    Expr value;
};

/// @brief If statement with optional elsif and else branches
struct IfStatement : NodeBase
{
    struct Branch
    {
        std::optional<NodeTrivia> trivia;
        Expr condition; // Empty for else branch
        std::vector<SequentialStatement> body;
    };

    Branch if_branch;                   // The initial if
    std::vector<Branch> elsif_branches; // elsif clauses
    std::optional<Branch> else_branch;  // Optional else
};

/// @brief Case statement with when clauses
struct CaseStatement : NodeBase
{
    struct WhenClause
    {
        std::optional<NodeTrivia> trivia;
        std::vector<Expr> choices;
        std::vector<SequentialStatement> body;
    };

    Expr selector;
    std::vector<WhenClause> when_clauses;
};

/// @brief Process statement
struct Process : NodeBase
{
    std::optional<std::string> label;
    std::vector<std::string> sensitivity_list;
    std::vector<Declaration> decls;
    std::vector<SequentialStatement> body;
};

/// @brief For loop
struct ForLoop : NodeBase
{
    std::string iterator;
    Expr range;
    std::vector<SequentialStatement> body;
};

/// @brief While loop
struct WhileLoop : NodeBase
{
    Expr condition;
    std::vector<SequentialStatement> body;
};

} // namespace ast

#endif /* AST_NODES_STATEMENTS_HPP */
