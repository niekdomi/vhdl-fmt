#ifndef AST_NODES_DESIGN_UNITS_HPP
#define AST_NODES_DESIGN_UNITS_HPP

#include "ast/node.hpp"
#include "ast/nodes/declarations.hpp"
#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/statements.hpp"

#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace ast {

// Forward declarations
struct LibraryClause;
struct UseClause;

/// @brief Variant type for context items.
using ContextItem = std::variant<LibraryClause, UseClause>;

/// @brief Represents a VHDL LIBRARY clause.
struct LibraryClause final : NodeBase
{
    std::vector<std::string> logical_names;
};

/// @brief Represents a VHDL USE clause.
struct UseClause final : NodeBase
{
    std::vector<std::string> selected_names;
};

/// @brief Represents a VHDL entity declaration.
struct Entity final : NodeBase
{
    std::string name;
    GenericClause generic_clause;
    PortClause port_clause;
    std::vector<Declaration> decls;
    std::vector<ConcurrentStatement> stmts;
    std::optional<std::string> end_label;
    bool has_end_entity_keyword{false};
};

/// @brief Represents a VHDL architecture body.
struct Architecture final : NodeBase
{
    std::string name;
    std::string entity_name;
    std::vector<Declaration> decls;
    std::vector<ConcurrentStatement> stmts;
    std::optional<std::string> end_label;
    bool has_end_architecture_keyword{false};
};

/// @brief Variant representing the specific unit type
using LibraryUnit = std::variant<Entity, Architecture>;

/// @brief Struct matching the grammar rule: design_unit : context_clause library_unit
struct DesignUnit final : NodeBase
{
    std::vector<ContextItem> context;
    LibraryUnit unit;
};

} // namespace ast

#endif /* AST_NODES_DESIGN_UNITS_HPP */
