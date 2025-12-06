#ifndef AST_NODES_DECLARATIONS_HPP
#define AST_NODES_DECLARATIONS_HPP

#include "ast/node.hpp"
#include "nodes/expressions.hpp"

#include <cstdint>
#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace ast {

// Forward declarations
struct ConstantDecl;
struct GenericParam;
struct Port;
struct RecordElement;
struct SignalDecl;
struct TypeDecl;
struct VariableDecl;

/// @brief Variant type for all declarations.
///
/// Example: `ConstantDecl`, `SignalDecl`, `VariableDecl`, or `TypeDecl`
using Declaration
  = std::variant<ConstantDecl, SignalDecl, VariableDecl, TypeDecl, GenericParam, Port>;

/// @brief Represents a VHDL constant declaration.
///
/// Example: `constant WIDTH : integer := 8;`
struct ConstantDecl : NodeBase
{
    std::vector<std::string> names; ///< List of constant identifiers.
    std::string type_name;          ///< Type of the constant.
    std::optional<Expr> init_expr;  ///< Optional initialization expression.
};

/// @brief Represents a generic parameter inside a GENERIC clause.
///
/// Example: `WIDTH : integer := 8`
struct GenericParam : NodeBase
{
    std::vector<std::string> names;   ///< List of generic parameter identifiers.
    std::string type_name;            ///< Type of the generic parameter.
    std::optional<Expr> default_expr; ///< Optional default value expression.
};

/// @brief Represents a port entry inside a PORT clause.
///
/// Example: `clk : in std_logic`
struct Port : NodeBase
{
    std::vector<std::string> names;       ///< List of port identifiers.
    std::string mode;                     ///< Port mode: "in", "out", "inout", or "buffer".
    std::string type_name;                ///< Type of the port.
    std::optional<Expr> default_expr;     ///< Optional default value expression.
    std::optional<Constraint> constraint; ///< Optional type constraint.
};

/// @brief Represents a VHDL signal declaration.
///
/// Example: `signal clk, reset : std_logic := '0';`
struct SignalDecl : NodeBase
{
    std::vector<std::string> names;       ///< List of signal identifiers.
    std::string type_name;                ///< Type of the signal.
    std::optional<Constraint> constraint; ///< Optional type constraint (e.g., range).
    std::optional<Expr> init_expr;        ///< Optional initialization expression.
    bool has_bus_kw{ false };             ///< Whether the BUS keyword is present.
};

/// @brief Represents a VHDL variable declaration.
///
/// Example: `variable counter : integer := 0;`
struct VariableDecl : NodeBase
{
    std::vector<std::string> names;       ///< List of variable identifiers.
    std::string type_name;                ///< Type of the variable.
    std::optional<Constraint> constraint; ///< Optional type constraint.
    std::optional<Expr> init_expr;        ///< Optional initialization expression.
    bool shared{ false };                 ///< Whether the SHARED keyword is present.
};

/// @brief Type kind enumeration for VHDL type declarations.
enum class TypeKind : std::uint8_t
{
    ENUMERATION, ///< Enumeration type: (VALUE1, VALUE2, ...)
    RECORD,      ///< Record type: record ... end record
    OTHER        ///< Other types (array, access, file, range, etc.) - stored as text
};

/// @brief Represents an element in a VHDL record type definition.
///
/// Example: `state : ctrl_state_t;` inside a record
struct RecordElement : NodeBase
{
    std::vector<std::string> names;       ///< List of element identifiers.
    std::string type_name;                ///< Type of the element.
    std::optional<Constraint> constraint; ///< Optional type constraint.
};

/// @brief Represents a VHDL type declaration.
///
/// Example: `type ctrl_state_t is (S_IDLE, S_BUSY);`
/// Example: `type ctrl_engine_t is record state : ctrl_state_t; end record;`
struct TypeDecl : NodeBase
{
    std::string name;                           ///< Type identifier.
    TypeKind kind{ TypeKind::OTHER };           ///< Kind of type definition.
    std::vector<std::string> enum_literals;     ///< For enumeration types.
    std::vector<RecordElement> record_elements; ///< For record types.
    std::string other_definition;               ///< For other types, raw text.
    std::optional<std::string> end_label;       ///< Optional label after END RECORD.
};

} // namespace ast

#endif /* AST_NODES_DECLARATIONS_HPP */
