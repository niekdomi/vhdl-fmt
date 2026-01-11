#ifndef EMIT_DOC_IMPL_HPP
#define EMIT_DOC_IMPL_HPP

#include <memory>
#include <string>
#include <string_view>
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
    int level{ -1 };
};

struct Keyword
{
    std::string content;
    int level{ -1 };
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

struct Align
{
    DocPtr doc;
};

/// Internal document representation using variant
struct DocImpl
{
    std::
      variant<Empty, Text, Keyword, SoftLine, HardLine, HardLines, Concat, Nest, Hang, Union, Align>
        value;
};

// Factory functions for creating documents
auto makeEmpty() -> DocPtr;
auto makeText(std::string_view text) -> DocPtr;
auto makeText(std::string_view text, int level) -> DocPtr;
auto makeKeyword(std::string_view text) -> DocPtr;
auto makeKeyword(std::string_view text, int level) -> DocPtr;
auto makeLine() -> DocPtr;
auto makeHardLine() -> DocPtr;
auto makeHardLines(unsigned count) -> DocPtr;
auto makeConcat(DocPtr left, DocPtr right) -> DocPtr;
auto makeNest(DocPtr doc) -> DocPtr;
auto makeHang(DocPtr doc) -> DocPtr;
auto makeUnion(DocPtr flat, DocPtr broken) -> DocPtr;
auto makeAlignText(DocPtr doc) -> DocPtr;
auto makeAlign(DocPtr doc) -> DocPtr;

// Utility functions
auto flatten(const DocPtr &doc) -> DocPtr;
auto resolveAlignment(const DocPtr &doc) -> DocPtr;

} // namespace emit

#endif // EMIT_DOC_IMPL_HPP
