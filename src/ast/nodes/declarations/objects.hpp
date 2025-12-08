#ifndef AST_NODES_OBJECTS_HPP
#define AST_NODES_OBJECTS_HPP

#include "ast/node.hpp"
#include "nodes/expressions.hpp"

#include <optional>
#include <string>
#include <vector>

namespace ast {

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

/// @brief Represents a VHDL constant declaration.
struct ConstantDecl : NodeBase
{
    std::vector<std::string> names;
    SubtypeIndication subtype;
    std::optional<Expr> init_expr;
};

} // namespace ast

#endif // AST_NODES_OBJECTS_HPP
