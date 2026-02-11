#include "ast/nodes/statements/concurrent.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>

namespace builder {

auto Translator::makeComponentInstantiation(
  vhdlParser::Component_instantiation_statementContext& ctx) -> ast::ComponentInstantiation
{
    auto* inst_unit = ctx.instantiated_unit();

    std::string entity_name;
    std::optional<std::string> architecture;
    bool is_entity = false;

    // Parse instantiated_unit: either "component name" or "entity name (arch)"
    if (inst_unit->ENTITY() != nullptr) {
        is_entity = true;
        entity_name = inst_unit->name()->getText();

        // Check for architecture name: entity work.foo(rtl)
        if (inst_unit->identifier() != nullptr) {
            architecture = inst_unit->identifier()->getText();
        }
    } else {
        // Plain component name
        entity_name = inst_unit->name()->getText();
    }

    // Parse generic_map_aspect (if present)
    std::vector<ast::Expr> generic_map;
    if (auto* gen_map = ctx.generic_map_aspect()) {
        if (auto* assoc_list = gen_map->association_list()) {
            generic_map = assoc_list->association_element()
                        | std::views::transform([&](auto* elem) { return makeCallArgument(*elem); })
                        | std::ranges::to<std::vector<ast::Expr>>();
        }
    }

    // Parse port_map_aspect (if present)
    std::vector<ast::Expr> port_map;
    if (auto* prt_map = ctx.port_map_aspect()) {
        if (auto* assoc_list = prt_map->association_list()) {
            port_map = assoc_list->association_element()
                     | std::views::transform([&](auto* elem) { return makeCallArgument(*elem); })
                     | std::ranges::to<std::vector<ast::Expr>>();
        }
    }

    return build<ast::ComponentInstantiation>(ctx)
      .set(&ast::ComponentInstantiation::entity_name, std::move(entity_name))
      .set(&ast::ComponentInstantiation::architecture, std::move(architecture))
      .set(&ast::ComponentInstantiation::is_entity, is_entity)
      .set(&ast::ComponentInstantiation::generic_map, std::move(generic_map))
      .set(&ast::ComponentInstantiation::port_map, std::move(port_map))
      .build();
}

} // namespace builder
