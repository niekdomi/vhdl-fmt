#ifndef EXPR_UTILS_HPP
#define EXPR_UTILS_HPP

#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "builder/ast_builder.hpp"

#include <format>
#include <string_view>
#include <variant>

namespace expr_utils {

/// Parse VHDL expression from a signal initialization
inline auto parseExpr(std::string_view init_expr) -> const ast::Expr *
{
    const auto vhdl = std::format(R"(
        entity E is end E;
        architecture A of E is
            signal x : integer := {};
        begin
        end A;
    )",
                                  init_expr);

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

    const auto *signal = std::get_if<ast::SignalDecl>(decl_item);
    if ((signal == nullptr) || !signal->init_expr.has_value()) {
        return nullptr;
    }
    return &(*signal->init_expr);
}

} // namespace expr_utils

#endif // EXPR_UTILS_HPP
