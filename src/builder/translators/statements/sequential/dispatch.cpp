#include "ast/nodes/statements.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeSequentialStatement(vhdlParser::Sequential_statementContext& ctx)
  -> ast::SequentialStatement
{
    // The Wrapper Builder: Handles Label & Trivia binding for the whole statement
    return build<ast::SequentialStatement>(ctx)
      .maybe(&ast::SequentialStatement::label,
             ctx.label_colon(),
             [](auto& lc) { return lc.identifier()->getText(); })
      .apply([&](auto& wrapper) {
          // Check if the label is already set
          if (wrapper.label.has_value()) {
              return;
          }

          // Try to find a label on the other statement types
          if (auto* loop = ctx.loop_statement()) {
              if (auto* lbl = loop->label_colon()) {
                  wrapper.label = lbl->identifier()->getText();
              }
          }

          if (auto* case_stmt = ctx.case_statement()) {
              if (auto* lbl = case_stmt->label_colon()) {
                  wrapper.label = lbl->identifier()->getText();
              }
          }
      })
      .set(&ast::SequentialStatement::kind, makeSequentialStatementKind(ctx))
      .build();
}

auto Translator::makeSequentialStatementKind(vhdlParser::Sequential_statementContext& ctx)
  -> ast::SequentialStmtKind
{
    if (auto* sig = ctx.signal_assignment_statement()) {
        return makeSignalAssign(*sig);
    }
    if (auto* var = ctx.variable_assignment_statement()) {
        return makeVariableAssign(*var);
    }
    if (auto* if_stmt = ctx.if_statement()) {
        return makeIfStatement(*if_stmt);
    }
    if (auto* case_stmt = ctx.case_statement()) {
        return makeCaseStatement(*case_stmt);
    }
    if (auto* loop = ctx.loop_statement()) {
        // Loop logic delegates to specific loop makers
        if (auto* iter = loop->iteration_scheme()) {
            if (iter->parameter_specification() != nullptr) {
                return makeForLoop(*loop);
            }
            if (iter->condition() != nullptr) {
                return makeWhileLoop(*loop);
            }
        }
        return makeLoop(*loop);
    }
    if (ctx.NULL_() != nullptr) {
        return ast::NullStatement{};
    }

    // TODO(vedivad): Return std::expected error or throw for unknown statement
    return ast::NullStatement{};
}

} // namespace builder
