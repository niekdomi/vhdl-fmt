#include "ast/nodes/types.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeEnumerationType(vhdlParser::Enumeration_type_definitionContext& ctx)
  -> ast::EnumerationTypeDef
{
    return build<ast::EnumerationTypeDef>(ctx)
      .collect(&ast::EnumerationTypeDef::literals,
               ctx.enumeration_literal(),
               [](auto* lit) { return lit->getText(); })
      .build();
}

} // namespace builder
