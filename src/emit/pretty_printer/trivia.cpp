#include "ast/node.hpp"
#include "common/overload.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <ranges>
#include <span>
#include <utility>
#include <variant>

namespace emit {

namespace {

/// @brief Predicate to filter out Break trivia if suppressing newlines.
auto shouldKeep(const bool suppress_newlines)
{
    return [suppress_newlines](const ast::Trivia &t) -> bool {
        return !(suppress_newlines && std::holds_alternative<ast::Break>(t));
    };
}

/// @brief Format a standard trivia item (e.g., Leading or Middle of Trailing).
/// Comments get a trailing hardline; Breaks get their full height.
auto formatTrivia(const ast::Trivia &t) -> Doc
{
    return std::visit(
      common::Overload{
        [](const ast::Comment &c) -> Doc { return Doc::text(c.text) + Doc::hardline(); },
        [](const ast::Break &p) -> Doc { return Doc::hardlines(p.blank_lines); } },
      t);
}

/// @brief Format specifically for the LAST item in a trailing block.
/// Comments don't get a trailing hardline
/// Breaks are reduced by 1 (since the block starts with \n).
auto formatLastTrailing(const ast::Trivia &t) -> Doc
{
    return std::visit(
      common::Overload{ [](const ast::Comment &c) -> Doc { return Doc::text(c.text); },
                        [](const ast::Break &p) -> Doc {
                            return Doc::hardlines(p.blank_lines > 0 ? p.blank_lines - 1 : 0);
                        } },
      t);
}

/// @brief Generic builder for a block of trivia.
/// @tparam Formatter Function to handle the very last item in the list.
template<typename Formatter>
auto buildTrivia(std::span<const ast::Trivia> trivia,
                 const bool suppress,
                 Doc prefix,
                 const Formatter format_last) -> Doc
{
    auto view = trivia | std::views::filter(shouldKeep(suppress));

    auto it = view.begin();
    if (it == view.end()) {
        return Doc::empty();
    }

    // Start with the specific prefix (Empty for Leading, Hardline for Trailing)
    Doc doc = std::move(prefix);

    auto pending = *it++;

    // Process all items except the last one
    for (const auto &item : std::ranges::subrange(it, view.end())) {
        doc += formatTrivia(std::exchange(pending, item));
    }

    // Apply the specific strategy for the last item
    return doc + format_last(pending);
}

} // namespace

auto PrettyPrinter::withTrivia(const ast::NodeBase &node, Doc core, const bool suppress) -> Doc
{
    if (!node.hasTrivia()) {
        return core;
    }

    Doc result = Doc::empty();

    // 1. Leading Trivia
    result += buildTrivia(node.getLeading(), suppress, Doc::empty(), formatTrivia);

    // 2. Core Doc
    result += core;

    // 3. Inline Comment with Trailing Trivia
    if (auto comment = node.getInlineComment()) {
        result += Doc::inlineComment(Doc::text(std::string{ " " }.append(*comment)) + buildTrivia(node.getTrailing(), suppress, Doc::hardline(), formatLastTrailing));
    } else {
        // 4. Trailing Trivia (only when no inline comment)
        result += buildTrivia(node.getTrailing(), suppress, Doc::hardline(), formatLastTrailing);
    }

    return result;
}

} // namespace emit
