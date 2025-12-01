#ifndef EMIT_DOC_HPP
#define EMIT_DOC_HPP

#include <memory>
#include <string>
#include <string_view>
#include <utility>

// Forward declarations
namespace common {
struct Config;
} // namespace common

namespace emit {

struct DocImpl;
using DocPtr = std::shared_ptr<DocImpl>;

template<typename Fn>
auto transformImpl(const DocPtr &doc, Fn &&fn) -> DocPtr;

template<typename T, typename Fn>
auto foldImpl(const DocPtr &doc, T init, Fn &&fn) -> T;

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

    /// @brief A "soft" line break. Renders as a space if it fits,
    ///        or a newline and indent if in "break" mode.
    static auto line() -> Doc;

    /// @brief A "hard" line break. Always renders as a newline.
    static auto hardline() -> Doc;

    /// @brief Multiple "hard" line breaks. Always renders as newlines.
    /// @param count The number of hard line breaks to insert.
    /// @note Can be zero to mark something that should not break.
    static auto hardlines(unsigned count) -> Doc;

    /// @brief Creates a special text for alignment.
    /// @note The renderer will append spaces based on other
    ///       texts within the same alignment group.
    /// @param str The text content for this text.
    /// @param level An integer key that defines the alignment group.
    static auto alignText(std::string_view str, int level) -> Doc;

    /// @brief Creates an inline comment document.
    /// @param text The comment text.
    /// @return A Doc representing the inline comment.
    static auto inlineComment(std::string_view text) -> Doc;

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
    // Tree Traversal & Analysis
    // ========================================================================

    /// @brief Recursively transforms the document tree.
    /// @param fn A callable that takes a `DocImpl` variant node (e.g., `Text`,
    ///           `Concat`) and returns a new `DocPtr`.
    /// @return A new `Doc` with the transformed structure.
    template<typename Fn>
    auto transform(Fn &&fn) const -> Doc
    {
        return Doc(transformImpl(impl_, std::forward<Fn>(fn)));
    }

    /// @brief Folds (reduces) the document tree into a single value.
    /// @tparam T The type of the accumulated value.
    /// @param init The initial value for the accumulator.
    /// @param fn A callable: `T f(T accumulator, const auto& node_variant)`
    /// @return The final accumulated value.
    template<typename T, typename Fn>
    auto fold(T init, Fn &&fn) const -> T
    {
        return foldImpl(impl_, std::move(init), std::forward<Fn>(fn));
    }

    // ========================================================================
    // Rendering
    // ========================================================================

    /// @brief Renders the document to a string based on the given config.
    /// @param config The configuration containing layout rules (line width, etc.)
    [[nodiscard]]
    auto render(const common::Config &config) const -> std::string;

    /// @brief Checks if the document is an Empty node.
    /// @return True if the document is 'Doc::empty()', false otherwise.
    [[nodiscard]]
    auto isEmpty() const -> bool;

  private:
    /// @brief Private constructor for internal factory functions.
    explicit Doc(std::shared_ptr<DocImpl> impl) : impl_(std::move(impl)) {}

    std::shared_ptr<DocImpl> impl_;
};

} // namespace emit

#endif // EMIT_DOC_HPP
