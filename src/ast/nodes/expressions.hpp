#ifndef AST_NODES_EXPRESSIONS_HPP
#define AST_NODES_EXPRESSIONS_HPP

#include "ast/node.hpp"

#include <memory>
#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace ast {

// Forward declarations
struct AttributeExpr;
struct BinaryExpr;
struct CallExpr;
struct GroupExpr;
struct ParenExpr;
struct PhysicalLiteral;
struct QualifiedExpr;
struct SliceExpr;
struct TokenExpr;
struct UnaryExpr;

/// @brief Helper alias for boxed recursive types.
///
/// Example: `Box<Expr>` wraps an expression in a unique_ptr
/// @tparam T The type to wrap in a unique_ptr.
template<typename T>
using Box = std::unique_ptr<T>;

/// @brief Variant type for all expressions (holds values, not pointers).
///
/// Example: `TokenExpr`, `BinaryExpr`, or `CallExpr`
using Expr = std::variant<TokenExpr,
                          GroupExpr,
                          UnaryExpr,
                          BinaryExpr,
                          ParenExpr,
                          CallExpr,
                          SliceExpr,
                          AttributeExpr,
                          QualifiedExpr,
                          PhysicalLiteral>;

/// @brief Represents a binary expression.
///
/// Example: `a + b`, `x downto 0`, `a and b`
struct BinaryExpr : NodeBase
{
    Box<Expr> left;  ///< Left operand (boxed for recursion).
    std::string op;  ///< Binary operator symbol.
    Box<Expr> right; ///< Right operand (boxed for recursion).
};

/// @brief Represents a function call.
///
/// Example: `rising_edge(clk)`, `resize(data, 16)`
struct CallExpr : NodeBase
{
    Box<Expr> callee;    ///< Function name being called.
    Box<GroupExpr> args; ///< Arguments (always a GroupExpr with parentheses).
};

/// @brief Represents array/signal slice notation.
///
/// Example: `data(7 downto 0)`, `mem(i)`
struct SliceExpr : NodeBase
{
    Box<Expr> prefix; ///< Array/signal being sliced.
    Box<Expr> range;  ///< Index or range expression.
};

/// @brief Represents an aggregate or grouped list of expressions.
///
/// Example: `(others => '0')`
struct GroupExpr : NodeBase
{
    std::vector<Expr> children; ///< Ordered child expressions.
};

/// @brief Represents explicit parentheses around an expression.
///
/// Example: `(a + b)`
struct ParenExpr : NodeBase
{
    Box<Expr> inner; ///< Inner expression inside parentheses (boxed for recursion).
};

/// @brief Represents a physical literal with value and unit.
///
/// Example: `10 ns`, `5 us`
struct PhysicalLiteral : NodeBase
{
    std::string value; ///< Numeric value (e.g., "10").
    std::string unit;  ///< Unit identifier (e.g., "ns").
};

/// @brief Represents a single token expression.
///
/// Example: `WIDTH`, `'1'`, `123`
struct TokenExpr : NodeBase
{
    std::string text; ///< Literal text of the token.
};

/// @brief Represents a unary expression.
///
/// Example: `-a`, `not ready`, `abs x`
struct UnaryExpr : NodeBase
{
    std::string op;  ///< Unary operator symbol.
    Box<Expr> value; ///< Operand expression (boxed for recursion).
};

/// @brief Represents an attribute reference.
///
/// Example: `data'length`, `clk'event`, `signal_name'stable(5 ns)`
struct AttributeExpr : NodeBase
{
    Box<Expr> prefix;             ///< Base expression (signal, type, array, etc.).
    std::string attribute;        ///< Attribute name (e.g., "length", "event", "stable").
    std::optional<Box<Expr>> arg; ///< Optional parameter for attributes like 'stable(5 ns).
};

/// @brief Represents a qualified expression (type qualification).
///
/// Example: `std_logic_vector'(x"AB")`, `integer'(42)`
struct QualifiedExpr : NodeBase
{
    std::string type_mark; ///< Type qualifier/mark (e.g., "std_logic_vector", "integer").
    Box<Expr> operand;     ///< Expression being qualified (aggregate or parenthesized expression).
};

// -------------------------------------------------------

/// @brief Represents an index constraint with parentheses.
///
/// Example: `(7 downto 0)`, `(0 to 15, 0 to 7)`
struct IndexConstraint : NodeBase
{
    GroupExpr ranges; ///< Parenthesized group of range expressions.
};

/// @brief Represents a range constraint with RANGE keyword.
///
/// Example: `range 0 to 255`
struct RangeConstraint : NodeBase
{
    BinaryExpr range; ///< Single range expression (e.g., "0 to 255" or "7 downto 0").
};

/// @brief Variant type for constraints used in type declarations.
using Constraint = std::variant<IndexConstraint, RangeConstraint>;

} // namespace ast

#endif /* AST_NODES_EXPRESSIONS_HPP */
