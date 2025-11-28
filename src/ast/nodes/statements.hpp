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
struct SequentialAssign;
struct IfStatement;
struct CaseStatement;
struct Process;
struct ForLoop;
struct WhileLoop;
struct NullStatement;
struct WaitStatement;
struct ReturnStatement;
struct NextStatement;
struct ExitStatement;
struct ReportStatement;
struct AssertStatement;
struct BreakStatement;
struct ProcedureCall;

/// Variant type for concurrent statements (outside processes)
using ConcurrentStatement = std::variant<ConcurrentAssign, Process>;

/// Variant type for sequential statements (inside processes)
using SequentialStatement = std::variant<SequentialAssign,
                                         IfStatement,
                                         CaseStatement,
                                         ForLoop,
                                         WhileLoop,
                                         NullStatement,
                                         WaitStatement,
                                         ReturnStatement,
                                         NextStatement,
                                         ExitStatement,
                                         ReportStatement,
                                         AssertStatement,
                                         BreakStatement,
                                         ProcedureCall>;

/// @brief Waveform element in a conditional concurrent assignment
struct ConditionalWaveform
{
    Expr value;                    ///< Assigned value
    std::optional<Expr> condition; ///< Optional condition for the waveform (else branch when empty)
};

/// @brief Waveform element in a selected concurrent assignment
struct SelectedWaveform
{
    Expr value;                ///< Assigned value
    std::vector<Expr> choices; ///< Selector choices triggering this waveform
};

/// @brief Concurrent signal assignment: target <= value;
struct ConcurrentAssign : NodeBase
{
    Expr target;
    Expr value;
    std::vector<ConditionalWaveform> conditional_waveforms; ///< Ordered conditional waveforms
    std::optional<Expr> select;                       ///< Selector for with-select assignments
    std::vector<SelectedWaveform> selected_waveforms; ///< Waveforms for each choice set
};

/// @brief Sequential signal/variable assignment: target := value;
struct SequentialAssign : NodeBase
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

/// @brief Null statement: null;
struct NullStatement : NodeBase
{
    // Empty - just a placeholder statement
};

/// @brief Wait statement: wait; | wait until condition; | wait on signals; | wait for time;
struct WaitStatement : NodeBase
{
    std::optional<Expr> condition;             // wait until <condition>
    std::vector<std::string> sensitivity_list; // wait on <signal>, <signal>
    std::optional<Expr> timeout;               // wait for <time>
};

/// @brief Return statement: return; | return expression;
struct ReturnStatement : NodeBase
{
    std::optional<Expr> value; // Optional return value (empty for procedures)
};

/// @brief Next statement: next; | next loop_label; | next when condition;
struct NextStatement : NodeBase
{
    std::optional<std::string> loop_label; // Optional loop label to exit
    std::optional<Expr> condition;         // Optional when condition
};

/// @brief Exit statement: exit; | exit loop_label; | exit when condition;
struct ExitStatement : NodeBase
{
    std::optional<std::string> loop_label; // Optional loop label to exit
    std::optional<Expr> condition;         // Optional when condition
};

/// @brief Report statement: report string_expr severity severity_level;
struct ReportStatement : NodeBase
{
    Expr message;                 // Report message expression
    std::optional<Expr> severity; // Optional severity level
};

/// @brief Assert statement: assert condition report message severity level;
struct AssertStatement : NodeBase
{
    Expr condition;               // Assertion condition
    std::optional<Expr> message;  // Optional report message
    std::optional<Expr> severity; // Optional severity level
};

/// @brief Break statement (VHDL-2008/VHDL-AMS): break; | break when condition; | break elements on
/// condition;
struct BreakStatement : NodeBase
{
    std::vector<Expr> break_elements; // Optional break elements (for VHDL-AMS)
    std::optional<Expr> condition;    // Optional condition (on/when clause)
};

/// @brief Procedure call statement: procedure_name(args);
struct ProcedureCall : NodeBase
{
    Expr call; // Stored as CallExpr in the Expr variant
};

} // namespace ast

#endif /* AST_NODES_STATEMENTS_HPP */
