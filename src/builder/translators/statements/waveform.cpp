#include "ast/nodes/statements/waveform.hpp"

#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeWaveformElement(vhdlParser::Waveform_elementContext& ctx)
  -> ast::Waveform::Element
{
    return build<ast::Waveform::Element>(ctx)
      .maybe(&ast::Waveform::Element::value,
             ctx.expression(0),
             [this](auto& expr) { return makeExpr(expr); })
      .maybe(&ast::Waveform::Element::after,
             ctx.expression(1),
             [this](auto& expr) { return makeExpr(expr); })
      .build();
}

auto Translator::makeWaveform(vhdlParser::WaveformContext& ctx) -> ast::Waveform
{
    return build<ast::Waveform>(ctx)
      .set(&ast::Waveform::is_unaffected, ctx.UNAFFECTED() != nullptr)
      .collect(&ast::Waveform::elements,
               ctx.waveform_element(),
               [this](auto* el) { return makeWaveformElement(*el); })
      .build();
}

} // namespace builder
