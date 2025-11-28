#include "ast/nodes/declarations.hpp"

#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <ranges>
#include <string>

namespace emit {

/// @brief Named constants for common alignment columns used in declarations.
struct AlignmentLevel
{
    static constexpr int NAME = 0; ///< Column 0: Used for names (port, generic, signal, etc.)
    static constexpr int TYPE = 1; ///< Column 1: Used for mode/type (port mode, type name)
};

auto PrettyPrinter::operator()(const ast::GenericParam &node) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    Doc result = Doc::alignText(names, AlignmentLevel::NAME)
               & Doc::text(":")
               & Doc::alignText(node.type_name, AlignmentLevel::TYPE);

    if (node.default_expr) {
        result &= Doc::text(":=") & visit(node.default_expr.value());
    }

    if (!node.is_last) {
        result += Doc::text(";");
    }

    return result;
}

auto PrettyPrinter::operator()(const ast::Port &node) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    Doc result = Doc::alignText(names, AlignmentLevel::NAME)
               & Doc::text(":")
               & Doc::alignText(node.mode, AlignmentLevel::TYPE)
               & Doc::text(node.type_name);

    // Constraint (e.g., (7 downto 0) or range 0 to 255)
    if (node.constraint) {
        result += visit(node.constraint.value());
    }

    if (node.default_expr) {
        result &= Doc::text(":=") & visit(node.default_expr.value());
    }

    if (!node.is_last) {
        result += Doc::text(";");
    }

    return result;
}

auto PrettyPrinter::operator()(const ast::SignalDecl &node) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    Doc result = Doc::text("signal") & Doc::alignText(names, AlignmentLevel::NAME) & Doc::text(":");

    // Type definition
    result &= Doc::alignText(node.type_name, AlignmentLevel::TYPE);

    if (node.constraint) {
        result += visit(node.constraint.value());
    }

    if (node.has_bus_kw) {
        result &= Doc::text("bus");
    }

    // Initialization
    if (node.init_expr) {
        result &= Doc::text(":=") & visit(node.init_expr.value());
    }

    return result + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::ConstantDecl &node) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    Doc result
      = Doc::text("constant") & Doc::alignText(names, AlignmentLevel::NAME) & Doc::text(":");

    result &= Doc::alignText(node.type_name, AlignmentLevel::TYPE);

    if (node.init_expr) {
        result &= Doc::text(":=") & visit(node.init_expr.value());
    }

    return result + Doc::text(";");
}

} // namespace emit
