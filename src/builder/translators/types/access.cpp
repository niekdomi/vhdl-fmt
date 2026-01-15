#include "ast/nodes/types.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeAccessType(vhdlParser::Access_type_definitionContext& ctx)
  -> ast::AccessTypeDef
{
    return build<ast::AccessTypeDef>(ctx)
      .set(&ast::AccessTypeDef::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .build();
}

} // namespace builder
