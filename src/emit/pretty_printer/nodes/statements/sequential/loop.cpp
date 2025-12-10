#include "ast/nodes/statements/sequential.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::ForLoop &node) const -> Doc
{
    const Doc head = Doc::keyword(("for"))
                   & Doc::text(node.iterator)
                   & Doc::keyword(("in"))
                   & visit(node.range)
                   & Doc::keyword(("loop"));

    const Doc body = join(node.body, Doc::line());
    const Doc end = Doc::keyword(("end")) & Doc::keyword(("loop")) + Doc::text(";");

    return Doc::bracket(head, body, end);
}

auto PrettyPrinter::operator()(const ast::WhileLoop &node) const -> Doc
{
    const Doc head = Doc::keyword(("while")) & visit(node.condition) & Doc::keyword(("loop"));
    const Doc body = join(node.body, Doc::line());
    const Doc end = Doc::keyword(("end")) & Doc::keyword(("loop")) + Doc::text(";");

    return Doc::bracket(head, body, end);
}

auto PrettyPrinter::operator()(const ast::Loop &node) const -> Doc
{
    Doc head = Doc::keyword(("loop"));

    const Doc body = join(node.body, Doc::line());
    const Doc end = Doc::keyword(("end")) & Doc::keyword(("loop")) + Doc::text(";");

    return Doc::bracket(head, body, end);
}

} // namespace emit
