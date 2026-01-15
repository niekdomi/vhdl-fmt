#include "ast/nodes/statements/sequential.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>
#include <utility>

namespace builder {

auto Translator::makeIfStatement(vhdlParser::If_statementContext& ctx) -> ast::IfStatement
{
    auto branch_view = std::views::zip(ctx.condition(), ctx.sequence_of_statements());

    return build<ast::IfStatement>(ctx)
      // IF/ELSIF
      .collect(&ast::IfStatement::branches,
               std::move(branch_view),
               [this](const auto& pair) {
                   auto [cond, seq] = pair;

                   ast::IfStatement::ConditionalBranch branch{};
                   branch.condition = makeExpr(*cond->expression());
                   for (auto* stmt : seq->sequential_statement()) {
                       branch.body.emplace_back(makeSequentialStatement(*stmt));
                   }
                   return branch;
               })

      // ELSE (only exists if sequences > conditions)
      .apply([&, this](auto& node) {
          auto sequences = ctx.sequence_of_statements();
          auto conditions = ctx.condition();

          if (sequences.size() > conditions.size()) {
              ast::IfStatement::ElseBranch else_br{};
              for (auto* stmt : sequences.back()->sequential_statement()) {
                  else_br.body.emplace_back(makeSequentialStatement(*stmt));
              }
              node.else_branch = std::move(else_br);
          }
      })
      .build();
}

} // namespace builder
