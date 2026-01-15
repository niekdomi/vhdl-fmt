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

struct SignalAssign final : NodeBase
{
    Expr target;
    Waveform waveform;
};

struct VariableAssign final : NodeBase
{
    Expr target;
    Expr value;
};

struct IfStatement final : NodeBase
{
    struct ConditionalBranch final : NodeBase
    {
        Expr condition;
        std::vector<SequentialStatement> body;
    };

    struct ElseBranch final : NodeBase
    {
        std::vector<SequentialStatement> body;
    };

    std::vector<ConditionalBranch> branches;
    std::optional<ElseBranch> else_branch;
};

struct CaseStatement final : NodeBase
{
    struct WhenClause final : NodeBase
    {
        std::vector<Expr> choices;
        std::vector<SequentialStatement> body;
    };

    Expr selector;
    std::vector<WhenClause> when_clauses;
};

struct Loop final : NodeBase
{
    std::vector<SequentialStatement> body;
};

struct WhileLoop final : NodeBase
{
    Expr condition;
    std::vector<SequentialStatement> body;
};

struct ForLoop final : NodeBase
{
    std::string iterator;
    Expr range;
    std::vector<SequentialStatement> body;
};

/// @brief Represents a NULL statement.
struct NullStatement final : NodeBase
{};

// TODO(vedivad): Report, Next, Exit, Return, Wait statements.

} // namespace ast

#endif /* AST_NODES_STATEMENTS_SEQUENTIAL_HPP */
