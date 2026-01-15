#include "ast/nodes/types.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeFileType(vhdlParser::File_type_definitionContext& ctx) -> ast::FileTypeDef
{
    return build<ast::FileTypeDef>(ctx)
      .set(&ast::FileTypeDef::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .build();
}

} // namespace builder
