#ifndef EMIT_DOC_IMPL_HPP
#define EMIT_DOC_IMPL_HPP

#include "common/overload.hpp"

#include <memory>
#include <string>
#include <string_view>
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

struct AlignText
{
    std::string content;
    int level{};
};

struct Align
{
    DocPtr doc;
};

/// Internal document representation using variant
struct DocImpl
{
    std::variant<Empty,
                 Text,
                 SoftLine,
                 HardLine,
                 HardLines,
                 Concat,
                 Nest,
                 Hang,
                 Union,
                 AlignText,
                 Align>
      value;
};

/// Recursive document transformer
template<typename Fn>
auto transformImpl(const DocPtr &doc, Fn &&fn) -> DocPtr
{
    if (!doc) {
        return doc;
    }

    return std::visit(
      common::Overload(
        [&fn](const Concat &node) -> DocPtr {
            return std::forward<Fn>(fn)(Concat{ .left = transformImpl(node.left, fn),
                                                .right = transformImpl(node.right, fn) });
        },
        [&fn](const Union &node) -> DocPtr {
            return std::forward<Fn>(fn)(Union{ .flat = transformImpl(node.flat, fn),
                                               .broken = transformImpl(node.broken, fn) });
        },
        [&fn](const Nest &node) -> DocPtr {
            return std::forward<Fn>(fn)(Nest{ .doc = transformImpl(node.doc, fn) });
        },
        [&fn](const Hang &node) -> DocPtr {
            return std::forward<Fn>(fn)(Hang{ .doc = transformImpl(node.doc, fn) });
        },
        [&fn](const Align &node) -> DocPtr {
            return std::forward<Fn>(fn)(Align{ .doc = transformImpl(node.doc, fn) });
        },
        [&fn](const auto &node) -> DocPtr {
            // Leaf nodes (Text, Empty, etc.) are just passed through to the function
            return std::forward<Fn>(fn)(node);
        }),
      doc->value);
}

template<typename T, typename Fn>
auto foldImpl(const DocPtr &doc, T init, Fn &&fn) -> T
{
    if (!doc) {
        return init;
    }

    return std::visit(common::Overload(
                        [&](const Concat &node) -> T {
                            T acc = std::forward<Fn>(fn)(std::move(init), node);
                            acc = foldImpl(node.left, std::move(acc), fn);
                            return foldImpl(node.right, std::move(acc), fn);
                        },
                        [&](const Union &node) -> T {
                            T acc = std::forward<Fn>(fn)(std::move(init), node);
                            // Only the broken branch is to be considered for folding
                            return foldImpl(node.broken, std::move(acc), fn);
                        },
                        [&](const Nest &node) -> T {
                            T acc = std::forward<Fn>(fn)(std::move(init), node);
                            return foldImpl(node.doc, std::move(acc), fn);
                        },
                        [&](const Hang &node) -> T {
                            T acc = std::forward<Fn>(fn)(std::move(init), node);
                            return foldImpl(node.doc, std::move(acc), fn);
                        },
                        [&](const Align &node) -> T {
                            T acc = std::forward<Fn>(fn)(std::move(init), node);
                            return foldImpl(node.doc, std::move(acc), fn);
                        },
                        [&](const auto &node) -> T {
                            // Leaf nodes
                            return std::forward<Fn>(fn)(std::move(init), node);
                        }),
                      doc->value);
}

// Factory functions for creating documents
auto makeEmpty() -> DocPtr;
auto makeText(std::string_view text) -> DocPtr;
auto makeLine() -> DocPtr;
auto makeHardLine() -> DocPtr;
auto makeHardLines(unsigned count) -> DocPtr;
auto makeConcat(DocPtr left, DocPtr right) -> DocPtr;
auto makeNest(DocPtr doc) -> DocPtr;
auto makeHang(DocPtr doc) -> DocPtr;
auto makeUnion(DocPtr flat, DocPtr broken) -> DocPtr;
auto makeAlignText(std::string_view text, int level) -> DocPtr;
auto makeAlign(DocPtr doc) -> DocPtr;

// Utility functions
auto flatten(const DocPtr &doc) -> DocPtr;
auto resolveAlignment(const DocPtr &doc) -> DocPtr;

} // namespace emit

#endif // EMIT_DOC_IMPL_HPP