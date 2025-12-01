#ifndef EMIT_DOC_UTILS_HPP
#define EMIT_DOC_UTILS_HPP

#include "emit/pretty_printer/doc.hpp"

#include <algorithm>
#include <functional>
#include <ranges>

namespace emit {

/// @brief Maps items to Docs and joins them with a separator, avoiding intermediate vectors.
/// @param items The input range of items.
/// @param sep The separator Doc (e.g., Doc::line()).
/// @param transform Function to convert each item to a Doc.
/// @param with_trailing Whether to include the separator after the last element.
/// @return Combined Doc.
template<std::ranges::input_range Range, typename Transform>
auto joinMap(Range &&items, const Doc &sep, Transform transform, const bool with_trailing) -> Doc
{
    const auto result = std::ranges::fold_left(
      std::forward<Range>(items), Doc::empty(), [&](const Doc &acc, const auto &item) {
          const auto doc = std::invoke(transform, item);
          return acc.isEmpty() ? doc : acc + sep + doc;
      });

    if (with_trailing && !result.isEmpty()) {
        return result + sep;
    }

    return result;
}

/// @brief Maps items to Docs and joins them with a separator, avoiding intermediate vectors.
/// @param items The input range of items.
/// @param sep The separator Doc (e.g., Doc::line()).
/// @param with_trailing Whether to include the separator after the last element.
/// @return Combined Doc.
template<std::ranges::input_range Range>
auto joinMap(Range &&items, const Doc &sep, const bool with_trailing) -> Doc
{
    const auto result = std::ranges::fold_left(
      std::forward<Range>(items), Doc::empty(), [&](const Doc &acc, const auto &item) {
          return acc.isEmpty() ? item : acc + sep + item;
      });

    if (with_trailing && !result.isEmpty()) {
        return result + sep;
    }

    return result;
}

/// @brief Helper to create a lambda that visits AST nodes using the given visitor.
/// @param visitor The PrettyPrinter visitor instance.
/// @return A lambda that takes an AST node and returns its Doc representation.
template<typename Visitor>
auto toDoc(const Visitor &visitor)
{
    return [&](const auto &node) { return visitor.visit(node); };
}

} // namespace emit

#endif // EMIT_DOC_UTILS_HPP
