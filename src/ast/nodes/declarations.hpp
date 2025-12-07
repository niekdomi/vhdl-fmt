#ifndef AST_NODES_DECLARATIONS_HPP
#define AST_NODES_DECLARATIONS_HPP

#include "ast/node.hpp"
#include "nodes/declarations/interface.hpp"
#include "nodes/declarations/objects.hpp"
#include "nodes/types.hpp"

#include <optional>
#include <string>

namespace ast {

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
using Declaration = std::variant<ConstantDecl, SignalDecl, VariableDecl, TypeDecl, ComponentDecl>;

} // namespace ast

#endif /* AST_NODES_DECLARATIONS_HPP */
