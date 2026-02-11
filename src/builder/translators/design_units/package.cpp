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
      .collectFrom(
        &ast::Package::decls,
        ctx.package_declarative_part(),
        [](auto& part) { return part.package_declarative_item(); },
        [this](auto* item) { return makePackageDeclarativeItem(*item); })
      .build();
}

} // namespace builder
