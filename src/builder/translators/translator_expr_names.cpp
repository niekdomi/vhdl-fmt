#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <algorithm>
#include <memory>
#include <string>
#include <utility>

namespace builder {

auto Translator::makeName(vhdlParser::NameContext &ctx) -> ast::Expr
{
    const auto &parts = ctx.name_part();
    // For formatting: check if we have any structural parts (calls, slices, attributes)
    // If not, just keep the whole name as a single token
    const auto has_structure = std::ranges::any_of(parts, [](auto *part) {
        return part->function_call_or_indexed_name_part()
            != nullptr
            || part->slice_name_part()
            != nullptr
            || part->attribute_name_part()
            != nullptr;
    });

    if (!has_structure) {
        // Simple name (possibly with dots like "rec.field") - keep as one token
        return makeToken(ctx);
    }

    // Has structural parts - build up the base, then apply operations
    // Start with the identifier/literal and consume any leading dot selections
    std::string base_text;
    if (ctx.identifier() != nullptr) {
        base_text = ctx.identifier()->getText();
    } else if (ctx.STRING_LITERAL() != nullptr) {
        base_text = ctx.STRING_LITERAL()->getText();
    } else {
        // Shouldn't happen, but fallback
        return makeToken(ctx);
    }

    // Consume consecutive selected_name_parts into base
    auto it = parts.begin();
    while (it != parts.end() && (*it)->selected_name_part() != nullptr) {
        base_text += (*it)->getText();
        ++it;
    }

    ast::Expr base = makeToken(ctx, std::move(base_text));

    // Process remaining structural parts
    for (; it != parts.end(); ++it) {
        auto *part = *it;

        if (auto *slice = part->slice_name_part()) {
            base = makeSliceExpr(std::move(base), *slice);
        } else if (auto *call = part->function_call_or_indexed_name_part()) {
            base = makeCallExpr(std::move(base), *call);
        } else if (auto *attr = part->attribute_name_part()) {
            base = makeAttributeExpr(std::move(base), *attr);
        }
        // Ignore any remaining selected_name_parts (shouldn't happen after structure)
    }

    return base;
}

auto Translator::makeSliceExpr(ast::Expr base, vhdlParser::Slice_name_partContext &ctx) -> ast::Expr
{
    return build<ast::CallExpr>(ctx)
      .setBox(&ast::CallExpr::callee, std::move(base))
      .with(&ctx,
            [&](auto &node, auto &slice_ctx) {
                if (auto *dr = slice_ctx.discrete_range()) {
                    if (auto *rd = dr->range_decl()) {
                        if (auto *er = rd->explicit_range()) {
                            node.args = std::make_unique<ast::Expr>(makeRange(*er));
                        } else {
                            node.args = std::make_unique<ast::Expr>(makeToken(*rd));
                        }
                    } else if (auto *subtype = dr->subtype_indication()) {
                        node.args = std::make_unique<ast::Expr>(makeToken(*subtype));
                    }
                }
            })
      .build();
}

auto Translator::makeCallExpr(ast::Expr base,
                              vhdlParser::Function_call_or_indexed_name_partContext &ctx)
  -> ast::Expr
{
    return build<ast::CallExpr>(ctx)
      .setBox(&ast::CallExpr::callee, std::move(base))
      .with(&ctx,
            [&](auto &node, auto &call_ctx) {
                auto *assoc_list = call_ctx.actual_parameter_part();
                if (assoc_list == nullptr) {
                    return;
                }
                auto *list_ctx = assoc_list->association_list();
                if (list_ctx == nullptr) {
                    node.args = std::make_unique<ast::Expr>(makeToken(call_ctx));
                    return;
                }
                auto associations = list_ctx->association_element();
                if (associations.size() == 1) {
                    node.args = std::make_unique<ast::Expr>(makeCallArgument(*associations[0]));
                } else {
                    node.args = std::make_unique<ast::Expr>(
                      build<ast::GroupExpr>(*list_ctx)
                        .collect(&ast::GroupExpr::children,
                                 associations,
                                 [&](auto *elem) { return makeCallArgument(*elem); })
                        .build());
                }
            })
      .build();
}

auto Translator::makeAttributeExpr(ast::Expr base, vhdlParser::Attribute_name_partContext &ctx)
  -> ast::Expr
{
    return makeBinary(ctx, "'", std::move(base), makeToken(ctx, ctx.getText().substr(1)));
}

auto Translator::makeCallArgument(vhdlParser::Association_elementContext &ctx) -> ast::Expr
{
    if (auto *actual = ctx.actual_part()) {
        if (auto *designator = actual->actual_designator()) {
            if (auto *expr = designator->expression()) {
                return makeExpr(*expr);
            }
            return makeToken(*designator);
        }
        return makeToken(*actual);
    }
    return makeToken(ctx);
}

} // namespace builder
