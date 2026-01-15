#ifndef EMIT_PRETTY_PRINTER_ALGORITHMS_ALIGNMENT_RESOLVER_HPP
#define EMIT_PRETTY_PRINTER_ALGORITHMS_ALIGNMENT_RESOLVER_HPP

#include "emit/pretty_printer/doc.hpp"

#include <span>
#include <vector>

namespace emit {

class AlignmentResolver
{
  public:
    /// @brief Applies alignment to the given document
    [[nodiscard]]
    static auto resolve(const DocPtr& doc) -> DocPtr;

  private:
    // Pass 1: Recursive Analysis
    static auto measure(const DocPtr& doc, std::vector<int>& widths) -> void;

    // Pass 2: Recursive Transformation
    [[nodiscard]]
    static auto apply(const DocPtr& doc, std::span<const int> widths) -> DocPtr;
};

} // namespace emit

#endif // EMIT_PRETTY_PRINTER_ALGORITHMS_ALIGNMENT_RESOLVER_HPP
