#ifndef AST_NODES_STATEMENTS_WAVEFORM_HPP
#define AST_NODES_STATEMENTS_WAVEFORM_HPP

#include "ast/node.hpp"
#include "ast/nodes/expressions.hpp"

#include <optional>
#include <vector>

namespace ast {

/// @brief Represents the right-hand side of a signal assignment.
struct Waveform final : NodeBase
{
    bool is_unaffected{false};

    struct Element final : NodeBase
    {
        Expr value;
        std::optional<Expr> after;
    };

    std::vector<Element> elements;
};

} // namespace ast

#endif /* AST_NODES_STATEMENTS_WAVEFORM_HPP */
