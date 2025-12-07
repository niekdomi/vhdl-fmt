#include "ast/nodes/declarations.hpp"
#include "ast/nodes/types.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>
#include <string>
#include <utility>
#include <vector>

namespace builder {

auto Translator::makeTypeDecl(vhdlParser::Type_declarationContext &ctx) -> ast::TypeDecl
{
    const std::string name = ctx.identifier()->getText();
    auto *type_def = ctx.type_definition();

    // 1. Forward Declaration (Incomplete Type)
    if (type_def == nullptr) {
        return build<ast::TypeDecl>(ctx).set(&ast::TypeDecl::name, name).build();
    }

    // 2. Dispatch based on definition type
    ast::TypeDefinition definition{};

    if (auto *scalar = type_def->scalar_type_definition()) {
        if (auto *enum_ctx = scalar->enumeration_type_definition()) {
            definition = makeEnumerationType(*enum_ctx);
        }
        // TODO(vedivad): Handle Integer/Physical/Floating types if added to AST
    } else if (auto *comp = type_def->composite_type_definition()) {
        if (auto *rec_ctx = comp->record_type_definition()) {
            definition = makeRecordType(*rec_ctx);
        } else if (auto *arr_ctx = comp->array_type_definition()) {
            definition = makeArrayType(*arr_ctx);
        }
    } else if (auto *acc_ctx = type_def->access_type_definition()) {
        definition = makeAccessType(*acc_ctx);
    } else if (auto *file_ctx = type_def->file_type_definition()) {
        definition = makeFileType(*file_ctx);
    }

    // Fallback for unsupported types is implicit (monostate/empty variant)

    return build<ast::TypeDecl>(ctx)
      .set(&ast::TypeDecl::name, name)
      .set(&ast::TypeDecl::type_def, std::move(definition))
      .build();
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
    auto extract_array_info = [&](auto *array_ctx, ast::ArrayTypeDef &def) {
        if (array_ctx == nullptr) {
            return;
        }

        auto *subtype = array_ctx->subtype_indication();
        if (subtype && !subtype->selected_name().empty()) {
            def.element_type = subtype->selected_name(0)->getText();
        }
    };

    return build<ast::ArrayTypeDef>(ctx)
      .apply([&](auto &def) {
          if (auto *uncons = ctx.unconstrained_array_definition()) {
              extract_array_info(uncons, def);
              for (auto *idx : uncons->index_subtype_definition()) {
                  if (auto *name = idx->name()) {
                      def.index_types.push_back(name->getText());
                  }
              }
          } else if (auto *cons = ctx.constrained_array_definition()) {
              extract_array_info(cons, def);
              // For constrained, we take the text of the constraint range
              if (auto *constr = cons->index_constraint()) {
                  def.index_types.push_back(constr->getText());
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
