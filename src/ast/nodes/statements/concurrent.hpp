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
    Expr target;
    Expr selector;

    struct Selection final : NodeBase
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

struct ComponentInstantiation final : NodeBase
{
    std::string entity_name;
    std::optional<std::string> architecture;
    bool is_entity{false};
    std::vector<Expr> generic_map;
    std::vector<Expr> port_map;
};

} // namespace ast

#endif /* AST_NODES_STATEMENTS_CONCURRENT_HPP */
