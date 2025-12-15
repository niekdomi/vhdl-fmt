#include "ast/nodes/design_file.hpp"

#include "ast/nodes/design_units.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <utility>
#include <vector>

namespace builder {

auto Translator::buildDesignFile(vhdlParser::Design_fileContext *ctx) -> ast::DesignFile
{
    ast::DesignFile node{};

    for (auto *unit_ctx : ctx->design_unit()) {
        auto *lib_unit = unit_ctx->library_unit();
        if (lib_unit == nullptr) {
            continue;
        }

        // Parse context clause (library and use clauses)
        std::vector<ast::ContextItem> context{};
        if (auto *context_ctx = unit_ctx->context_clause()) {
            context = makeContextClause(*context_ctx);
        }

        // Check primary units (entity_declaration | configuration_declaration |
        // package_declaration)
        if (auto *primary = lib_unit->primary_unit()) {
            if (auto *entity_ctx = primary->entity_declaration()) {
                ast::DesignUnit du{};
                du.context = std::move(context);
                du.unit = makeEntity(*entity_ctx);
                node.units.emplace_back(std::move(du));
            }
            // TODO(someone): Handle configuration_declaration and package_declaration
        }
        // Check secondary units (architecture_body | package_body)
        else if (auto *secondary = lib_unit->secondary_unit()) {
            if (auto *arch_ctx = secondary->architecture_body()) {
                ast::DesignUnit du{};
                du.context = std::move(context);
                du.unit = makeArchitecture(*arch_ctx);
                node.units.emplace_back(std::move(du));
            }
            // TODO(someone): Handle package_body
        }
    }

    return node;
}

} // namespace builder
