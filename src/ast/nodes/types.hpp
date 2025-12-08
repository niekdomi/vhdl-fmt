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
    SubtypeIndication subtype;
};

/// @brief Represents a record type definition.
struct RecordTypeDef : NodeBase
{
    std::vector<RecordElement> elements;
    std::optional<std::string> end_label;
};

/// @brief Represents a single dimension in an array definition.
using ArrayDimension = std::variant<std::string, Expr>;

struct ArrayTypeDef : NodeBase
{
    SubtypeIndication subtype;
    std::vector<ArrayDimension> indices;
};

// Represents "access my_type"
struct AccessTypeDef : NodeBase
{
    SubtypeIndication subtype;
};

struct FileTypeDef : NodeBase
{
    SubtypeIndication subtype;
};

/// @brief Variant for the *structure* of a type.
using TypeDefinition
  = std::variant<EnumerationTypeDef, RecordTypeDef, ArrayTypeDef, AccessTypeDef, FileTypeDef>;

} // namespace ast

#endif
