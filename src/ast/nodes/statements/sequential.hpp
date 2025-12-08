#ifndef AST_NODES_STATEMENTS_SEQUENTIAL_HPP
#define AST_NODES_STATEMENTS_SEQUENTIAL_HPP

#include "ast/node.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/waveform.hpp"

#include <optional>
#include <string>
#include <vector>

namespace ast {

// Forward declarations
struct SequentialStatement;

struct SignalAssign : NodeBase
{
    Expr target;
    Waveform waveform;
};

struct VariableAssign : NodeBase
{
    Expr target;
    Expr value;
};

struct IfStatement : NodeBase
{
    struct Branch
    {
        Expr condition;
        std::vector<SequentialStatement> body;
    };

    Branch if_branch;
    std::vector<Branch> elsif_branches;
    std::optional<Branch> else_branch;
};

struct CaseStatement : NodeBase
{
    struct WhenClause : NodeBase
    {
        std::vector<Expr> choices;
        std::vector<SequentialStatement> body;
    };

    Expr selector;
    std::vector<WhenClause> when_clauses;
};

struct Loop : NodeBase
{
    std::optional<std::string> label;
    std::vector<SequentialStatement> body;
};

struct WhileLoop : NodeBase
{
    Expr condition;
    std::vector<SequentialStatement> body;
};

struct ForLoop : NodeBase
{
    std::string iterator;
    Expr range;
    std::vector<SequentialStatement> body;
};

/// @brief Represents a NULL statement.
struct NullStatement : NodeBase
{};

} // namespace ast

#endif /* AST_NODES_STATEMENTS_SEQUENTIAL_HPP */
