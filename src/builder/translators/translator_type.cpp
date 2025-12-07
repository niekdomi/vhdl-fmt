#include "ast/nodes/declarations.hpp"
#include "ast/nodes/types.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>
#include <string>
#include <vector>

namespace builder {

auto Translator::makeTypeDecl(vhdlParser::Type_declarationContext &ctx) -> ast::TypeDecl
{
    return build<ast::TypeDecl>(ctx)
      .set(&ast::TypeDecl::name, ctx.identifier()->getText())
      .maybe(&ast::TypeDecl::type_def,
             ctx.type_definition(),
             [this](auto &ctx) { return makeTypeDefinition(ctx); })
      .build();
}

auto Translator::makeTypeDefinition(vhdlParser::Type_definitionContext &ctx) -> ast::TypeDefinition
{
    // Scalar Types (Enum, Physical, Integer/Real via range constraints)
    // Grammar: scalar_type_definition : physical | enumeration | range_constraint
    if (auto *scalar = ctx.scalar_type_definition()) {
        if (auto *enum_ctx = scalar->enumeration_type_definition()) {
            return makeEnumerationType(*enum_ctx);
        }

        // TODO(vedivad): Implement physical and range types
        // if (auto *phys_ctx = scalar->physical_type_definition()) {
        //      // "type time is range ... units ... end units;"
        //     return makePhysicalType(*phys_ctx);
        // }

        // if (auto *range_ctx = scalar->range_constraint()) {
        //     // "type MyInt is range 0 to 10;"
        //     return makeScalarRangeType(*range_ctx);
        // }
    }

    // Composite Types (Arrays and Records)
    // Grammar: composite_type_definition : array_type | record_type
    else if (auto *comp = ctx.composite_type_definition()) {
        if (auto *arr_ctx = comp->array_type_definition()) {
            return makeArrayType(*arr_ctx);
        }

        if (auto *rec_ctx = comp->record_type_definition()) {
            return makeRecordType(*rec_ctx);
        }
    }

    // Access Types (Pointers)
    // Grammar: access_type_definition : ACCESS subtype_indication
    else if (auto *acc_ctx = ctx.access_type_definition()) {
        return makeAccessType(*acc_ctx);
    }

    // File Types
    // Grammar: file_type_definition : FILE OF subtype_indication
    else if (auto *file_ctx = ctx.file_type_definition()) {
        return makeFileType(*file_ctx);
    }

    // Return empty variant if no known type matched
    return {};
}

auto Translator::makeEnumerationType(vhdlParser::Enumeration_type_definitionContext &ctx)
  -> ast::EnumerationTypeDef
{
    return build<ast::EnumerationTypeDef>(ctx)
      .collect(&ast::EnumerationTypeDef::literals,
               ctx.enumeration_literal(),
               [](auto *lit) { return lit->getText(); })
      .build();
}

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
      .apply([&](auto &node) {
          auto *subtype = ctx.element_subtype_definition()->subtype_indication();
          if (subtype == nullptr) {
              return;
          }

          if (auto *name = subtype->selected_name(0)) {
              node.type_name = name->getText();
          }
          if (auto *constr = subtype->constraint()) {
              node.constraint = makeConstraint(*constr);
          }
      })
      .build();
}

auto Translator::makeArrayType(vhdlParser::Array_type_definitionContext &ctx) -> ast::ArrayTypeDef
{
    auto extract_element_info = [&](auto *array_ctx, ast::ArrayTypeDef &def) {
        if (array_ctx == nullptr) {
            return;
        }

        auto *subtype = array_ctx->subtype_indication();
        if (subtype == nullptr) {
            return;
        }

        def.element_type = extractTypeName(subtype);

        if (auto *constr = subtype->constraint()) {
            def.element_constraint = makeConstraint(*constr);
        }
    };

    return build<ast::ArrayTypeDef>(ctx)
      .apply([&](auto &def) {
          // Case 1: Unconstrained (array (natural range <>) of ...)
          if (auto *uncons = ctx.unconstrained_array_definition()) {
              extract_element_info(uncons, def);
              for (auto *idx : uncons->index_subtype_definition()) {
                  if (auto *name = idx->name()) {
                      def.indices.emplace_back(name->getText());
                  }
              }
          }
          // Case 2: Constrained (array (7 downto 0) of ...)
          else if (auto *cons = ctx.constrained_array_definition()) {
              extract_element_info(cons, def);
              if (auto *idx_constr = cons->index_constraint()) {
                  for (auto *dr : idx_constr->discrete_range()) {
                      // Parse the range into an AST expression
                      def.indices.emplace_back(makeDiscreteRange(*dr));
                  }
              }
          }
      })
      .build();
}

auto Translator::makeAccessType(vhdlParser::Access_type_definitionContext &ctx)
  -> ast::AccessTypeDef
{
    return build<ast::AccessTypeDef>(ctx)
      .apply([&](auto &def) {
          if (auto *subtype = ctx.subtype_indication()) {
              if (!subtype->selected_name().empty()) {
                  def.pointed_type = subtype->selected_name(0)->getText();
              }
          }
      })
      .build();
}

auto Translator::makeFileType(vhdlParser::File_type_definitionContext &ctx) -> ast::FileTypeDef
{
    return build<ast::FileTypeDef>(ctx)
      .apply([&](auto &def) {
          if (auto *subtype = ctx.subtype_indication()) {
              if (!subtype->selected_name().empty()) {
                  def.content_type = subtype->selected_name(0)->getText();
              }
          }
      })
      .build();
}

} // namespace builder
