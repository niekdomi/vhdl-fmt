#include "ast/nodes/declarations.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeComponentDecl(vhdlParser::Component_declarationContext& ctx)
  -> ast::ComponentDecl
{
    return build<ast::ComponentDecl>(ctx)
      .set(&ast::ComponentDecl::name, ctx.identifier(0)->getText())
      .set(&ast::ComponentDecl::has_is_keyword, ctx.IS() != nullptr)
      .maybe(
        &ast::ComponentDecl::end_label, ctx.identifier(1), [](auto& id) { return id.getText(); })
      .maybe(&ast::ComponentDecl::generic_clause,
             ctx.generic_clause(),
             [&](auto& gc) { return makeGenericClause(gc); })
      .maybe(&ast::ComponentDecl::port_clause,
             ctx.port_clause(),
             [&](auto& pc) { return makePortClause(pc); })
      .build();
}

} // namespace builder
