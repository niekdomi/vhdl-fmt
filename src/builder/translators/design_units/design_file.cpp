#include "ast/nodes/design_file.hpp"

#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <stdexcept>

namespace builder {

auto Translator::buildDesignFile(vhdlParser::Design_fileContext* ctx) -> ast::DesignFile
{
    // No trivia binding here as the children should bind them instead
    return buildNoTrivia<ast::DesignFile>()
      .collect(&ast::DesignFile::units,
               ctx->design_unit(),
               [this](auto* unit_ctx) { return makeDesignUnit(unit_ctx); })
      .build();
}

auto Translator::makeDesignUnit(vhdlParser::Design_unitContext* ctx) -> ast::DesignUnit
{
    auto* lib_unit_ctx = ctx->library_unit();
    if (lib_unit_ctx == nullptr) {
        return {};
    }

    // No trivia binding here as the children should bind them instead
    return buildNoTrivia<ast::DesignUnit>()
      .collectFrom(
        &ast::DesignUnit::context,
        ctx->context_clause(),
        [](auto& cc) { return cc.context_item(); },
        [this](auto* item) { return makeContextItem(item); })
      .set(&ast::DesignUnit::unit, makeLibraryUnit(lib_unit_ctx))
      .build();
}

auto Translator::makeLibraryUnit(vhdlParser::Library_unitContext* ctx) -> ast::LibraryUnit
{
    // Primary Unit (Entity, Configuration, Package Decl)
    if (auto* primary = ctx->primary_unit()) {
        if (auto* ent = primary->entity_declaration()) {
            return makeEntity(*ent);
        }
        // TODO(vedivad): Configuration
        // TODO(vedivad): Package Declaration
    }

    // Secondary Unit (Architecture, Package Body)
    if (auto* secondary = ctx->secondary_unit()) {
        if (auto* arch = secondary->architecture_body()) {
            return makeArchitecture(*arch);
        }
        // TODO(vedivad): Package Body
    }

    // The parser context exists but matches a node type we don't handle yet
    throw std::runtime_error("Unknown or unimplemented library unit type");
}

} // namespace builder
