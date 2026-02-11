#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makePackageBody(vhdlParser::Package_bodyContext& ctx) -> ast::PackageBody
{
    return build<ast::PackageBody>(ctx)
      .set(&ast::PackageBody::name, ctx.identifier(0)->getText())
      .set(&ast::PackageBody::has_end_package_body_keyword, ctx.BODY().size() > 1)
      .maybe(&ast::PackageBody::end_label, ctx.identifier(1), [](auto& id) { return id.getText(); })
      // TODO(domi): Handle package_body_declarative_part when needed
      .build();
}

} // namespace builder
