#include "emit/pretty_printer/doc_impl.hpp"

#include "emit/pretty_printer/doc.hpp"

#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>
#include <variant>

namespace emit {

// Factory functions
auto makeEmpty() -> DocPtr
{
    return std::make_shared<DocImpl>(Empty{});
}

auto makeText(std::string_view text) -> DocPtr
{
    return std::make_shared<DocImpl>(Text{ .content = std::string{ text } });
}

auto makeText(std::string_view text, int level) -> DocPtr
{
    return std::make_shared<DocImpl>(Text{ .content = std::string{ text }, .level = level });
}

auto makeKeyword(std::string_view text) -> DocPtr
{
    return std::make_shared<DocImpl>(Keyword{ .content = std::string{ text } });
}

auto makeKeyword(std::string_view text, int level) -> DocPtr
{
    return std::make_shared<DocImpl>(Keyword{ .content = std::string{ text }, .level = level });
}

auto makeLine() -> DocPtr
{
    return std::make_shared<DocImpl>(SoftLine{});
}

auto makeHardLine() -> DocPtr
{
    return std::make_shared<DocImpl>(HardLine{});
}

auto makeHardLines(unsigned count) -> DocPtr
{
    return std::make_shared<DocImpl>(HardLines{ count });
}

auto makeConcat(DocPtr left, DocPtr right) -> DocPtr
{
    // === Rule 1: Identity (Empty) elimination ===
    const bool left_is_empty = !left || std::holds_alternative<Empty>(left->value);
    if (left_is_empty) {
        return right;
    }

    const bool right_is_empty = !right || std::holds_alternative<Empty>(right->value);
    if (right_is_empty) {
        return left;
    }

    // === Rule 2: Merge adjacent Text nodes ===
    if (auto *left_text = std::get_if<Text>(&left->value)) {
        if (auto *right_text = std::get_if<Text>(&right->value)) {
            // Create a new merged text node directly
            if (left_text->level < 0 && right_text->level < 0) {
                return makeText(left_text->content + right_text->content, -1);
            }
        }
    }

    // === Rule 3: Merge adjacent HardLines/HardLine nodes ===
    auto get_lines = [](const DocPtr &d) -> std::optional<unsigned> {
        if (std::holds_alternative<HardLine>(d->value)) {
            return 1;
        }
        if (auto *hl = std::get_if<HardLines>(&d->value)) {
            return hl->count;
        }
        return std::nullopt;
    };

    if (auto lhs = get_lines(left), rhs = get_lines(right); lhs && rhs) {
        const unsigned total_lines = *lhs + *rhs;
        if (total_lines == 1) {
            return makeHardLine();
        }
        // HardLines(0) acts as prevention for flattening
        return makeHardLines(total_lines);
    }

    // === Fallback: Actually create the Concat node ===
    return std::make_shared<DocImpl>(Concat{ .left = std::move(left), .right = std::move(right) });
}

auto makeNest(DocPtr doc) -> DocPtr
{
    return std::make_shared<DocImpl>(Nest{ .doc = std::move(doc) });
}

auto makeHang(DocPtr doc) -> DocPtr
{
    return std::make_shared<DocImpl>(Hang{ .doc = std::move(doc) });
}

auto makeUnion(DocPtr flat, DocPtr broken) -> DocPtr
{
    return std::make_shared<DocImpl>(Union{ .flat = std::move(flat), .broken = std::move(broken) });
}

auto makeAlign(DocPtr doc) -> DocPtr
{
    return std::make_shared<DocImpl>(Align{ .doc = std::move(doc) });
}

// Utility functions
auto flatten(const DocPtr &doc) -> DocPtr
{
    if (!doc) {
        return doc;
    }

    return transformImpl(doc, [](auto &&node) -> DocPtr {
        using T = std::decay_t<decltype(node)>;

        // Convert SoftLine to Space
        if constexpr (std::is_same_v<T, SoftLine>) {
            return makeText(" ", -1);
        }
        // Unwrap Unions (Pick the pre-flattened branch)
        else if constexpr (std::is_same_v<T, Union>) {
            return node.flat;
        }
        // Unwrap Align scopes
        else if constexpr (std::is_same_v<T, Align>) {
            return node.doc;
        }
        // Default: Pass everything else through (Concat, Text, HardLine, etc.)
        else {
            return std::make_shared<DocImpl>(std::forward<decltype(node)>(node));
        }
    });
}

} // namespace emit
