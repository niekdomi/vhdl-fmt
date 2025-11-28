#ifndef EMIT_PRETTY_PRINTER_HPP
#define EMIT_PRETTY_PRINTER_HPP

#include "ast/node.hpp"
#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "ast/visitor.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <utility>

namespace emit {

/// @brief Helper concept to identify AST nodes that are Expressions.
/// Used to suppress breaks (blank lines) within expressions for tighter formatting.
template<typename T>
concept IsExpression = std::is_same_v<T, ast::TokenExpr>
                    || std::is_same_v<T, ast::GroupExpr>
                    || std::is_same_v<T, ast::UnaryExpr>
                    || std::is_same_v<T, ast::BinaryExpr>
                    || std::is_same_v<T, ast::ParenExpr>
                    || std::is_same_v<T, ast::CallExpr>;

class PrettyPrinter final : public ast::VisitorBase<Doc>
{
  private:
    // Node visitors
    auto operator()(const ast::DesignFile &node) const -> Doc;
    auto operator()(const ast::Entity &node) const -> Doc;
    auto operator()(const ast::Architecture &node) const -> Doc;
    auto operator()(const ast::GenericClause &node) const -> Doc;
    auto operator()(const ast::PortClause &node) const -> Doc;
    auto operator()(const ast::GenericParam &node) const -> Doc;
    auto operator()(const ast::Port &node) const -> Doc;

    // Declarations
    auto operator()(const ast::SignalDecl &node) const -> Doc;
    auto operator()(const ast::ConstantDecl &node) const -> Doc;
    auto operator()(const ast::VariableDecl &node) const -> Doc;

    // Expressions
    auto operator()(const ast::TokenExpr &node) const -> Doc;
    auto operator()(const ast::GroupExpr &node) const -> Doc;
    auto operator()(const ast::UnaryExpr &node) const -> Doc;
    auto operator()(const ast::BinaryExpr &node) const -> Doc;
    auto operator()(const ast::ParenExpr &node) const -> Doc;
    auto operator()(const ast::CallExpr &node) const -> Doc;

    // Constraints
    auto operator()(const ast::IndexConstraint &node) const -> Doc;
    auto operator()(const ast::RangeConstraint &node) const -> Doc;

    // Concurrent Statements
    auto operator()(const ast::ConditionalConcurrentAssign &node) const -> Doc;
    auto operator()(const ast::SelectedConcurrentAssign &node) const -> Doc;
    auto operator()(const ast::Process &node) const -> Doc;

    // Sequential Statements
    auto operator()(const ast::SignalAssign &node) const -> Doc;
    auto operator()(const ast::VariableAssign &node) const -> Doc;
    auto operator()(const ast::IfStatement &node) const -> Doc;
    auto operator()(const ast::CaseStatement &node) const -> Doc;
    auto operator()(const ast::ForLoop &node) const -> Doc;
    auto operator()(const ast::WhileLoop &node) const -> Doc;

    /// @brief Wraps the core doc with trivia for the given node.
    template<typename T>
    auto wrapResult(const T &node, Doc result) const -> Doc
    {
        return withTrivia(node, std::move(result), IsExpression<T>);
    }

    /// @brief Combines the core doc with leading, inline, and trailing trivia.
    /// @param suppress_newlines If true, Break trivia (blank lines) will be ignored.
    [[nodiscard]]
    static auto withTrivia(const ast::NodeBase &node, Doc core_doc, bool suppress_newlines) -> Doc;

    // Allow base class to call `wrapResult`, so `wrapResult` can be private
    friend class ast::VisitorBase<Doc>;
};

} // namespace emit

#endif // EMIT_PRETTY_PRINTER_HPP
