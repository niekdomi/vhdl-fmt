#include "ast/nodes/types.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeArrayType(vhdlParser::Array_type_definitionContext& ctx) -> ast::ArrayTypeDef
{
    if (auto* uncons = ctx.unconstrained_array_definition()) {
        return makeUnconstrainedArray(*uncons);
    }

    if (auto* cons = ctx.constrained_array_definition()) {
        return makeConstrainedArray(*cons);
    }

    return {};
}

auto Translator::makeUnconstrainedArray(vhdlParser::Unconstrained_array_definitionContext& ctx)
  -> ast::ArrayTypeDef
{
    return build<ast::ArrayTypeDef>(ctx)
      .set(&ast::ArrayTypeDef::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .apply([&](auto& def) {
          for (auto* idx : ctx.index_subtype_definition()) {
              if (auto* name = idx->name()) {
                  def.indices.emplace_back(name->getText());
              }
          }
      })
      .build();
}

auto Translator::makeConstrainedArray(vhdlParser::Constrained_array_definitionContext& ctx)
  -> ast::ArrayTypeDef
{
    return build<ast::ArrayTypeDef>(ctx)
      .set(&ast::ArrayTypeDef::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .with(ctx.index_constraint(),
            [this](auto& def, auto& idx_ctx) {
                for (auto* dr : idx_ctx.discrete_range()) {
                    def.indices.emplace_back(makeDiscreteRange(*dr));
                }
            })
      .build();
}

} // namespace builder
