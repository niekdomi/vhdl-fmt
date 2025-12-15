#include "emit/pretty_printer/algorithms/alignment_resolver.hpp"

#include "emit/pretty_printer/doc_impl.hpp"
#include "emit/pretty_printer/walker.hpp"

#include <algorithm>
#include <cstddef>
#include <span>
#include <type_traits>
#include <variant>
#include <vector>

namespace emit {

auto AlignmentResolver::resolve(const DocPtr &doc) -> DocPtr
{
    if (!doc) {
        return doc;
    }

    // There will never be this many levels of alignment
    constexpr int MAX_LEVELS = 8;
    std::vector<int> widths{};
    widths.reserve(MAX_LEVELS);

    // Pass 1: Measure
    measure(doc, widths);

    if (widths.empty()) {
        return doc;
    }

    // Pass 2: Apply
    return apply(doc, widths);
}

void AlignmentResolver::measure(const DocPtr &doc, std::vector<int> &widths)
{
    if (!doc) {
        return;
    }

    auto visitor = [&](const auto &node) {
        using T = std::decay_t<decltype(node)>;

        if constexpr (std::is_same_v<T, Align>) {
            return; // Firewall
        }

        if constexpr (IS_ANY_OF_V<T, Text, Keyword>) {
            // Only process valid levels
            if (node.level < 0) {
                return;
            }

            // Resize widths vector if necessary
            if (static_cast<size_t>(node.level) >= widths.size()) {
                widths.resize(node.level + 1, 0);
            }

            // Update max width
            widths[node.level]
              = std::max(widths[node.level], static_cast<int>(node.content.length()));
        }

        // Recurse
        DocWalker::traverseChildren(node,
                                    [&](const DocPtr &child) -> void { measure(child, widths); });
    };

    std::visit(visitor, doc->value);
}

auto AlignmentResolver::apply(const DocPtr &doc, std::span<const int> widths) -> DocPtr
{
    if (!doc) {
        return doc;
    }

    auto visitor = [&doc, widths](const auto &node) {
        using T = std::decay_t<decltype(node)>;

        // 1. Return Align nodes as-is
        if constexpr (std::is_same_v<T, Align>) {
            return doc;
        }

        // 2. Apply Padding to Leaves
        if constexpr (IS_ANY_OF_V<T, Text, Keyword>) {
            // Only apply padding to levels >= 0 || Safe bound check
            if (node.level < 0 || static_cast<size_t>(node.level) >= widths.size()) {
                return doc;
            }

            if (const int width = widths[node.level]; width > 0) {
                const int padding = width - static_cast<int>(node.content.length());
                if (padding > 0) {
                    auto content = std::make_shared<DocImpl>(T{ .content = node.content });
                    return makeConcat(content, makeText(std::string(padding, ' ')));
                }
            }

            return doc;
        }

        // 3. Recurse and Rebuild
        return std::make_shared<DocImpl>(
          DocWalker::mapChildren(node, [&](const auto &c) { return apply(c, widths); }));
    };

    return std::visit(visitor, doc->value);
}

} // namespace emit
