#include "ast/nodes/declarations.hpp"

#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/declarations/objects.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <ranges>
#include <string>

namespace emit {

/// @brief Named constants for common alignment columns used in declarations.
struct AlignmentLevel
{
    static constexpr int NAME = 0; ///< Column 0: Used for names (port, generic, signal, etc.)
    static constexpr int MODE = 1; ///< Column 1: Used for mode (port modes like "in", "out", etc.)
};

auto PrettyPrinter::operator()(const ast::GenericParam &node, const bool is_last) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    Doc result = Doc::text(names, AlignmentLevel::NAME) & Doc::text(":") & visit(node.subtype);

    if (node.default_expr) {
        result &= Doc::text(":=") & visit(node.default_expr.value());
    }

    return is_last ? result : result + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::Port &node, const bool is_last) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    Doc result = Doc::text(names, AlignmentLevel::NAME)
               & Doc::text(":")
               & Doc::keyword(node.mode, AlignmentLevel::MODE)
               & visit(node.subtype);

    if (node.default_expr) {
        result &= Doc::text(":=") & visit(node.default_expr.value());
    }

    return is_last ? result : result + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::SignalDecl &node) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    Doc result = Doc::keyword(("signal")) & Doc::text(names, AlignmentLevel::NAME) & Doc::text(":");

    // Type definition
    result &= visit(node.subtype);

    if (node.has_bus_kw) {
        result &= Doc::keyword(("bus"));
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
      = Doc::keyword(("constant")) & Doc::text(names, AlignmentLevel::NAME) & Doc::text(":");

    result &= visit(node.subtype);

    if (node.init_expr) {
        result &= Doc::text(":=") & visit(node.init_expr.value());
    }

    return result + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::VariableDecl &node) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    // "variable x, y : integer"
    Doc result = (node.shared ? (Doc::keyword(("shared")) & Doc::keyword(("variable")))
                              : Doc::keyword(("variable")))
               & Doc::text(names, AlignmentLevel::NAME)
               & Doc::text(":")
               & visit(node.subtype);

    if (node.init_expr) {
        result &= Doc::text(":=") & visit(node.init_expr.value());
    }

    return result + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::TypeDecl &node) const -> Doc
{
    Doc result = Doc::keyword(("type")) & Doc::text(node.name);

    if (!node.type_def.has_value()) {
        // Incomplete type declaration: "type <name>;"
        return result + Doc::text(";");
    }

    // "is <definition>"
    result &= Doc::keyword(("is")) & visit(node.type_def.value());

    return result + Doc::text(";");
}

} // namespace emit
