#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeConcurrentStatement(vhdlParser::Architecture_statementContext &ctx)
  -> ast::ConcurrentStatement
{
    return build<ast::ConcurrentStatement>(ctx)
      .maybe(&ast::ConcurrentStatement::label, 
             ctx.label_colon(), 
             [](auto &lc) { return lc.identifier()->getText(); })
      // If no label yet, check if the KIND provides one (e.g. Process)
      .apply([&](auto& stmt) {
          if (!stmt.label.has_value()) {
              if (auto* proc = ctx.process_statement()) {
                  if (auto* pl = proc->label_colon()) {
                      stmt.label = pl->identifier()->getText();
                  }
              }
          }
      })
      .set(&ast::ConcurrentStatement::kind, makeConcurrentStatementKind(ctx))
      .build();
}

auto Translator::makeConcurrentStatementKind(vhdlParser::Architecture_statementContext &ctx)
  -> ast::ConcurrentStmtKind
{
    if (auto *proc = ctx.process_statement()) {
        return makeProcess(*proc);
    }
    
    if (auto *assign = ctx.concurrent_signal_assignment_statement()) {
        return makeConcurrentAssignBody(*assign);
    }

    // TODO(vedivad): Block, Generate, Component Instantiation
    throw std::runtime_error("Unknown concurrent statement kind");
}

} // namespace builder