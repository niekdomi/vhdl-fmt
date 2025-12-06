#include "emit/pretty_printer/doc_impl.hpp"

#include "common/overload.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <algorithm>
#include <map>
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
    return std::make_shared<DocImpl>(Text{ std::string(text) });
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
            return makeText(left_text->content + right_text->content);
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

auto makeAlignText(std::string_view text, int level) -> DocPtr
{
    return std::make_shared<DocImpl>(AlignText{ .content = std::string(text), .level = level });
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

    return transformImpl(
      doc,
      common::Overload{
        [](const SoftLine &) -> DocPtr { return makeText(" "); },
        [](const Union &node) -> DocPtr {
            // In flat mode, we just pick the 'flat' branch.
            return node.flat;
        },
        [](const AlignText &node) -> DocPtr {
            // In flat mode, alignment is just the text.
            return makeText(node.content);
        },
        [](const Align &node) -> DocPtr {
            // In flat mode, the alignment group is just its content.
            return node.doc;
        },
        // For all other nodes (Concat, Nest, Hang, Text, Empty, HardLine, etc.),
        [](const auto &node) -> DocPtr { return std::make_shared<DocImpl>(node); } });
}

auto resolveAlignment(const DocPtr &doc) -> DocPtr
{
    // === Pass 1: Find max width FOR EACH level ===
    std::map<int, int> max_widths_by_level;
    max_widths_by_level = foldImpl(
      doc, std::move(max_widths_by_level), [](std::map<int, int> current_maxes, const auto &node) {
          using T = std::decay_t<decltype(node)>;
          if constexpr (std::is_same_v<T, AlignText>) {
              const int current_max = current_maxes[node.level];
              current_maxes[node.level]
                = std::max(current_max, static_cast<int>(node.content.length()));
          }
          return current_maxes; // Pass accumulator through
      });

    // Handle the case where no aligned text was found
    if (max_widths_by_level.empty()) {
        return doc;
    }

    // === Pass 2: Apply padding based on the level's max width ===
    return transformImpl(doc, [&](const auto &node) -> DocPtr {
        using T = std::decay_t<decltype(node)>;

        if constexpr (std::is_same_v<T, AlignText>) {
            // Look up the max width for this text's level
            const int max_width = max_widths_by_level.at(node.level);
            const int padding = max_width - static_cast<int>(node.content.length());
            return makeText(node.content + std::string(padding, ' '));
        } else {
            return std::make_shared<DocImpl>(node);
        }
    });
}

} // namespace emit
