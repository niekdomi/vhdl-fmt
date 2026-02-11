#ifndef AST_NODES_SUBPROGRAM_HPP
#define AST_NODES_SUBPROGRAM_HPP

#include "ast/node.hpp"
#include "ast/nodes/expressions.hpp"

#include <optional>
#include <string>
#include <vector>

namespace ast {

/// @brief Represents a formal parameter in a subprogram
struct FormalParam final : NodeBase
{
    std::vector<std::string> names;
    std::optional<std::string> mode; // "in", "out", "inout", or none for functions
    SubtypeIndication subtype;
    std::optional<Expr> default_expr;
};

/// @brief Represents a VHDL function declaration (no body)
struct FunctionDecl final : NodeBase
{
    std::string name;
    std::vector<FormalParam> parameters;
    SubtypeIndication return_type;
    bool is_pure{true}; // true for pure, false for impure
};

/// @brief Represents a VHDL procedure declaration (no body)
struct ProcedureDecl final : NodeBase
{
    std::string name;
    std::vector<FormalParam> parameters;
};

// TODO: Add FunctionBody and ProcedureBody later - they need full Declaration support

} // namespace ast

#endif /* AST_NODES_SUBPROGRAM_HPP */
