#ifndef AST_NODES_INTERFACE_HPP
#define AST_NODES_INTERFACE_HPP

#include "ast/node.hpp"
#include "nodes/expressions.hpp"

#include <optional>
#include <string>
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

} // namespace ast

#endif /* AST_NODES_INTERFACE_HPP */
