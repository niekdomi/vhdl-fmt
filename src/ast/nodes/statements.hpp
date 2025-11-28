#ifndef AST_NODES_STATEMENTS_HPP
#define AST_NODES_STATEMENTS_HPP

#include "ast/node.hpp"
#include "ast/nodes/expressions.hpp"

#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace ast {

// Forward declarations
struct ConcurrentAssign;
struct VariableAssign;
struct SignalAssign;
struct IfStatement;
struct CaseStatement;
struct Process;
struct ForLoop;
struct WhileLoop;

/// Variant type for concurrent statements (outside processes)
using ConcurrentStatement = std::variant<ConcurrentAssign, Process>;

/// Variant type for sequential statements (inside processes)
using SequentialStatement
  = std::variant<VariableAssign, SignalAssign, IfStatement, CaseStatement, ForLoop, WhileLoop>;

/// @brief Concurrent signal assignment: target <= value;
struct ConcurrentAssign : NodeBase
{
    Expr target;
    Expr value;
};

/// @brief Variable Assignment: target := expr;
struct VariableAssign : NodeBase
{
    Expr target;
    Expr value;
};

/// @brief Signal Assignment: target <= waveform;
/// (Currently simplified to single expr, but ready for expansion)
struct SignalAssign : NodeBase
{
    Expr target;
    Expr value;
    // Future expansion:
    // std::vector<WaveformElement> waveform;
    // std::optional<DelayMechanism> delay;
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
        std::vector<Expr> choices; // Can be multiple: when 1 | 2 | 3 =>
        std::vector<SequentialStatement> body;
    };

    Expr selector; // The expression being switched on
    std::vector<WhenClause> when_clauses;
};

/// @brief Process statement (sensitivity list + sequential statements)
struct Process : NodeBase
{
    std::optional<std::string> label;
    std::vector<std::string> sensitivity_list;
    std::vector<SequentialStatement> body;
};

/// @brief For loop: for i in range loop ... end loop;
struct ForLoop : NodeBase
{
    std::string iterator; // Loop variable name
    Expr range;           // Range expression (e.g., 0 to 10)
    std::vector<SequentialStatement> body;
};

/// @brief While loop: while condition loop ... end loop;
struct WhileLoop : NodeBase
{
    Expr condition;
    std::vector<SequentialStatement> body;
};

} // namespace ast

#endif /* AST_NODES_STATEMENTS_HPP */
