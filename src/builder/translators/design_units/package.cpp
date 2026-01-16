#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makePackage(vhdlParser::Package_declarationContext& ctx) -> ast::Package
{
    return build<ast::Package>(ctx)
      .set(&ast::Package::name, ctx.identifier(0)->getText())
      .set(&ast::Package::has_end_package_keyword, ctx.PACKAGE().size() > 1)
      .maybe(&ast::Package::end_label, ctx.identifier(1), [](auto& id) { return id.getText(); })
      // TODO(domi): Handle package_declarative_part when needed
      .build();
}

} // namespace builder
