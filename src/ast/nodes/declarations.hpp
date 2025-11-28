#ifndef AST_NODES_DECLARATIONS_HPP
#define AST_NODES_DECLARATIONS_HPP

#include "ast/node.hpp"
#include "nodes/expressions.hpp"

#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace ast {

// Forward declarations
struct ConstantDecl;
struct SignalDecl;
struct VariableDecl;
struct GenericParam;
struct Port;

/// Variant type for all declarations
using Declaration = std::variant<ConstantDecl, SignalDecl, VariableDecl, GenericParam, Port>;

// Constant declaration: constant WIDTH : integer := 8;
struct ConstantDecl : NodeBase
{
    std::vector<std::string> names;
    std::string type_name;
    std::optional<Expr> init_expr;
};

// Signal declaration: signal v : std_logic_vector(7 downto 0) := (others => '0');
struct SignalDecl : NodeBase
{
    std::vector<std::string> names;
    std::string type_name;
    bool has_bus_kw{ false };
    std::optional<Constraint> constraint;
    std::optional<Expr> init_expr;
};

// Variable declaration: shared variable v : integer := 0;
// (Used inside Processes and Subprograms)
struct VariableDecl : NodeBase
{
    bool shared{ false };
    std::vector<std::string> names;
    std::string type_name;
    std::optional<Constraint> constraint;
    std::optional<Expr> init_expr;
};

// Generic parameter inside GENERIC clause
struct GenericParam : NodeBase
{
    std::vector<std::string> names;
    std::string type_name;
    std::optional<Expr> default_expr;
    bool is_last{};
};

// Port entry inside PORT clause
struct Port : NodeBase
{
    std::vector<std::string> names;
    std::string mode; // "in" / "out"
    std::string type_name;
    std::optional<Expr> default_expr;
    std::optional<Constraint> constraint;
    bool is_last{};
};

} // namespace ast

#endif /* AST_NODES_DECLARATIONS_HPP */
