#include "emit/pretty_printer/doc.hpp"

#include "common/config.hpp"
#include "emit/pretty_printer/doc_impl.hpp"
#include "emit/pretty_printer/renderer.hpp"

#include <string>
#include <string_view>
#include <variant>

namespace emit {
// ========================================================================
// Static Factories (Document Primitives)
// ========================================================================

auto Doc::empty() -> Doc
{
    return Doc(makeEmpty());
}

auto Doc::text(std::string_view str) -> Doc
{
    return Doc(makeText(str));
}

auto Doc::line() -> Doc
{
    return Doc(makeLine());
}

auto Doc::hardline() -> Doc
{
    return Doc(makeHardLine());
}

auto Doc::hardlines(unsigned count) -> Doc
{
    if (count == 1) {
        return Doc(makeHardLine());
    }
    // Count 0 can act as a marker to prevent flattening
    return Doc(makeHardLines(count));
}

auto Doc::alignText(std::string_view str, int level) -> Doc
{
    return Doc(makeAlignText(str, level));
}

// ========================================================================
// Low-Level Combinators (Operators)
// ========================================================================

auto Doc::operator+(const Doc& other) const -> Doc
{
    return Doc(makeConcat(impl_, other.impl_));
}

auto Doc::operator&(const Doc& other) const -> Doc
{
    return *this + Doc::text(" ") + other;
}

auto Doc::operator/(const Doc& other) const -> Doc
{
    return *this + line() + other;
}

auto Doc::operator|(const Doc& other) const -> Doc
{
    return *this + hardline() + other;
}

auto Doc::operator<<(const Doc& other) const -> Doc
{
    // *this + (line() + other).nest()
    auto nested = Doc(makeNest(makeConcat(line().impl_, other.impl_)));
    return *this + nested;
}

auto Doc::hardIndent(const Doc& other) const -> Doc
{
    // *this + (hardline() + other).nest()
    auto nested = Doc(makeNest(makeConcat(hardline().impl_, other.impl_)));
    return *this + nested;
}

// ========================================================================
// Compound Assignment Operators
// ========================================================================

auto Doc::operator+=(const Doc& other) -> Doc&
{
    *this = *this + other;
    return *this;
}

auto Doc::operator&=(const Doc& other) -> Doc&
{
    *this = *this & other;
    return *this;
}

auto Doc::operator/=(const Doc& other) -> Doc&
{
    *this = *this / other;
    return *this;
}

auto Doc::operator|=(const Doc& other) -> Doc&
{
    *this = *this | other;
    return *this;
}

auto Doc::operator<<=(const Doc& other) -> Doc&
{
    *this = *this << other;
    return *this;
}

// ========================================================================
// High-Level Layout Patterns
// ========================================================================

auto Doc::bracket(const Doc& left, const Doc& inner, const Doc& right) -> Doc
{
    return (left << inner) / right;
}

auto Doc::align(const Doc& doc) -> Doc
{
    return Doc(makeAlign(doc.impl_));
}

auto Doc::group(const Doc& doc) -> Doc
{
    return Doc(makeUnion(flatten(doc.impl_), doc.impl_));
}

auto Doc::hang(const Doc& doc) -> Doc
{
    return Doc(makeHang(doc.impl_));
}

// ========================================================================
// Rendering
// ========================================================================

auto Doc::render(const common::Config& config) const -> std::string
{
    Renderer renderer(config);
    return renderer.render(impl_);
}

// =======================================================================
// Utilities
// ========================================================================

auto Doc::isEmpty() const -> bool
{
    if (!impl_) {
        return true;
    }
    return std::holds_alternative<Empty>(impl_->value);
}

} // namespace emit
