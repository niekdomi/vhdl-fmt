#ifndef AST_NODES_DECLARATIONS_HPP
#define AST_NODES_DECLARATIONS_HPP

#include "ast/node.hpp"
#include "nodes/expressions.hpp"
#include "nodes/types.hpp"

#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace ast {

/// @brief Represents a generic parameter inside a GENERIC clause.
struct GenericParam : NodeBase
{
    std::vector<std::string> names;
    SubtypeIndication subtype;
    std::optional<Expr> default_expr;
};

/// @brief Represents a port entry inside a PORT clause.
struct Port : NodeBase
{
    std::vector<std::string> names;
    std::string mode;
    SubtypeIndication subtype;
    std::optional<Expr> default_expr;
};

/// @brief Represents a VHDL GENERIC clause.
struct GenericClause : NodeBase
{
    std::vector<GenericParam> generics;
};

/// @brief Represents a VHDL PORT clause.
struct PortClause : NodeBase
{
    std::vector<Port> ports;
};

/// @brief Represents a VHDL constant declaration.
struct ConstantDecl : NodeBase
{
    std::vector<std::string> names;
    SubtypeIndication subtype;
    std::optional<Expr> init_expr;
};

/// @brief Represents a VHDL signal declaration.
struct SignalDecl : NodeBase
{
    std::vector<std::string> names;
    SubtypeIndication subtype;
    std::optional<Expr> init_expr;
    bool has_bus_kw{ false };
};

/// @brief Represents a VHDL variable declaration.
struct VariableDecl : NodeBase
{
    std::vector<std::string> names;
    SubtypeIndication subtype;
    std::optional<Expr> init_expr;
    bool shared{ false };
};

/// @brief Represents a VHDL type declaration.
struct TypeDecl : NodeBase
{
    std::string name;
    std::optional<TypeDefinition> type_def;
};

/// @brief Represents a VHDL component declaration.
struct ComponentDecl : NodeBase
{
    std::string name;
    GenericClause generic_clause;
    PortClause port_clause;
    std::optional<std::string> end_label;
    bool has_is_keyword{ false };
};

/// @brief Variant type for all declarations.
using Declaration = std::
  variant<ConstantDecl, SignalDecl, VariableDecl, TypeDecl, GenericParam, Port, ComponentDecl>;

} // namespace ast

#endif /* AST_NODES_DECLARATIONS_HPP */
