#ifndef DECL_UTILS_HPP
#define DECL_UTILS_HPP

#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <format>
#include <string_view>
#include <variant>

namespace decl_utils {

/// Parse a VHDL declaration string into a specific AST node.
/// Wraps the string in an architecture body to ensure valid parsing context.
template<typename T>
inline auto parse(std::string_view decl_str) -> const T*
{
    const auto vhdl = std::format(R"(
        entity E is end E;
        architecture A of E is
            {}
        begin
        end A;
    )",
                                  decl_str);

    static ast::DesignFile design;
    design = builder::buildFromString(vhdl);

    if (design.units.size() < 2) {
        return nullptr;
    }
    const auto* arch = std::get_if<ast::Architecture>(&design.units[1]);
    if ((arch == nullptr) || arch->decls.empty()) {
        return nullptr;
    }

    const auto* decl_variant = &arch->decls.front();

    return std::get_if<T>(decl_variant);
}

} // namespace decl_utils

#endif // DECL_UTILS_HPP
