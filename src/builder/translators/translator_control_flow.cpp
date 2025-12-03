#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <cstddef>
#include <ranges>
#include <utility>
#include <vector>

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
                for (const auto i : std::views::iota(std::size_t{ 1 }, conditions.size())) {
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

auto Translator::makeCaseStatement(vhdlParser::Case_statementContext &ctx) -> ast::CaseStatement
{
    return build<ast::CaseStatement>(ctx)
      .maybe(
        &ast::CaseStatement::selector, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .collect(&ast::CaseStatement::when_clauses,
               ctx.case_statement_alternative(),
               [&](auto *alt) {
                   ast::CaseStatement::WhenClause when_clause;
                   if (auto *choices_ctx = alt->choices()) {
                       when_clause.choices
                         = choices_ctx->choice()
                         | std::views::transform([this](auto *ch) { return makeChoice(*ch); })
                         | std::ranges::to<std::vector>();
                   }
                   if (auto *seq = alt->sequence_of_statements()) {
                       when_clause.body = makeSequenceOfStatements(*seq);
                   }
                   return when_clause;
               })
      .build();
}

auto Translator::makeForLoop(vhdlParser::Loop_statementContext &ctx) -> ast::ForLoop
{
    auto *iter = ctx.iteration_scheme();
    auto *param = iter ? iter->parameter_specification() : nullptr;

    return build<ast::ForLoop>(ctx)
      .maybe(&ast::ForLoop::iterator,
             (param != nullptr) ? param->identifier() : nullptr,
             [](auto &id) { return id.getText(); })
      .maybe(&ast::ForLoop::range,
             (param != nullptr) ? param->discrete_range() : nullptr,
             [&](auto &dr) { return makeDiscreteRange(dr); })
      .maybe(&ast::ForLoop::body,
             ctx.sequence_of_statements(),
             [&](auto &seq) { return makeSequenceOfStatements(seq); })
      .build();
}

auto Translator::makeWhileLoop(vhdlParser::Loop_statementContext &ctx) -> ast::WhileLoop
{
    auto *iter = ctx.iteration_scheme();
    auto *cond = iter ? iter->condition() : nullptr;

    return build<ast::WhileLoop>(ctx)
      .maybe(&ast::WhileLoop::condition,
             cond ? cond->expression() : nullptr,
             [&](auto &expr) { return makeExpr(expr); })
      .maybe(&ast::WhileLoop::body,
             ctx.sequence_of_statements(),
             [&](auto &seq) { return makeSequenceOfStatements(seq); })
      .build();
}

} // namespace builder
