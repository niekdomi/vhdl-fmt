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

/// @brief Variant type for concurrent statements (outside processes).
using ConcurrentStatement
  = std::variant<ConditionalConcurrentAssign, SelectedConcurrentAssign, Process>;

/// @brief Variant type for sequential statements (inside processes).
using SequentialStatement
  = std::variant<VariableAssign, SignalAssign, IfStatement, CaseStatement, ForLoop, WhileLoop>;

/// @brief Represents the right-hand side of a signal assignment.
///
/// Example: `'1'`, `'0' after 10 ns`, `UNAFFECTED`
struct Waveform : NodeBase
{
    bool is_unaffected{ false }; ///< True if waveform is UNAFFECTED keyword.

    /// @brief Represents a single waveform element.
    struct Element : NodeBase
    {
        Expr value;                ///< Value expression to assign.
        std::optional<Expr> after; ///< Optional delay time (AFTER clause).
    };
    std::vector<Element> elements; ///< List of waveform elements.
};

/// @brief Represents a conditional concurrent signal assignment.
///
/// Example: `target <= val WHEN cond ELSE val;`
struct ConditionalConcurrentAssign : NodeBase
{
    Expr target; ///< Target signal of the assignment.

    /// @brief Represents a waveform with an optional condition.
    struct ConditionalWaveform : NodeBase
    {
        Waveform waveform;             ///< The waveform to assign.
        std::optional<Expr> condition; ///< Optional WHEN condition (none for final ELSE).
    };
    std::vector<ConditionalWaveform> waveforms; ///< List of conditional waveforms.
};

/// @brief Represents a selected concurrent signal assignment.
///
/// Example: `WITH sel SELECT target <= val WHEN choice;`
struct SelectedConcurrentAssign : NodeBase
{
    Expr target;   ///< Target signal of the assignment.
    Expr selector; ///< Selector expression in WITH clause.

    /// @brief Represents a selection branch with choices.
    struct Selection : NodeBase
    {
        Waveform waveform;         ///< The waveform to assign for this selection.
        std::vector<Expr> choices; ///< List of choices (WHEN alternatives).
    };
    std::vector<Selection> selections; ///< List of selection branches.
};

/// @brief Represents a variable assignment statement.
///
/// Example: `target := expr;`
struct VariableAssign : NodeBase
{
    Expr target; ///< Target variable of the assignment.
    Expr value;  ///< Value expression to assign.
};

/// @brief Represents a signal assignment statement.
///
/// Example: `target <= expr;`
struct SignalAssign : NodeBase
{
    Expr target;       ///< Target signal of the assignment.
    Waveform waveform; ///< Waveform to assign.
};

/// @brief Represents an IF statement with optional ELSIF and ELSE branches.
///
/// Example: `if cond then stmts; elsif cond then stmts; else stmts; end if;`
struct IfStatement : NodeBase
{
    /// @brief Represents a branch (if, elsif, or else).
    struct Branch
    {
        Expr condition;                        ///< Branch condition (empty for else branch).
        std::vector<SequentialStatement> body; ///< Statements in the branch.
    };

    Branch if_branch;                   ///< The initial IF branch.
    std::vector<Branch> elsif_branches; ///< ELSIF branches.
    std::optional<Branch> else_branch;  ///< Optional ELSE branch.
};

/// @brief Represents a CASE statement with WHEN clauses.
///
/// Example: `case sel is when "00" => stmts; when others => stmts; end case;`
struct CaseStatement : NodeBase
{
    /// @brief Represents a WHEN clause in a CASE statement.
    struct WhenClause : NodeBase
    {
        std::vector<Expr> choices;             ///< Choice expressions (alternatives).
        std::vector<SequentialStatement> body; ///< Statements for this clause.
    };

    Expr selector;                        ///< Selector expression.
    std::vector<WhenClause> when_clauses; ///< List of WHEN clauses.
};

/// @brief Represents a VHDL process statement.
///
/// Example: `process (clk) begin stmts; end process;`
struct Process : NodeBase
{
    std::optional<std::string> label;          ///< Optional process label.
    std::vector<std::string> sensitivity_list; ///< List of sensitivity signals.
    std::vector<Declaration> decls;            ///< Process declarative items.
    std::vector<SequentialStatement> body;     ///< Sequential statements in process.
};

/// @brief Represents a FOR loop statement.
///
/// Example: `for i in 0 to 7 loop stmts; end loop;`
struct ForLoop : NodeBase
{
    std::string iterator;                  ///< Loop iterator identifier.
    Expr range;                            ///< Loop range expression.
    std::vector<SequentialStatement> body; ///< Loop body statements.
};

/// @brief Represents a WHILE loop statement.
///
/// Example: `while cond loop stmts; end loop;`
struct WhileLoop : NodeBase
{
    Expr condition;                        ///< Loop condition expression.
    std::vector<SequentialStatement> body; ///< Loop body statements.
};

} // namespace ast

#endif /* AST_NODES_STATEMENTS_HPP */
