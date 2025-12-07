#ifndef AST_NODES_DESIGN_UNITS_HPP
#define AST_NODES_DESIGN_UNITS_HPP

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
struct LibraryClause;
struct UseClause;

/// @brief Variant type for all design units.
using DesignUnit = std::variant<Entity, Architecture>;

/// @brief Variant type for context items.
using ContextItem = std::variant<LibraryClause, UseClause>;

/// @brief Represents a VHDL LIBRARY clause.
struct LibraryClause : NodeBase
{
    std::vector<std::string> logical_names;
};

/// @brief Represents a VHDL USE clause.
struct UseClause : NodeBase
{
    std::vector<std::string> selected_names;
};

/// @brief Represents a VHDL entity declaration.
struct Entity : NodeBase
{
    std::vector<ContextItem> context;
    std::string name;
    GenericClause generic_clause;
    PortClause port_clause;
    std::vector<Declaration> decls;
    std::vector<ConcurrentStatement> stmts;
    std::optional<std::string> end_label;
    bool has_end_entity_keyword{ false };
};

/// @brief Represents a VHDL architecture body.
struct Architecture : NodeBase
{
    std::vector<ContextItem> context;
    std::string name;
    std::string entity_name;
    std::vector<Declaration> decls;
    std::vector<ConcurrentStatement> stmts;
    std::optional<std::string> end_label;
    bool has_end_architecture_keyword{ false };
};

} // namespace ast

#endif /* AST_NODES_DESIGN_UNITS_HPP */
