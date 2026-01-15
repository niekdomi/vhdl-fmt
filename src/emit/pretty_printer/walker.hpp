#ifndef EMIT_PRETTY_PRINTER_WALKER_HPP
#define EMIT_PRETTY_PRINTER_WALKER_HPP

#include "emit/pretty_printer/doc_impl.hpp"

#include <type_traits>
#include <utility>
#include <variant>

namespace emit {

// Helper trait to check if T is one of the types in the list
template<typename T, typename... Types>
inline constexpr bool IS_ANY_OF_V = (std::is_same_v<T, Types> || ...);

struct DocWalker
{
    /// @brief Maps the children of a node using the provided function
    template<typename Node, typename Fn>
    static auto mapChildren(const Node& node, Fn fn) -> Node
    {
        using T = std::decay_t<Node>;

        if constexpr (std::is_same_v<T, Concat>) {
            return Concat{.left = fn(node.left), .right = fn(node.right)};
        } else if constexpr (std::is_same_v<T, Union>) {
            return Union{.flat = fn(node.flat), .broken = fn(node.broken)};
        } else if constexpr (IS_ANY_OF_V<T, Nest, Hang, Align>) {
            return T{.doc = fn(node.doc)};
        } else {
            return node;
        }
    }

    /// @brief Folds over the children of a node using the provided function
    template<typename Node, typename Acc, typename Fn>
    static auto foldChildren(const Node& node, Acc init, Fn fn) -> Acc
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

    /// @brief Traverses the children of a node using the provided function
    template<typename Node, typename Fn>
    static auto traverseChildren(const Node& node, const Fn& fn) -> void
    {
        using T = std::decay_t<Node>;

        if constexpr (std::is_same_v<T, Concat>) {
            fn(node.left);
            fn(node.right);
        } else if constexpr (std::is_same_v<T, Union>) {
            // Standard traversal typically follows the 'broken' (expanded) path
            fn(node.broken);
        } else if constexpr (IS_ANY_OF_V<T, Nest, Hang, Align>) {
            fn(node.doc);
        }
        // Leaf nodes (Text, Empty, etc.) have no children to traverse
    }

    /// @brief Recursive document transformer
    template<typename Fn>
    static auto transform(const DocPtr& doc, const Fn& fn) -> DocPtr
    {
        if (!doc) {
            return doc;
        }

        return std::visit(
          [&](const auto& node) -> DocPtr {
              // Recursively map children first (Bottom-Up)
              auto new_node =
                mapChildren(node, [&](const DocPtr& child) { return transform(child, fn); });
              // Then apply the transformer to the new node
              return fn(std::move(new_node));
          },
          doc->value);
    }

    /// @brief Recursive document folder
    template<typename T, typename Fn>
    static auto fold(const DocPtr& doc, T init, const Fn& fn) -> T
    {
        if (!doc) {
            return init;
        }

        return std::visit(
          [&](const auto& node) -> T {
              T acc = fn(std::move(init), node);
              return foldChildren(node, std::move(acc), [&](const DocPtr& child, T inner_acc) {
                  return fold(child, std::move(inner_acc), fn);
              });
          },
          doc->value);
    }

    /// @brief Recursive document traversal for side-effect operations
    template<typename Fn>
    static auto traverse(const DocPtr& doc, const Fn& fn) -> void
    {
        if (!doc) {
            return;
        }

        std::visit(
          [&](const auto& node) {
              fn(node);
              traverseChildren(node, [&](const DocPtr& child) { traverse(child, fn); });
          },
          doc->value);
    }
};

} // namespace emit

#endif // EMIT_PRETTY_PRINTER_WALKER_HPP
