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
struct ContextDeclaration;

/// Variant type for all design units (holds values, not pointers)
using DesignUnit = std::variant<Entity, Architecture, ContextDeclaration>;

struct GenericClause : NodeBase
{
    std::vector<GenericParam> generics;
};

struct PortClause : NodeBase
{
    std::vector<Port> ports;
};

// Context item types (library clause, use clause, context reference)
struct LibraryClause : NodeBase
{
    std::vector<std::string> logical_names; // library ieee, std;
};

struct UseClause : NodeBase
{
    std::vector<std::string> selected_names; // use ieee.std_logic_1164.all;
};

struct ContextReference : NodeBase
{
    std::vector<std::string> selected_names; // context IP_lib.IP_context;
};

// Context item variant - used in context declarations
using ContextItem = std::variant<LibraryClause, UseClause, ContextReference>;

struct Entity : NodeBase
{
    std::string name;
    GenericClause generic_clause;
    PortClause port_clause;
    std::vector<Declaration> decls;
    std::vector<ConcurrentStatement> stmts;
    std::optional<std::string> end_label;
};

struct Architecture : NodeBase
{
    std::string name;
    std::string entity_name;
    std::vector<Declaration> decls;
    std::vector<ConcurrentStatement> stmts;
};

struct ContextDeclaration : NodeBase
{
    std::string name;
    std::vector<ContextItem> items;
};

} // namespace ast

#endif /* AST_NODES_ENTITY_HPP */
