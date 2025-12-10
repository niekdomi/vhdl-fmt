#include "emit/pretty_printer/renderer.hpp"

#include "common/config.hpp"
#include "common/overload.hpp"
#include "emit/pretty_printer/doc_impl.hpp"

#include <cctype>
#include <ranges>
#include <string>
#include <utility>
#include <variant>

namespace emit {

auto Renderer::render(const DocPtr &doc) -> std::string
{
    output_.clear();
    column_ = 0;

    renderDoc(0, Mode::BREAK, doc);

    return std::move(output_);
}

void Renderer::renderDoc(int indent, Mode mode, const DocPtr &doc)
{
    if (!doc) {
        return;
    }

    auto render_visitor = common::Overload{
        // Empty produces nothing
        [](const Empty &) -> void {},

        // Text
        [&](const Text &node) -> void { write(node.content); },

        // Keyword
        [&](const Keyword &node) -> void {
            if (config_.casing.keywords == common::CaseStyle::LOWER) {
                write(node.content
                      | std::views::transform(
                        [](unsigned char c) -> char { return static_cast<char>(std::tolower(c)); })
                      | std::ranges::to<std::string>());
            } else {
                write(node.content
                      | std::views::transform(
                        [](unsigned char c) -> char { return static_cast<char>(std::toupper(c)); })
                      | std::ranges::to<std::string>());
            }
        },

        // SoftLine (depends on mode)
        [&](const SoftLine &) -> void {
            if (mode == Mode::FLAT) {
                write(" ");
            } else {
                newline(indent);
            }
        },

        // HardLine (always breaks)
        [&](const HardLine &) -> void { newline(indent); },

        // HardLines (always breaks 'count' times)
        [&](const HardLines &node) -> void {
            for (unsigned i = 0; i < node.count; ++i) {
                newline(indent);
            }
        },

        // Concat (recursively renders children)
        [&](const Concat &node) -> void {
            renderDoc(indent, mode, node.left);
            renderDoc(indent, mode, node.right);
        },

        // Nest (increases indentation)
        [&](const Nest &node) -> void {
            renderDoc(indent + config_.line_config.indent_size, mode, node.doc);
        },

        [&](const Hang &node) -> void { renderDoc(column_, mode, node.doc); },

        // Align (conditional pre-processing)
        [&](const Align &node) -> void {
            DocPtr doc_to_render = node.doc;
            if (config_.port_map.align_signals) {
                // Run the two-pass logic to resolve alignment
                doc_to_render = resolveAlignment(node.doc);
            }

            // Render the (possibly) aligned inner document
            renderDoc(indent, mode, doc_to_render);
        },

        // Union (decision point)
        [&](const Union &node) -> void {
            // Decide: use flat or broken layout?
            if (mode == Mode::FLAT || fits(config_.line_config.line_length - column_, node.flat)) {
                // Fits on current line - use flat version
                renderDoc(indent, Mode::FLAT, node.flat);
            } else {
                // Doesn't fit - use broken version
                renderDoc(indent, Mode::BREAK, node.broken);
            }
        }
    };

    std::visit(render_visitor, doc->value);
}
// Check if document fits on current line
auto Renderer::fits(int width, const DocPtr &doc) -> bool
{
    return fitsImpl(width, doc) >= 0;
}

// Helper: simulate flattened rendering and return remaining width
auto Renderer::fitsImpl(int width, const DocPtr &doc) -> int
{
    if (!doc) {
        return width;
    }
    if (width < 0) {
        return -1;
    }

    auto fits_visitor = common::Overload{
        // Empty
        [&](const Empty &) -> int { return width; },

        // Text
        [&](const Text &node) -> int { return width - static_cast<int>(node.content.length()); },

        // Keyword
        [&](const Keyword &node) -> int { return width - static_cast<int>(node.content.length()); },

        // SoftLine (becomes space)
        [&](const SoftLine &) -> int { return width - 1; },

        // Concat (threads remaining width)
        [&](const Concat &node) -> int {
            const int remaining = fitsImpl(width, node.left);
            if (remaining < 0) {
                return -1;
            }
            return fitsImpl(remaining, node.right);
        },

        // Nest, Align, Union (Recursive call)
        [&](const Nest &node) -> int { return fitsImpl(width, node.doc); },
        [&](const Hang &node) -> int { return fitsImpl(width, node.doc); },
        [&](const Align &node) -> int { return fitsImpl(width, node.doc); },
        [&](const Union &node) -> int {
            // Check flat version only for fitting
            return fitsImpl(width, node.flat);
        },

        // All others (HardLine, HardLines) do not fit
        [](const HardLine &) -> int { return -1; },
        [](const HardLines &) -> int { return -1; },
    };

    return std::visit(fits_visitor, doc->value);
}

// Output helpers
void Renderer::write(std::string_view text)
{
    output_ += text;
    column_ += static_cast<int>(text.length());
}

void Renderer::newline(int indent)
{
    output_ += '\n';
    output_.append(indent, ' ');
    column_ = indent;
}

} // namespace emit
