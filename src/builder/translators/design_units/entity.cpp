#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeEntity(vhdlParser::Entity_declarationContext &ctx) -> ast::Entity
{
    auto *header = ctx.entity_header();

    return build<ast::Entity>(ctx)
      .set(&ast::Entity::name, ctx.identifier(0)->getText())
      .set(&ast::Entity::has_end_entity_keyword, ctx.ENTITY().size() > 1)
      .maybe(&ast::Entity::end_label, ctx.identifier(1), [](auto &id) { return id.getText(); })
      .maybe(&ast::Entity::generic_clause,
             (header != nullptr) ? header->generic_clause() : nullptr,
             [&](auto &gc) { return makeGenericClause(gc); })
      .maybe(&ast::Entity::port_clause,
             (header != nullptr) ? header->port_clause() : nullptr,
             [&](auto &pc) { return makePortClause(pc); })
      .build();
}

} // namespace builder
