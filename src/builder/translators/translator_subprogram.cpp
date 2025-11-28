#include "ast/nodes/declarations.hpp"
#include "builder/translator.hpp"
#include "common/range_helpers.hpp"
#include "vhdlParser.h"

#include <ranges>
#include <utility>

namespace builder {

auto Translator::makeSubprogramParam(vhdlParser::Interface_declarationContext *ctx,
                                     const bool is_last) -> ast::SubprogramParam
{
    if (ctx == nullptr) {
        return {};
    }

    auto param = make<ast::SubprogramParam>(ctx);
    param.is_last = is_last;

    auto set_names = [](auto *list) {
        return list->identifier()
             | std::views::transform([](auto *id) { return id->getText(); })
             | std::ranges::to<std::vector>();
    };

    const auto fill_type = [](auto *stype) -> std::string {
        if (stype == nullptr) {
            return {};
        }

        if (!stype->selected_name().empty()) {
            return stype->selected_name(0)->getText();
        }

        return stype->getText();
    };

    if (auto *const_ctx = ctx->interface_constant_declaration()) {
        param.names = set_names(const_ctx->identifier_list());
        param.mode = const_ctx->IN() != nullptr ? "in" : "";
        param.type_name = fill_type(const_ctx->subtype_indication());

        if (auto *expr = const_ctx->expression()) {
            param.default_expr = makeExpr(expr);
        }

        return param;
    }

    const auto fill_signal_like = [&](auto *decl_ctx, auto *mode_ctx, auto *subtype_ctx) {
        param.names = set_names(decl_ctx->identifier_list());
        param.mode = mode_ctx == nullptr ? "" : mode_ctx->getText();
        param.type_name = fill_type(subtype_ctx);

        if (auto *expr = decl_ctx->expression()) {
            param.default_expr = makeExpr(expr);
        }
    };

    if (auto *sig_ctx = ctx->interface_signal_declaration()) {
        fill_signal_like(sig_ctx, sig_ctx->signal_mode(), sig_ctx->subtype_indication());
        return param;
    }

    if (auto *var_ctx = ctx->interface_variable_declaration()) {
        fill_signal_like(var_ctx, var_ctx->signal_mode(), var_ctx->subtype_indication());
        return param;
    }

    if (auto *file_ctx = ctx->interface_file_declaration()) {
        param.names = set_names(file_ctx->identifier_list());
        param.type_name = fill_type(file_ctx->subtype_indication());
        return param;
    }

    return param;
}

auto Translator::makeParameterList(vhdlParser::Formal_parameter_listContext *ctx)
  -> std::vector<ast::SubprogramParam>
{
    std::vector<ast::SubprogramParam> params;
    if (ctx == nullptr) {
        return params;
    }

    auto *iface_list = ctx->interface_list();
    if (iface_list == nullptr) {
        return params;
    }

    const auto &elems = iface_list->interface_element();
    params = common::transformWithLast(elems,
                                       [this](auto *elem, const bool is_last) {
                                           return makeSubprogramParam(elem->interface_declaration(),
                                                                      is_last);
                                       })
           | std::ranges::to<std::vector>();

    return params;
}

auto Translator::makeSubprogramDecls(vhdlParser::Subprogram_declarative_partContext *ctx)
  -> std::vector<ast::Declaration>
{
    if (ctx == nullptr) {
        return {};
    }

    std::vector<ast::Declaration> decls;
    for (auto *item : ctx->subprogram_declarative_item()) {
        if (auto *const_ctx = item->constant_declaration()) {
            decls.emplace_back(makeConstantDecl(const_ctx));
        } else if (auto *alias_ctx = item->alias_declaration()) {
            decls.emplace_back(makeAliasDecl(alias_ctx));
        } else if (auto *type_ctx = item->type_declaration()) {
            decls.emplace_back(makeTypeDecl(type_ctx));
        } else if (auto *subtype_ctx = item->subtype_declaration()) {
            decls.emplace_back(makeSubtypeDecl(subtype_ctx));
        } else if (auto *nested_decl = item->subprogram_declaration()) {
            if (auto decl = makeSubprogramDeclaration(nested_decl)) {
                decls.emplace_back(std::move(*decl));
            }
        } else if (auto *nested_body = item->subprogram_body()) {
            if (auto decl = makeSubprogramBody(nested_body)) {
                decls.emplace_back(std::move(*decl));
            }
        }
        // Variable/file declarations and others are currently ignored.
    }

    return decls;
}

auto Translator::makeSubprogramStatements(vhdlParser::Subprogram_statement_partContext *ctx)
  -> std::vector<ast::SequentialStatement>
{
    if (ctx == nullptr) {
        return {};
    }

    return ctx->sequential_statement()
         | std::views::transform([this](auto *stmt) { return makeSequentialStatement(stmt); })
         | std::ranges::to<std::vector>();
}

auto Translator::makeProcedure(vhdlParser::Procedure_specificationContext *ctx)
  -> ast::ProcedureDecl
{
    if (ctx == nullptr) {
        return {};
    }

    auto proc = make<ast::ProcedureDecl>(ctx);

    if (auto *designator = ctx->designator()) {
        proc.name = designator->getText();
    }

    proc.parameters = makeParameterList(ctx->formal_parameter_list());

    return proc;
}

auto Translator::makeFunction(vhdlParser::Function_specificationContext *ctx) -> ast::FunctionDecl
{
    if (ctx == nullptr) {
        return {};
    }

    auto func = make<ast::FunctionDecl>(ctx);

    if (auto *designator = ctx->designator()) {
        func.name = designator->getText();
    }

    func.parameters = makeParameterList(ctx->formal_parameter_list());

    if (auto *stype = ctx->subtype_indication()) {
        if (!stype->selected_name().empty()) {
            func.return_type = stype->selected_name(0)->getText();
        } else {
            func.return_type = stype->getText();
        }
    }

    return func;
}

auto Translator::makeSubprogramDeclaration(vhdlParser::Subprogram_declarationContext *ctx)
  -> std::optional<ast::Declaration>
{
    if (ctx == nullptr) {
        return std::nullopt;
    }

    auto *spec = ctx->subprogram_specification();
    if (spec == nullptr) {
        return std::nullopt;
    }

    if (auto *proc_spec = spec->procedure_specification()) {
        return makeProcedure(proc_spec);
    }

    if (auto *func_spec = spec->function_specification()) {
        return makeFunction(func_spec);
    }

    return std::nullopt;
}

auto Translator::makeSubprogramBody(vhdlParser::Subprogram_bodyContext *ctx)
  -> std::optional<ast::Declaration>
{
    if (ctx == nullptr) {
        return std::nullopt;
    }

    auto *spec = ctx->subprogram_specification();
    if (spec == nullptr) {
        return std::nullopt;
    }

    auto declarative_part = makeSubprogramDecls(ctx->subprogram_declarative_part());
    auto statements = makeSubprogramStatements(ctx->subprogram_statement_part());

    if (auto *proc_spec = spec->procedure_specification()) {
        auto proc = makeProcedure(proc_spec);
        proc.decls = std::move(declarative_part);
        proc.body = std::move(statements);

        return proc;
    }

    if (auto *func_spec = spec->function_specification()) {
        auto func = makeFunction(func_spec);
        func.decls = std::move(declarative_part);
        func.body = std::move(statements);

        return func;
    }

    return std::nullopt;
}

} // namespace builder
