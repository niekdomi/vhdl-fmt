#ifndef AST_NODES_DESIGN_FILE_HPP
#define AST_NODES_DESIGN_FILE_HPP

#include "ast/node.hpp"
#include "ast/nodes/design_units.hpp"

#include <vector>

namespace ast {

/// @brief Represents the root node of a VHDL design file.
///
/// Example: A file containing an entity and its architecture.
struct DesignFile : NodeBase
{
    std::vector<DesignUnit> units; ///< List of design units in the file.
};

} // namespace ast

#endif /* AST_NODES_DESIGN_FILE_HPP */
