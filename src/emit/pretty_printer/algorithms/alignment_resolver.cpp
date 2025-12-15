#include "emit/pretty_printer/algorithms/alignment_resolver.hpp"

#include "emit/pretty_printer/doc_impl.hpp"
#include "emit/pretty_printer/walker.hpp"

#include <algorithm>
#include <map>
#include <type_traits>
#include <variant>

namespace emit {

auto AlignmentResolver::resolve(const DocPtr &doc) -> DocPtr
{
    if (!doc) {
        return doc;
    }

    std::map<int, int> widths{};

    // Pass 1: Measure
    measure(doc, widths);

    if (widths.empty()) {
        return doc;
    }

    // Pass 2: Apply
    return apply(doc, widths);
}

void AlignmentResolver::measure(const DocPtr &doc, std::map<int, int> &widths)
{
    if (!doc) {
        return;
    }

    auto visitor = [&](const auto &node) {
        using T = std::decay_t<decltype(node)>;

        // 1. Stop recursion at Align nodes
        if constexpr (std::is_same_v<T, Align>) {
            return;
        }

        // 2. Measure Leaves
        if constexpr (IS_ANY_OF_V<T, Text, Keyword>) {
            if (node.level >= 0) {
                widths[node.level]
                  = std::max(widths[node.level], static_cast<int>(node.content.length()));
            }
        }

        // 3. Recurse
        DocWalker::traverseChildren(node,
                                    [&](const DocPtr &child) -> void { measure(child, widths); });
    };

    std::visit(visitor, doc->value);
}

auto AlignmentResolver::apply(const DocPtr &doc, const std::map<int, int> &widths) -> DocPtr
{
    if (!doc) {
        return doc;
    }

    auto visitor = [&](const auto &node) {
        using T = std::decay_t<decltype(node)>;

        // 1. Return Align nodes as-is
        if constexpr (std::is_same_v<T, Align>) {
            return doc;
        }

        // 2. Apply Padding to Leaves
        if constexpr (IS_ANY_OF_V<T, Text, Keyword>) {
            // Only apply padding to levels >= 0
            if (node.level < 0) {
                return doc;
            }

            // Safe lookup since measured first
            if (auto it = widths.find(node.level); it != widths.end()) {
                const int padding = it->second - static_cast<int>(node.content.length());
                if (padding > 0) {
                    auto content = std::make_shared<DocImpl>(T{ .content = node.content });
                    return makeConcat(content, makeText(std::string(padding, ' ')));
                }
            }
            return doc; // No padding needed
        }

        // 3. Recurse and Rebuild
        return std::make_shared<DocImpl>(
          DocWalker::mapChildren(node, [&](const auto &c) { return apply(c, widths); }));
    };

    return std::visit(visitor, doc->value);
}

} // namespace emit
