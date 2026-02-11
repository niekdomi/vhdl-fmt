#include "ast/nodes/declarations.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>

namespace builder {

auto Translator::makeFormalParam(vhdlParser::Interface_declarationContext& ctx) -> ast::FormalParam
{
    // Simplified - just get the basic info
    // The grammar for formal_parameter_list uses interface_list which has interface_element
    // For now, create a simple parameter

    // This is a placeholder - formal parameters have a different structure
    // We need to check the actual grammar
    return build<ast::FormalParam>(ctx).build();
}

auto Translator::makeFunctionDecl(vhdlParser::Subprogram_declarationContext& ctx)
  -> ast::FunctionDecl
{
    auto* spec = ctx.subprogram_specification();
    auto* func_spec = spec->function_specification();

    std::string name = func_spec->designator()->getText();
    bool is_pure = func_spec->IMPURE() == nullptr; // Pure unless explicitly impure

    // TODO: Parse parameters properly
    std::vector<ast::FormalParam> parameters;

    auto return_type = makeSubtypeIndication(*func_spec->subtype_indication());

    return build<ast::FunctionDecl>(ctx)
      .set(&ast::FunctionDecl::name, std::move(name))
      .set(&ast::FunctionDecl::is_pure, is_pure)
      .set(&ast::FunctionDecl::parameters, std::move(parameters))
      .set(&ast::FunctionDecl::return_type, std::move(return_type))
      .build();
}

auto Translator::makeProcedureDecl(vhdlParser::Subprogram_declarationContext& ctx)
  -> ast::ProcedureDecl
{
    auto* spec = ctx.subprogram_specification();
    auto* proc_spec = spec->procedure_specification();

    std::string name = proc_spec->designator()->getText();

    // TODO: Parse parameters properly
    std::vector<ast::FormalParam> parameters;

    return build<ast::ProcedureDecl>(ctx)
      .set(&ast::ProcedureDecl::name, std::move(name))
      .set(&ast::ProcedureDecl::parameters, std::move(parameters))
      .build();
}

auto Translator::makePackageDeclarativeItem(vhdlParser::Package_declarative_itemContext& ctx)
  -> ast::Declaration
{
    // Handle type declarations
    if (auto* type_decl = ctx.type_declaration()) {
        return makeTypeDecl(*type_decl);
    }

    // Handle constant declarations
    if (auto* const_decl = ctx.constant_declaration()) {
        return makeConstantDecl(*const_decl);
    }

    // Handle signal declarations
    if (auto* sig_decl = ctx.signal_declaration()) {
        return makeSignalDecl(*sig_decl);
    }

    // Handle variable declarations
    if (auto* var_decl = ctx.variable_declaration()) {
        return makeVariableDecl(*var_decl);
    }

    // Handle component declarations
    if (auto* comp_decl = ctx.component_declaration()) {
        return makeComponentDecl(*comp_decl);
    }

    // Handle subprogram declarations (function/procedure without body)
    if (auto* subprog_decl = ctx.subprogram_declaration()) {
        auto* spec = subprog_decl->subprogram_specification();

        if (spec->function_specification() != nullptr) {
            return makeFunctionDecl(*subprog_decl);
        }

        if (spec->procedure_specification() != nullptr) {
            return makeProcedureDecl(*subprog_decl);
        }
    }

    // TODO(domi): Handle subprogram bodies, attribute declarations, etc.

    // Fallback: return empty constant as placeholder for unsupported items
    return ast::ConstantDecl{};
}

} // namespace builder
