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

auto PrettyPrinter::operator()([[maybe_unused]] const ast::SignalDecl &node) const -> Doc
{
    // TODO(vedivad): Implement signal declaration printing
    return Doc::text("-- signal");
}

auto PrettyPrinter::operator()([[maybe_unused]] const ast::ConstantDecl &node) const -> Doc
{
    // TODO(vedivad): Implement constant declaration printing
    return Doc::text("-- constant");
}

auto PrettyPrinter::operator()([[maybe_unused]] const ast::AliasDecl &node) const -> Doc
{
    // TODO(vedivad): Implement alias declaration printing
    return Doc::text("-- alias");
}

auto PrettyPrinter::operator()([[maybe_unused]] const ast::TypeDecl &node) const -> Doc
{
    // TODO(vedivad): Implement type declaration printing
    return Doc::text("-- type");
}

auto PrettyPrinter::operator()([[maybe_unused]] const ast::SubtypeDecl &node) const -> Doc
{
    // TODO(vedivad): Implement subtype declaration printing
    return Doc::text("-- subtype");
}

auto PrettyPrinter::operator()(const ast::SubprogramParam &node) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    Doc result = Doc::text(names);

    if (!node.mode.empty() || !node.type_name.empty()) {
        result &= Doc::text(":");
        if (!node.mode.empty()) {
            result &= Doc::text(node.mode);
        }
        if (!node.type_name.empty()) {
            result &= Doc::text(node.type_name);
        }
    }

    if (node.default_expr) {
        result &= Doc::text(":=") & visit(node.default_expr.value());
    }

    if (!node.is_last) {
        result += Doc::text(";");
    }

    return result;
}

auto PrettyPrinter::operator()([[maybe_unused]] const ast::ProcedureDecl &node) const -> Doc
{
    // TODO(domi): Implement procedure declaration printing
    return Doc::text("-- procedure " + node.name);
}

auto PrettyPrinter::operator()([[maybe_unused]] const ast::FunctionDecl &node) const -> Doc
{
    // TODO(domi): Implement function declaration printing
    return Doc::text("-- function " + node.name);
}

} // namespace emit
