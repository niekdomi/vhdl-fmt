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
struct LibraryClause;
struct UseClause;
struct ComponentDecl;

/// @brief Variant type for architecture declarative items (preserves order).
///
/// Example: `ConstantDecl`, `SignalDecl`, `ComponentDecl`
using DeclarativeItem = std::variant<Declaration, ComponentDecl>;

/// @brief Variant type for all design units (holds values, not pointers).
///
/// Example: `Entity` or `Architecture`
using DesignUnit = std::variant<Entity, Architecture>;

/// @brief Variant type for context items (library and use clauses).
///
/// Example: `LibraryClause` or `UseClause`
using ContextItem = std::variant<LibraryClause, UseClause>;

/// @brief Represents a VHDL GENERIC clause.
///
/// Example: `generic (WIDTH : integer := 8);`
struct GenericClause : NodeBase
{
    std::vector<GenericParam> generics; ///< List of generic parameters.
};

/// @brief Represents a VHDL LIBRARY clause.
///
/// Example: `library ieee;`
struct LibraryClause : NodeBase
{
    std::vector<std::string> logical_names; ///< List of library names.
};

/// @brief Represents a VHDL PORT clause.
///
/// Example: `port (clk : in std_logic; data : out std_logic_vector);`
struct PortClause : NodeBase
{
    std::vector<Port> ports; ///< List of port declarations.
};

/// @brief Represents a VHDL USE clause.
///
/// Example: `use ieee.std_logic_1164.all;`
struct UseClause : NodeBase
{
    std::vector<std::string> selected_names; ///< List of selected names (dot-separated).
};

/// @brief Represents a VHDL architecture body.
///
/// Example: `architecture rtl of counter is begin process(clk) begin end process; end architecture
/// rtl;`
struct Architecture : NodeBase
{
    std::vector<ContextItem> context;           ///< Library and use clauses.
    std::string name;                           ///< Architecture identifier.
    std::string entity_name;                    ///< Name of the associated entity.
    std::vector<DeclarativeItem> decls;         ///< Architecture declarative items.
    std::vector<ConcurrentStatement> stmts;     ///< Architecture concurrent statements.
    std::optional<std::string> end_label;       ///< Optional label after END keyword.
    bool has_end_architecture_keyword{ false }; ///< Whether END ARCHITECTURE syntax is used.
};

/// @brief Represents a VHDL component declaration.
///
/// Example: `component my_comp is generic (WIDTH : integer); port (clk : in std_logic); end
/// component;`
struct ComponentDecl : NodeBase
{
    std::string name;                     ///< Component identifier.
    GenericClause generic_clause;         ///< Generic parameters clause.
    PortClause port_clause;               ///< Port declarations clause.
    std::optional<std::string> end_label; ///< Optional label after END COMPONENT.
    bool has_is_keyword{ false };         ///< Whether IS keyword is present.
};

/// @brief Represents a VHDL entity declaration.
///
/// Example: `entity counter is port (clk : in std_logic); end entity counter;`
struct Entity : NodeBase
{
    std::vector<ContextItem> context;       ///< Library and use clauses.
    std::string name;                       ///< Entity identifier.
    GenericClause generic_clause;           ///< Generic parameters clause.
    PortClause port_clause;                 ///< Port declarations clause.
    std::vector<Declaration> decls;         ///< Entity declarative items.
    std::vector<ConcurrentStatement> stmts; ///< Entity concurrent statements.
    std::optional<std::string> end_label;   ///< Optional label after END keyword.
    bool has_end_entity_keyword{ false };   ///< Whether END ENTITY syntax is used.
};

} // namespace ast

#endif /* AST_NODES_ENTITY_HPP */
