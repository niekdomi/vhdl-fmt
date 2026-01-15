#ifndef AST_NODES_STATEMENTS_CONCURRENT_HPP
#define AST_NODES_STATEMENTS_CONCURRENT_HPP

#include "ast/node.hpp"
#include "ast/nodes/declarations.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/waveform.hpp"

#include <optional>
#include <string>
#include <vector>

namespace ast {

// Forward declarations
struct SequentialStatement;

struct ConditionalConcurrentAssign final : NodeBase
{
    std::optional<std::string> label;
    Expr target;

    struct ConditionalWaveform final : NodeBase
    {
        Waveform waveform;
        std::optional<Expr> condition;
    };
    std::vector<ConditionalWaveform> waveforms;
};

struct SelectedConcurrentAssign final : NodeBase
{
    std::optional<std::string> label;
    Expr target;
    Expr selector;

    struct Selection : NodeBase
    {
        Waveform waveform;
        std::vector<Expr> choices;
    };
    std::vector<Selection> selections;
};

struct Process final : NodeBase
{
    std::optional<std::string> label;
    std::vector<std::string> sensitivity_list;
    std::vector<Declaration> decls;
    std::vector<SequentialStatement> body;
};

} // namespace ast

#endif /* AST_NODES_STATEMENTS_CONCURRENT_HPP */
