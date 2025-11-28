#ifndef AST_NODES_EXPRESSIONS_HPP
#define AST_NODES_EXPRESSIONS_HPP

#include "ast/node.hpp"

#include <memory>
#include <string>
#include <variant>
#include <vector>

namespace ast {

// Forward declarations
struct TokenExpr;
struct GroupExpr;
struct UnaryExpr;
struct BinaryExpr;
struct ParenExpr;
struct CallExpr;
struct PhysicalLiteral;

/// Helper alias for boxed recursive types
template<typename T>
using Box = std::unique_ptr<T>;

/// Variant type for all expressions (holds values, not pointers)
using Expr
  = std::variant<TokenExpr, GroupExpr, UnaryExpr, BinaryExpr, ParenExpr, CallExpr, PhysicalLiteral>;

/// Single token: literal, identifier, or operator.
struct TokenExpr : NodeBase
{
    std::string text; ///< Literal text of the token.
};

/// Physical literal (e.g. "10 ns")
/// distinct from TokenExpr because it is composed of two tokens separated by space.
struct PhysicalLiteral : NodeBase
{
    std::string value; // e.g. "10"
    std::string unit;  // e.g. "ns"
};

/// Aggregate or grouped list of expressions (e.g. `(others => '0')`).
struct GroupExpr : NodeBase
{
    std::vector<Expr> children; ///< Ordered child expressions.
};

/// Unary expression (e.g. `-a`, `not ready`).
struct UnaryExpr : NodeBase
{
    std::string op;  ///< Unary operator symbol.
    Box<Expr> value; ///< Operand expression (boxed for recursion).
};

/// Binary expression (e.g. `a + b`, `x downto 0`).
struct BinaryExpr : NodeBase
{
    Box<Expr> left;  ///< Left operand (boxed for recursion).
    std::string op;  ///< Binary operator symbol.
    Box<Expr> right; ///< Right operand (boxed for recursion).
};

/// Explicit parentheses around an expression (e.g. `(a + b)`).
struct ParenExpr : NodeBase
{
    Box<Expr> inner; ///< Inner expression inside parentheses (boxed for recursion).
};

/// Function call or indexed name (e.g. `rising_edge(clk)`, `data(7 downto 0)`).
/// Note: VHDL doesn't syntactically distinguish function calls from array indexing.
struct CallExpr : NodeBase
{
    Box<Expr> callee; ///< Function/array name being called/indexed.
    Box<Expr> args;   ///< Arguments (single expr or GroupExpr for multiple args).
};

// Forward declarations for constraints
struct IndexConstraint;
struct RangeConstraint;

/// Variant type for constraints used in type declarations
using Constraint = std::variant<IndexConstraint, RangeConstraint>;

/// Index constraint with parentheses: (7 downto 0) or (0 to 15, 0 to 7)
/// Grammar: LPAREN discrete_range (COMMA discrete_range)* RPAREN
/// Uses GroupExpr to represent the parenthesized list of ranges
struct IndexConstraint : NodeBase
{
    GroupExpr ranges; ///< Parenthesized group of range expressions
};

/// Range constraint with RANGE keyword: range 0 to 255
/// Grammar: RANGE range_decl
/// Note: The RANGE keyword is implicit in the constraint type, not stored
struct RangeConstraint : NodeBase
{
    BinaryExpr range; ///< Single range expression (e.g., "0 to 255" or "7 downto 0")
};

} // namespace ast

#endif /* AST_NODES_EXPRESSIONS_HPP */
