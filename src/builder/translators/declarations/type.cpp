#include "ast/nodes/declarations.hpp"
#include "ast/nodes/types.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeTypeDecl(vhdlParser::Type_declarationContext& ctx) -> ast::TypeDecl
{
    return build<ast::TypeDecl>(ctx)
      .set(&ast::TypeDecl::name, ctx.identifier()->getText())
      .maybe(&ast::TypeDecl::type_def,
             ctx.type_definition(),
             [this](auto& type_ctx) { return makeTypeDefinition(type_ctx); })
      .build();
}

auto Translator::makeTypeDefinition(vhdlParser::Type_definitionContext& ctx) -> ast::TypeDefinition
{
    // Scalar Types (Enum, Physical, Integer/Real via range constraints)
    // Grammar: scalar_type_definition : physical | enumeration | range_constraint
    if (auto* scalar = ctx.scalar_type_definition()) {
        if (auto* enum_ctx = scalar->enumeration_type_definition()) {
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
    else if (auto* comp = ctx.composite_type_definition())
    {
        if (auto* arr_ctx = comp->array_type_definition()) {
            return makeArrayType(*arr_ctx);
        }

        if (auto* rec_ctx = comp->record_type_definition()) {
            return makeRecordType(*rec_ctx);
        }
    }

    // Access Types (Pointers)
    // Grammar: access_type_definition : ACCESS subtype_indication
    else if (auto* acc_ctx = ctx.access_type_definition())
    {
        return makeAccessType(*acc_ctx);
    }

    // File Types
    // Grammar: file_type_definition : FILE OF subtype_indication
    else if (auto* file_ctx = ctx.file_type_definition())
    {
        return makeFileType(*file_ctx);
    }

    // Return empty variant if no known type matched
    return {};
}

} // namespace builder
