#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <cstddef>
#include <ranges>
#include <utility>

namespace builder {

auto Translator::makeIfStatement(vhdlParser::If_statementContext *ctx) -> ast::IfStatement
{
    if (ctx == nullptr) {
        return {};
    }

    auto stmt = make<ast::IfStatement>(ctx);

    // Main if branch
    const auto conditions = ctx->condition();
    const auto sequences = ctx->sequence_of_statements();

    if (conditions.empty() || sequences.empty()) {
        return stmt;
    }

    stmt.if_branch.condition = makeExpr(conditions[0]->expression());
    stmt.if_branch.body = makeSequenceOfStatements(sequences[0]);

    // elsif branches - number of elsif branches is conditions.size() - 1 (minus the initial if)
    // If there's an else, the last sequence doesn't have a condition
    for (const auto i : std::views::iota(std::size_t{ 1 }, conditions.size())) {
        ast::IfStatement::Branch elsif_branch;
        elsif_branch.condition = makeExpr(conditions[i]->expression());
        elsif_branch.body = makeSequenceOfStatements(sequences[i]);
        stmt.elsif_branches.push_back(std::move(elsif_branch));
    }

    // else branch - if there are more sequences than conditions, the last one is else
    if (sequences.size() > conditions.size()) {
        ast::IfStatement::Branch else_branch;
        // else has no condition - leave it empty
        else_branch.body = makeSequenceOfStatements(sequences.back());
        stmt.else_branch = std::move(else_branch);
    }

    return stmt;
}

auto Translator::makeCaseStatement(vhdlParser::Case_statementContext *ctx) -> ast::CaseStatement
{
    if (ctx == nullptr) {
        return {};
    }

    auto stmt = make<ast::CaseStatement>(ctx);

    if (auto *expr = ctx->expression()) {
        stmt.selector = makeExpr(expr);
    }

    for (auto *alt : ctx->case_statement_alternative()) {
        ast::CaseStatement::WhenClause when_clause;

        if (auto *choices_ctx = alt->choices()) {
            when_clause.choices = choices_ctx->choice()
                                | std::views::transform([this](auto *ch) { return makeChoice(ch); })
                                | std::ranges::to<std::vector>();
        }

        if (auto *seq = alt->sequence_of_statements()) {
            when_clause.body = makeSequenceOfStatements(seq);
        }

        stmt.when_clauses.push_back(std::move(when_clause));
    }

    return stmt;
}

auto Translator::makeForLoop(vhdlParser::Loop_statementContext *ctx) -> ast::ForLoop
{
    if (ctx == nullptr) {
        return {};
    }

    auto loop = make<ast::ForLoop>(ctx);

    // Extract body
    if (auto *seq = ctx->sequence_of_statements()) {
        loop.body = makeSequenceOfStatements(seq);
    }

    // Extract iteration scheme
    auto *iter = ctx->iteration_scheme();
    if (iter == nullptr) {
        return loop;
    }

    auto *param = iter->parameter_specification();
    if (param == nullptr) {
        return loop;
    }

    // Extract iterator name
    if (auto *id = param->identifier()) {
        loop.iterator = id->getText();
    }

    // Extract range
    auto *discrete = param->discrete_range();
    if (discrete == nullptr) {
        return loop;
    }

    // Handle range_decl
    if (auto *range_decl = discrete->range_decl()) {
        if (auto *explicit_r = range_decl->explicit_range()) {
            loop.range = makeRange(explicit_r);
        } else {
            loop.range = makeToken(range_decl, range_decl->getText());
        }
        return loop;
    }

    // Try subtype_indication
    if (auto *subtype = discrete->subtype_indication()) {
        loop.range = makeToken(subtype, subtype->getText());
    }

    return loop;
}

auto Translator::makeWhileLoop(vhdlParser::Loop_statementContext *ctx) -> ast::WhileLoop
{
    if (ctx == nullptr) {
        return {};
    }

    auto loop = make<ast::WhileLoop>(ctx);

    // Extract body
    if (auto *seq = ctx->sequence_of_statements()) {
        loop.body = makeSequenceOfStatements(seq);
    }

    // Extract condition from iteration scheme
    auto *iter = ctx->iteration_scheme();
    if (iter == nullptr) {
        return loop;
    }

    auto *cond = iter->condition();
    if (cond == nullptr) {
        return loop;
    }

    loop.condition = makeExpr(cond->expression());
    return loop;
}

} // namespace builder
