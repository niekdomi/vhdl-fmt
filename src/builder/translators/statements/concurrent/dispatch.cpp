#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <format>
#include <stdexcept>

namespace builder {

auto Translator::makeConcurrentStatement(vhdlParser::Architecture_statementContext& ctx)
  -> ast::ConcurrentStatement
{
    // TODO(vedivad): Investigate whether to bind trivia here or in the kind
    return build<ast::ConcurrentStatement>(ctx)
      .maybe(&ast::ConcurrentStatement::label,
             ctx.label_colon(),
             [](auto& lc) { return lc.identifier()->getText(); })
      // If no label yet, check if the KIND provides one (e.g. Process)
      .apply([&](auto& stmt) {
          if (!stmt.label.has_value()) {
              // Component has optional label
              if (auto* proc = ctx.process_statement()) {
                  if (auto* pl = proc->label_colon()) {
                      stmt.label = pl->identifier()->getText();
                  }
              }

              // Component instantiation has required label
              if (auto* inst = ctx.component_instantiation_statement()) {
                  if (auto* il = inst->label_colon()) {
                      stmt.label = il->identifier()->getText();
                  }
              }
          }
      })
      .set(&ast::ConcurrentStatement::kind, makeConcurrentStatementKind(ctx))
      .build();
}

auto Translator::makeConcurrentStatementKind(vhdlParser::Architecture_statementContext& ctx)
  -> ast::ConcurrentStmtKind
{
    if (auto* proc = ctx.process_statement()) {
        return makeProcess(*proc);
    }

    if (auto* assign = ctx.concurrent_signal_assignment_statement()) {
        return makeConcurrentAssignBody(*assign);
    }

    if (auto* inst = ctx.component_instantiation_statement()) {
        return makeComponentInstantiation(*inst);
    }

    // TODO(vedivad): Block, Generate
    throw std::runtime_error(
      // NOLINTNEXTLINE(cppcoreguidelines-avoid-magic-numbers, readability-magic-numbers)
      std::format("Unknown concurrent statement kind: {}", ctx.getText().substr(0, 200)));
}

} // namespace builder
