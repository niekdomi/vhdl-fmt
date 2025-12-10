#ifndef EMIT_RENDERER_HPP
#define EMIT_RENDERER_HPP

#include "emit/pretty_printer/doc_impl.hpp"

#include <cstdint>
#include <string>
#include <string_view>

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
    explicit Renderer(const common::Config &config) : config_{ config } {}

    ~Renderer() = default;

    Renderer(const Renderer &) = delete;
    auto operator=(const Renderer &) -> Renderer & = delete;
    Renderer(Renderer &&) = delete;
    auto operator=(Renderer &&) -> Renderer & = delete;

    // Core rendering function
    auto render(const DocPtr &doc) -> std::string;

  private:
    // Internal rendering using visitor pattern
    void renderDoc(int indent, Mode mode, const DocPtr &doc);

    // Check if document fits on current line
    static auto fits(int width, const DocPtr &doc) -> bool;

    // Helper for fits: returns remaining width, or -1 if doesn't fit
    static auto fitsImpl(int width, const DocPtr &doc) -> int;

    // Output helpers
    void write(std::string_view text);
    void newline(int indent);

    // Member variables
    int column_{ 0 };
    std::string output_;
    const common::Config &config_;
};

} // namespace emit

#endif // EMIT_RENDERER_HPP
