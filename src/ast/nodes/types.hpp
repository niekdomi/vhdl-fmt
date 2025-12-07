#ifndef AST_NODES_TYPES_HPP
#define AST_NODES_TYPES_HPP

#include "ast/node.hpp"
#include "nodes/expressions.hpp"

#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace ast {

/// @brief Represents an enumeration type definition.
struct EnumerationTypeDef : NodeBase
{
    std::vector<std::string> literals;
};

/// @brief Represents an element in a VHDL record type definition.
struct RecordElement : NodeBase
{
    std::vector<std::string> names;
    std::string type_name;
    std::optional<Constraint> constraint;
};

/// @brief Represents a record type definition.
struct RecordTypeDef : NodeBase
{
    std::vector<RecordElement> elements;
    std::optional<std::string> end_label;
};

struct ArrayTypeDef : NodeBase
{
    // TODO(vedivad): Complete this
    std::string element_type;
    std::vector<std::string> index_types;
};

// Represents "access my_type"
struct AccessTypeDef : NodeBase
{
    std::string pointed_type;
};

struct FileTypeDef : NodeBase
{
    std::string content_type;
};

/// @brief Variant for the *structure* of a type.
using TypeDefinition
  = std::variant<EnumerationTypeDef, RecordTypeDef, ArrayTypeDef, AccessTypeDef, FileTypeDef>;

} // namespace ast

#endif
