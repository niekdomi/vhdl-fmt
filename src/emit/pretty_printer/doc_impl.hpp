#ifndef EMIT_DOC_IMPL_HPP
#define EMIT_DOC_IMPL_HPP

#include <memory>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>
#include <variant>

namespace emit {

// Forward declaration for recursive type
struct DocImpl;
using DocPtr = std::shared_ptr<DocImpl>;

/// Empty document
struct Empty
{};

/// Text (no newlines allowed)
struct Text
{
    std::string content;
    int level{ -1 };
};

struct Keyword
{
    std::string content;
    int level{ -1 };
};

/// Line break (space when flattened, newline when broken)
struct SoftLine
{};

/// Hard line break (always newline, never becomes space)
struct HardLine
{};

/// Multiple hard line breaks
struct HardLines
{
    unsigned count{};
};

/// Concatenation of two documents
struct Concat
{
    DocPtr left;
    DocPtr right;
};

/// Increase indentation level
struct Nest
{
    DocPtr doc;
};

/// Set indentation level to the current column
struct Hang
{
    DocPtr doc;
};

/// Choice between flat and broken layout
struct Union
{
    DocPtr flat;
    DocPtr broken;
};

struct Align
{
    DocPtr doc;
};

/// Internal document representation using variant
struct DocImpl
{
    std::
      variant<Empty, Text, Keyword, SoftLine, HardLine, HardLines, Concat, Nest, Hang, Union, Align>
        value;
};

// Helper trait to check if T is one of the types in the list
template<typename T, typename... Types>
inline constexpr bool IS_ANY_OF_V = (std::is_same_v<T, Types> || ...);

template<typename Node, typename Fn>
auto mapChildren(const Node &node, Fn fn) -> Node
{
    using T = std::decay_t<Node>;

    if constexpr (std::is_same_v<T, Concat>) {
        return Concat{ .left = fn(node.left), .right = fn(node.right) };
    } else if constexpr (std::is_same_v<T, Union>) {
        return Union{ .flat = fn(node.flat), .broken = fn(node.broken) };
    } else if constexpr (IS_ANY_OF_V<T, Nest, Hang, Align>) {
        return T{ .doc = fn(node.doc) };
    } else {
        return node;
    }
}

template<typename Node, typename Acc, typename Fn>
auto foldChildren(const Node &node, Acc init, Fn fn) -> Acc
{
    using T = std::decay_t<Node>;

    if constexpr (std::is_same_v<T, Concat>) {
        init = fn(node.left, std::move(init));
        return fn(node.right, std::move(init));
    } else if constexpr (std::is_same_v<T, Union>) {
        return fn(node.broken, std::move(init));
    } else if constexpr (IS_ANY_OF_V<T, Nest, Hang, Align>) {
        return fn(node.doc, std::move(init));
    } else {
        return init;
    }
}

template<typename Node, typename Fn>
void traverseChildren(const Node &node, const Fn &fn)
{
    using T = std::decay_t<Node>;

    if constexpr (std::is_same_v<T, Concat>) {
        fn(node.left);
        fn(node.right);
    } else if constexpr (std::is_same_v<T, Union>) {
        // Same as fold, only analyze the 'broken' branch
        fn(node.broken);
    } else if constexpr (IS_ANY_OF_V<T, Nest, Hang, Align>) {
        fn(node.doc);
    }
    // Leaf nodes (Text, Empty, etc.) have no children to traverse
}

/// @brief Recursive document transformer
template<typename Fn>
auto transformImpl(const DocPtr &doc, const Fn &fn) -> DocPtr
{
    if (!doc) {
        return doc;
    }

    return std::visit(
      [&](const auto &node) -> DocPtr {
          auto new_node
            = mapChildren(node, [&](const DocPtr &child) { return transformImpl(child, fn); });
          return fn(std::move(new_node));
      },
      doc->value);
}

/// @brief Recursive document folder
template<typename T, typename Fn>
auto foldImpl(const DocPtr &doc, T init, const Fn &fn) -> T
{
    if (!doc) {
        return init;
    }

    return std::visit(
      [&](const auto &node) -> T {
          T acc = fn(std::move(init), node);
          return foldChildren(node, std::move(acc), [&](const DocPtr &child, T inner_acc) {
              return foldImpl(child, std::move(inner_acc), fn);
          });
      },
      doc->value);
}

/// @brief Recursive document traversal for side-effect operations
template<typename Fn>
void traverseImpl(const DocPtr &doc, const Fn &fn)
{
    if (!doc) {
        return;
    }

    std::visit(
      [&](const auto &node) {
          fn(node);
          traverseChildren(node, [&](const DocPtr &child) { traverseImpl(child, fn); });
      },
      doc->value);
}

// Factory functions for creating documents
auto makeEmpty() -> DocPtr;
auto makeText(std::string_view text) -> DocPtr;
auto makeText(std::string_view text, int level) -> DocPtr;
auto makeKeyword(std::string_view text) -> DocPtr;
auto makeKeyword(std::string_view text, int level) -> DocPtr;
auto makeLine() -> DocPtr;
auto makeHardLine() -> DocPtr;
auto makeHardLines(unsigned count) -> DocPtr;
auto makeConcat(DocPtr left, DocPtr right) -> DocPtr;
auto makeNest(DocPtr doc) -> DocPtr;
auto makeHang(DocPtr doc) -> DocPtr;
auto makeUnion(DocPtr flat, DocPtr broken) -> DocPtr;
auto makeAlignText(DocPtr doc) -> DocPtr;
auto makeAlign(DocPtr doc) -> DocPtr;

// Utility functions
auto flatten(const DocPtr &doc) -> DocPtr;
auto resolveAlignment(const DocPtr &doc) -> DocPtr;

} // namespace emit

#endif // EMIT_DOC_IMPL_HPP