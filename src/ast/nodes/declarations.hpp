#ifndef AST_NODES_DECLARATIONS_HPP
#define AST_NODES_DECLARATIONS_HPP

#include "ast/node.hpp"
#include "nodes/expressions.hpp"
#include "nodes/statements.hpp"

#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace ast {

// Forward declarations
struct ConstantDecl;
struct SignalDecl;
struct GenericParam;
struct Port;
struct AliasDecl;
struct TypeDecl;
struct SubtypeDecl;
struct SubprogramParam;
struct ProcedureDecl;
struct FunctionDecl;

/// Variant type for all declarations
using Declaration = std::variant<ConstantDecl,
                                 SignalDecl,
                                 GenericParam,
                                 Port,
                                 AliasDecl,
                                 TypeDecl,
                                 SubtypeDecl,
                                 ProcedureDecl,
                                 FunctionDecl>;

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

// Alias declaration: alias byte_data : std_logic_vector(7 downto 0) is data;
struct AliasDecl : NodeBase
{
    std::string name;
    std::string type_name;
    Expr target; // The aliased object (can be a name, slice, etc.)
};

// Type declaration: type state_t is (IDLE, RUNNING, DONE);
struct TypeDecl : NodeBase
{
    std::string name;
    // Type definition stored as generic Expr for now
    // Could be an enumeration, array type, record type, etc.
    std::optional<Expr> definition;
};

// Subtype declaration: subtype small_int is integer range 0 to 100;
struct SubtypeDecl : NodeBase
{
    std::string name;
    std::string base_type;
    std::optional<Constraint> constraint;
};

// Subprogram parameter (procedure/function)
struct SubprogramParam : NodeBase
{
    std::vector<std::string> names;
    std::string mode; // in/out/inout/buffer/ linkage depending on decl
    std::string type_name;
    std::optional<Expr> default_expr;
    bool is_last{};
};

// Procedure declaration/body
struct ProcedureDecl : NodeBase
{
    std::string name;
    std::vector<SubprogramParam> parameters;
    std::vector<Declaration> decls;
    std::vector<SequentialStatement> body;
};

// Function declaration/body
struct FunctionDecl : NodeBase
{
    std::string name;
    std::vector<SubprogramParam> parameters;
    std::string return_type;
    std::vector<Declaration> decls;
    std::vector<SequentialStatement> body;
};

} // namespace ast

#endif /* AST_NODES_DECLARATIONS_HPP */
