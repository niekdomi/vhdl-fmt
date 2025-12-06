#ifndef EMIT_DOC_IMPL_HPP
#define EMIT_DOC_IMPL_HPP

#include <concepts>
#include <memory>
#include <string>
#include <string_view>
#include <utility>
#include <variant>

namespace emit {

// Forward declaration for recursive type
struct DocImpl;
using DocPtr = std::shared_ptr<DocImpl>;

template<typename T>
concept DocNode = requires(const T &node) {
    { node.fmap(std::declval<DocPtr(const DocPtr &)>()) } -> std::same_as<T>;
    {
        node.fold(std::declval<int>(), std::declval<int(int, const DocPtr &)>())
    } -> std::same_as<int>;
};

/// Empty document
struct Empty
{
    template<typename Fn>
    auto fmap(Fn && /* fn */) const -> Empty
    {
        return {};
    }

    template<typename T, typename Fn>
    auto fold(T init, Fn && /* fn */) const -> T
    {
        return init;
    }
};

/// Text (no newlines allowed)
struct Text
{
    std::string content;

    template<typename Fn>
    auto fmap(Fn && /* fn */) const -> Text
    {
        return { content };
    }

    template<typename T, typename Fn>
    auto fold(T init, Fn && /* fn */) const -> T
    {
        return init;
    }
};

/// Line break (space when flattened, newline when broken)
struct SoftLine
{
    template<typename Fn>
    auto fmap(Fn && /* fn */) const -> SoftLine
    {
        return {};
    }

    template<typename T, typename Fn>
    auto fold(T init, Fn && /* fn */) const -> T
    {
        return init;
    }
};

/// Hard line break (always newline, never becomes space)
struct HardLine
{
    template<typename Fn>
    auto fmap(Fn && /* fn */) const -> HardLine
    {
        return {};
    }

    template<typename T, typename Fn>
    auto fold(T init, Fn && /* fn */) const -> T
    {
        return init;
    }
};

/// Multiple hard line breaks
struct HardLines
{
    unsigned count{};

    template<typename Fn>
    auto fmap(Fn && /* fn */) const -> HardLines
    {
        return { count };
    }

    template<typename T, typename Fn>
    auto fold(T init, Fn && /* fn */) const -> T
    {
        return init;
    }
};

/// Concatenation of two documents
struct Concat
{
    DocPtr left;
    DocPtr right;

    template<typename Fn>
    auto fmap(Fn &&fn) const -> Concat
    {
        return { std::forward<Fn>(fn)(left), std::forward<Fn>(fn)(right) };
    }

    template<typename T, typename Fn>
    auto fold(T init, Fn &&fn) const -> T
    {
        T new_value = std::forward<Fn>(fn)(std::move(init), left);
        return std::forward<Fn>(fn)(std::move(new_value), right);
    }
};

/// Increase indentation level
struct Nest
{
    DocPtr doc;

    template<typename Fn>
    auto fmap(Fn &&fn) const -> Nest
    {
        return { std::forward<Fn>(fn)(doc) };
    }

    template<typename T, typename Fn>
    auto fold(T init, Fn &&fn) const -> T
    {
        return std::forward<Fn>(fn)(std::move(init), doc);
    }
};

/// Set indentation level to the current column
struct Hang
{
    DocPtr doc;

    template<typename Fn>
    auto fmap(Fn &&fn) const -> Hang
    {
        return { std::forward<Fn>(fn)(doc) };
    }

    template<typename T, typename Fn>
    auto fold(T init, Fn &&fn) const -> T
    {
        return std::forward<Fn>(fn)(std::move(init), doc);
    }
};

/// Choice between flat and broken layout
struct Union
{
    DocPtr flat;
    DocPtr broken;

    template<typename Fn>
    auto fmap(Fn &&fn) const -> Union
    {
        return { std::forward<Fn>(fn)(flat), std::forward<Fn>(fn)(broken) };
    }

    template<typename T, typename Fn>
    auto fold(T init, Fn &&fn) const -> T
    {
        // Only the broken branch is to be considered
        return std::forward<Fn>(fn)(std::move(init), broken);
    }
};

struct AlignText
{
    std::string content;
    int level{};

    template<typename Fn>
    auto fmap(Fn && /* fn */) const -> AlignText
    {
        return { .content = content, .level = level };
    }

    template<typename T, typename Fn>
    auto fold(T init, Fn && /* fn */) const -> T
    {
        // These nodes have no children, so they just return the accumulator.
        return init;
    }
};

struct Align
{
    DocPtr doc;

    template<typename Fn>
    auto fmap(Fn &&fn) const -> Align
    {
        return { std::forward<Fn>(fn)(doc) };
    }

    template<typename T, typename Fn>
    auto fold(T init, Fn &&fn) const -> T
    {
        // Align knows it has one child.
        return std::forward<Fn>(fn)(std::move(init), doc);
    }
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

/// Recursive document transformer using fmap
template<typename Fn>
auto transformImpl(const DocPtr &doc, Fn &&fn) -> DocPtr
{
    return std::visit(
      [&fn](const DocNode auto &node) -> DocPtr {
          const auto mapped
            = node.fmap([&fn](const DocPtr &inner) { return transformImpl(inner, fn); });
          return std::forward<Fn>(fn)(mapped);
      },
      doc->value);
}

template<typename T, typename Fn>
auto foldImpl(const DocPtr &doc, T init, Fn &&fn) -> T
{
    if (!doc) {
        return init;
    }

    return std::visit(
      [&](const DocNode auto &node) -> T {
          T new_value = std::forward<Fn>(fn)(std::move(init), node);

          const auto recurse_step
            = [&fn](T acc, const DocPtr &child) { return foldImpl(child, std::move(acc), fn); };

          return node.fold(std::move(new_value), recurse_step);
      },
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
