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

/// @brief Variant type for all design units (holds values, not pointers).
using DesignUnit = std::variant<Entity, Architecture>;

/// @brief Represents a VHDL GENERIC clause.
///
/// Example: `generic (WIDTH : integer := 8);`
struct GenericClause : NodeBase
{
    std::vector<GenericParam> generics; ///< List of generic parameters.
};

/// @brief Represents a VHDL PORT clause.
///
/// Example: `port (clk : in std_logic; data : out std_logic_vector);`
struct PortClause : NodeBase
{
    std::vector<Port> ports; ///< List of port declarations.
};

/// @brief Represents a VHDL entity declaration.
///
/// Example: `entity counter is port (clk : in std_logic); end entity;`
struct Entity : NodeBase
{
    std::string name;                       ///< Entity identifier.
    GenericClause generic_clause;           ///< Generic parameters clause.
    PortClause port_clause;                 ///< Port declarations clause.
    std::vector<Declaration> decls;         ///< Entity declarative items.
    std::vector<ConcurrentStatement> stmts; ///< Entity concurrent statements.
    std::optional<std::string> end_label;   ///< Optional label after END keyword.
    bool has_end_entity_keyword = false;    ///< Whether END ENTITY syntax is used.
};

/// @brief Represents a VHDL architecture body.
///
/// Example: `architecture rtl of counter is begin end architecture;`
struct Architecture : NodeBase
{
    std::string name;                           ///< Architecture identifier.
    std::string entity_name;                    ///< Name of the associated entity.
    std::vector<Declaration> decls;             ///< Architecture declarative items.
    std::vector<ConcurrentStatement> stmts;     ///< Architecture concurrent statements.
    std::optional<std::string> end_label;       ///< Optional label after END keyword.
    bool has_end_architecture_keyword = false;  ///< Whether END ARCHITECTURE syntax is used.
};

} // namespace ast

#endif /* AST_NODES_ENTITY_HPP */
