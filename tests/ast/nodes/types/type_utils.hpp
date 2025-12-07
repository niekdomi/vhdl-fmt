#ifndef TYPE_UTILS_HPP
#define TYPE_UTILS_HPP

#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "builder/ast_builder.hpp"

#include <format>
#include <string_view>
#include <variant>

namespace type_utils {

/// Parse a VHDL type declaration string into an AST node.
/// Returns a pointer to the TypeDecl inside the static AST.
inline auto parseType(std::string_view type_decl_str) -> const ast::TypeDecl *
{
    const auto vhdl = std::format(R"(
        entity E is end E;
        architecture A of E is
            {}
        begin
        end A;
    )",
                                  type_decl_str);

    static ast::DesignFile design; // Static to keep alive for returned pointer
    design = builder::buildFromString(vhdl);

    if (design.units.size() < 2) {
        return nullptr;
    }
    const auto *arch = std::get_if<ast::Architecture>(&design.units[1]);
    if ((arch == nullptr) || arch->decls.empty()) {
        return nullptr;
    }

    const auto *decl_item = arch->decls.data();

    return std::get_if<ast::TypeDecl>(decl_item);
}

} // namespace type_utils

#endif // TYPE_UTILS_HPP
