#include "ast/nodes/statements/sequential.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>

namespace builder {

auto Translator::makeIfStatement(vhdlParser::If_statementContext &ctx) -> ast::IfStatement
{
    return build<ast::IfStatement>(ctx)
      .with(&ctx,
            [&](auto &node, auto &if_ctx) {
                auto conditions = if_ctx.condition();
                auto sequences = if_ctx.sequence_of_statements();

                if (conditions.empty() || sequences.empty()) {
                    return;
                }

                // Main if branch
                node.if_branch.condition = makeExpr(*conditions[0]->expression());
                node.if_branch.body = makeSequenceOfStatements(*sequences[0]);

                // elsif branches
                for (const auto i : std::views::iota(1UZ, conditions.size())) {
                    ast::IfStatement::Branch elsif_branch;
                    elsif_branch.condition = makeExpr(*conditions[i]->expression());
                    elsif_branch.body = makeSequenceOfStatements(*sequences[i]);
                    node.elsif_branches.emplace_back(std::move(elsif_branch));
                }

                // else branch - if there are more sequences than conditions
                if (sequences.size() > conditions.size()) {
                    ast::IfStatement::Branch else_branch;
                    else_branch.body = makeSequenceOfStatements(*sequences.back());
                    node.else_branch = std::move(else_branch);
                }
            })
      .build();
}

} // namespace builder
