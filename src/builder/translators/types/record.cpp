#include "ast/nodes/types.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>
#include <vector>

namespace builder {

auto Translator::makeRecordType(vhdlParser::Record_type_definitionContext &ctx)
  -> ast::RecordTypeDef
{
    return build<ast::RecordTypeDef>(ctx)
      .collect(&ast::RecordTypeDef::elements,
               ctx.element_declaration(),
               [this](auto *elem) { return makeRecordElement(*elem); })
      .maybe(
        &ast::RecordTypeDef::end_label, ctx.identifier(), [](auto &id) { return id.getText(); })
      .build();
}

auto Translator::makeRecordElement(vhdlParser::Element_declarationContext &ctx)
  -> ast::RecordElement
{
    return build<ast::RecordElement>(ctx)
      .set(&ast::RecordElement::names,
           ctx.identifier_list()->identifier() | std::views::transform([](auto *id) {
               return id->getText();
           }) | std::ranges::to<std::vector<std::string>>())
      .set(&ast::RecordElement::subtype,
           makeSubtypeIndication(*ctx.element_subtype_definition()->subtype_indication()))
      .build();
}

} // namespace builder
