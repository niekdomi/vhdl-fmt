#ifndef EMIT_RENDERER_HPP
#define EMIT_RENDERER_HPP

#include "emit/pretty_printer/doc_impl.hpp"

#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace common {
struct Config;
} // namespace common

namespace emit {

/// Rendering mode for layout algorithm
enum class Mode : std::uint8_t
{
    FLAT,
    BREAK
};

/// Renderer for the pretty printer
class Renderer final
{
  public:
    explicit Renderer(const common::Config &config);

    // Core rendering function
    auto render(const DocPtr &doc) -> std::string;

  private:
    // Internal rendering using visitor pattern
    void renderDoc(int indent, Mode mode, const DocPtr &doc);

    // Check if document fits on current line
    static auto fits(int width, const DocPtr &doc) -> bool;

    // Helper for fits: returns remaining width, or -1 if doesn't fit
    static auto fitsImpl(int width, const DocPtr &doc) -> int;

    // Helper to flush pending comments
    void flushComments(int indent);

    // Output helpers
    void write(std::string_view text);
    void newline(int indent);

    // Member variables
    int width_{};
    int indent_size_{};
    bool align_{ false };
    int column_{ 0 };
    std::string output_;
    std::vector<DocPtr> pending_comments_;
    bool flushing_comments_{ false };
};

} // namespace emit

#endif // EMIT_RENDERER_HPP
