#ifndef AST_NODES_ENTITY_HPP
#define AST_NODES_ENTITY_HPP

#include "ast/node.hpp"
#include "ast/nodes/declarations.hpp"
#include "ast/nodes/statements.hpp"

#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace ast {

// Forward declarations
struct Entity;
struct Architecture;

/// Variant type for all design units (holds values, not pointers)
using DesignUnit = std::variant<Entity, Architecture>;

struct GenericClause : NodeBase
{
    std::vector<GenericParam> generics;
};

struct PortClause : NodeBase
{
    std::vector<Port> ports;
};

struct Entity : NodeBase
{
    std::string name;
    GenericClause generic_clause;
    PortClause port_clause;
    std::vector<Declaration> decls;
    std::vector<ConcurrentStatement> stmts;
    std::optional<std::string> end_label;
    bool has_end_entity_keyword = false;
};

struct Architecture : NodeBase
{
    std::string name;
    std::string entity_name;
    std::vector<Declaration> decls;
    std::vector<ConcurrentStatement> stmts;
    std::optional<std::string> end_label;
    bool has_end_architecture_keyword = false;
};

} // namespace ast

#endif /* AST_NODES_ENTITY_HPP */
