#include "ast/nodes/declarations/subprogram.hpp"

#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::FormalParam& node, const bool is_last) const -> Doc
{
    const std::string names =
      node.names | std::views::join_with(std::string_view{", "}) | std::ranges::to<std::string>();

    Doc result = Doc::text(names) & Doc::text(":");

    if (node.mode) {
        result &= Doc::keyword(*node.mode);
    }

    result &= visit(node.subtype);

    if (node.default_expr) {
        result &= Doc::text(":=") & visit(*node.default_expr);
    }

    return is_last ? result : result + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::FunctionDecl& node) const -> Doc
{
    Doc result = Doc::empty();

    if (!node.is_pure) {
        result += Doc::keyword("impure") & Doc::empty();
    }

    result += Doc::keyword("function") & Doc::text(node.name);

    if (!node.parameters.empty()) {
        const Doc params = joinMap(node.parameters, Doc::text(" "), [&](const auto& param) {
            const bool is_last = &param == &node.parameters.back();
            return visit(param, is_last);
        });

        result += Doc::text("(") + params + Doc::text(")");
    }

    result &= Doc::keyword("return") & visit(node.return_type);
    result += Doc::text(";");

    return result;
}

auto PrettyPrinter::operator()(const ast::ProcedureDecl& node) const -> Doc
{
    Doc result = Doc::keyword("procedure") & Doc::text(node.name);

    if (!node.parameters.empty()) {
        const Doc params = joinMap(node.parameters, Doc::text(" "), [&](const auto& param) {
            const bool is_last = &param == &node.parameters.back();
            return visit(param, is_last);
        });

        result += Doc::text("(") + params + Doc::text(")");
    }

    result += Doc::text(";");

    return result;
}

// TODO: Implement FunctionBody and ProcedureBody pretty printers

} // namespace emit
