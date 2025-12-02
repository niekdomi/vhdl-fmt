#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <cstddef>
#include <ranges>
#include <utility>

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
    return build<ast::ForLoop>(ctx)
      .with(ctx.iteration_scheme(),
            [&](auto &node, auto &iter) {
                if (auto *param = iter.parameter_specification()) {
                    if (auto *id = param->identifier()) {
                        node.iterator = id->getText();
                    }
                    if (auto *range = param->discrete_range()) {
                        if (auto *range_decl = range->range_decl()) {
                            if (auto *explicit_r = range_decl->explicit_range()) {
                                node.range = makeRange(*explicit_r);
                            } else {
                                auto tok = make<ast::TokenExpr>(*range_decl);
                                tok.text = range_decl->getText();
                                node.range = std::move(tok);
                            }
                        } else if (auto *subtype = range->subtype_indication()) {
                            auto tok = make<ast::TokenExpr>(*subtype);
                            tok.text = subtype->getText();
                            node.range = std::move(tok);
                        }
                    }
                }
            })
      .maybe(&ast::ForLoop::body,
             ctx.sequence_of_statements(),
             [&](auto &seq) { return makeSequenceOfStatements(seq); })
      .build();
}

auto Translator::makeWhileLoop(vhdlParser::Loop_statementContext &ctx) -> ast::WhileLoop
{
    return build<ast::WhileLoop>(ctx)
      .with(ctx.iteration_scheme(),
            [&](auto &node, auto &iter) {
                if (auto *cond = iter.condition()) {
                    node.condition = makeExpr(*cond->expression());
                }
            })
      .maybe(&ast::WhileLoop::body,
             ctx.sequence_of_statements(),
             [&](auto &seq) { return makeSequenceOfStatements(seq); })
      .build();
}

} // namespace builder
