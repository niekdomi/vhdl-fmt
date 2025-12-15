#ifndef EMIT_DOC_HPP
#define EMIT_DOC_HPP

#include <memory>
#include <string_view>
#include <utility>

// Forward declarations
namespace common {
struct Config;
} // namespace common

namespace emit {

struct DocImpl;
using DocPtr = std::shared_ptr<DocImpl>;

/// @brief An immutable abstraction for a pretty-printable document.
/// @note This class is a lightweight handle (PImpl pattern) to the underlying
///       document structure (DocImpl).
class Doc final
{
  public:
    // ========================================================================
    // Static Factories (Document Primitives)
    // ========================================================================

    /// @brief Returns a document that is always empty.
    static auto empty() -> Doc;

    /// @brief Creates a document from a string.
    /// @note The text must not contain newlines.
    static auto text(std::string_view str) -> Doc;

    /// @brief Creates a document from a string.
    /// @note The text must not contain newlines.
    /// @param level The level of the document.
    static auto text(std::string_view str, int level) -> Doc;

    /// @brief Creates a document from a keyword.
    /// @note The text must not contain newlines.
    static auto keyword(std::string_view str) -> Doc;

    /// @brief Creates a document from a keyword.
    /// @note The text must not contain newlines.
    /// @param level The level of the document.
    static auto keyword(std::string_view str, int level) -> Doc;

    /// @brief A "soft" line break. Renders as a space if it fits,
    ///        or a newline and indent if in "break" mode.
    static auto line() -> Doc;

    /// @brief A "hard" line break. Always renders as a newline.
    static auto hardline() -> Doc;

    /// @brief Multiple "hard" line breaks. Always renders as newlines.
    /// @param count The number of hard line breaks to insert.
    /// @note Can be zero to mark something that should not break.
    static auto hardlines(unsigned count) -> Doc;

    // ========================================================================
    // Low-Level Combinators (Operators)
    // ========================================================================

    /// @brief Concatenates two documents directly. (a + b)
    auto operator+(const Doc &other) const -> Doc;

    /// @brief Concatenates two documents with a space. (a & b)
    /// @note Equivalent to `a + Doc::text(" ") + b`.
    auto operator&(const Doc &other) const -> Doc;

    /// @brief Concatenates two documents with a soft line. (a / b)
    /// @note Equivalent to `a + Doc::line() + b`.
    auto operator/(const Doc &other) const -> Doc;

    /// @brief Concatenates two documents with a hard line. (a | b)
    /// @note Equivalent to `a + Doc::hardline() + b`.
    auto operator|(const Doc &other) const -> Doc;

    /// @brief Nests the right-hand document after a soft line. (a << b)
    /// @note Equivalent to `a + (Doc::line() + b).nest()`.
    auto operator<<(const Doc &other) const -> Doc;

    /// @brief Nests the right-hand document after a hard line.
    /// @note Equivalent to `a + (Doc::hardline() + b).nest()`.
    [[nodiscard]]
    auto hardIndent(const Doc &other) const -> Doc;

    // ========================================================================
    // Compound Assignment Operators
    // ========================================================================

    /// @brief Direct concatenation assignment.
    auto operator+=(const Doc &other) -> Doc &;
    /// @brief Space concatenation assignment.
    auto operator&=(const Doc &other) -> Doc &;
    /// @brief Softline concatenation assignment.
    auto operator/=(const Doc &other) -> Doc &;
    /// @brief Hardline concatenation assignment.
    auto operator|=(const Doc &other) -> Doc &;
    /// @brief Softline + indent assignment.
    auto operator<<=(const Doc &other) -> Doc &;

    // ========================================================================
    // High-Level Layout Patterns
    // ========================================================================

    /// @brief Groups a document, giving the renderer a choice.
    /// @param doc The document to group.
    /// @return A `Union` node representing a choice between the "flat"
    ///         version of this Doc and the "broken" (original) version.
    [[nodiscard]]
    static auto group(const Doc &doc) -> Doc;

    /// @brief A common "bracket" pattern: (left, inner, right).
    /// @note This is equivalent to `(left << inner) / right`.
    [[nodiscard]]
    static auto bracket(const Doc &left, const Doc &inner, const Doc &right) -> Doc;

    /// @brief Defines a scope for alignment.
    /// @param doc The document sub-tree containing `Doc::alignText` texts.
    /// @return A new `Doc` node that instructs the renderer to process
    ///         alignment for the `doc` sub-tree.
    [[nodiscard]]
    static auto align(const Doc &doc) -> Doc;

    /// @brief Sets the indentation level of the document to the current column.
    /// @param doc The document to hang.
    /// @return A `Hang` node.
    [[nodiscard]]
    static auto hang(const Doc &doc) -> Doc;

    // ========================================================================
    // Utility
    // ========================================================================

    /// @brief Checks if the document is an Empty node.
    /// @return True if the document is 'Doc::empty()', false otherwise.
    [[nodiscard]]
    auto isEmpty() const -> bool;

    /// @brief Access the underlying DocImpl pointer.
    [[nodiscard]]
    auto getImpl() const -> DocPtr
    {
        return impl_;
    }

  private:
    /// @brief Private constructor for internal factory functions.
    explicit Doc(std::shared_ptr<DocImpl> impl) : impl_(std::move(impl)) {}

    std::shared_ptr<DocImpl> impl_;
};

} // namespace emit

#endif // EMIT_DOC_HPP
