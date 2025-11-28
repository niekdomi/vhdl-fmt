#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <algorithm>
#include <optional>
#include <ranges>
#include <type_traits>
#include <utility>

namespace builder {

namespace {

auto cloneExpr(const ast::Expr &expr) -> ast::Expr
{
    return std::visit(
      [](const auto &node) -> ast::Expr {
          using T = std::decay_t<decltype(node)>;
          if constexpr (std::is_same_v<T, ast::TokenExpr>) {
              return node;
          } else if constexpr (std::is_same_v<T, ast::GroupExpr>) {
              ast::GroupExpr copy{};
              copy.trivia = node.trivia;
              copy.children.reserve(node.children.size());
              for (const auto &child : node.children) {
                  copy.children.push_back(cloneExpr(child));
              }
              return copy;
          } else if constexpr (std::is_same_v<T, ast::UnaryExpr>) {
              ast::UnaryExpr copy{};
              copy.trivia = node.trivia;
              copy.op = node.op;
              if (node.value != nullptr) {
                  copy.value = std::make_unique<ast::Expr>(cloneExpr(*node.value));
              }
              return copy;
          } else if constexpr (std::is_same_v<T, ast::BinaryExpr>) {
              ast::BinaryExpr copy{};
              copy.trivia = node.trivia;
              copy.op = node.op;
              if (node.left != nullptr) {
                  copy.left = std::make_unique<ast::Expr>(cloneExpr(*node.left));
              }
              if (node.right != nullptr) {
                  copy.right = std::make_unique<ast::Expr>(cloneExpr(*node.right));
              }
              return copy;
          } else if constexpr (std::is_same_v<T, ast::ParenExpr>) {
              ast::ParenExpr copy{};
              copy.trivia = node.trivia;
              if (node.inner != nullptr) {
                  copy.inner = std::make_unique<ast::Expr>(cloneExpr(*node.inner));
              }
              return copy;
          } else if constexpr (std::is_same_v<T, ast::CallExpr>) {
              ast::CallExpr copy{};
              copy.trivia = node.trivia;
              if (node.callee != nullptr) {
                  copy.callee = std::make_unique<ast::Expr>(cloneExpr(*node.callee));
              }
              if (node.args != nullptr) {
                  copy.args = std::make_unique<ast::Expr>(cloneExpr(*node.args));
              }
              return copy;
          }
          return ast::Expr{};
      },
      expr);
}

} // namespace

auto Translator::makeConcurrentAssign(
  vhdlParser::Concurrent_signal_assignment_statementContext *ctx) -> ast::ConcurrentAssign
{
    if (ctx == nullptr) {
        return {};
    }

    // Dispatch based on concrete assignment type
    if (auto *cond = ctx->conditional_signal_assignment()) {
        return makeConditionalAssign(cond);
    }

    if (auto *sel = ctx->selected_signal_assignment()) {
        return makeSelectedAssign(sel);
    }

    // Fallback for unhandled cases
    return make<ast::ConcurrentAssign>(ctx);
}

auto Translator::makeConditionalAssign(vhdlParser::Conditional_signal_assignmentContext *ctx)
  -> ast::ConcurrentAssign
{
    if (ctx == nullptr) {
        return {};
    }

    const auto extract_wave_expr
      = [this](vhdlParser::WaveformContext &wave_ctx) -> std::optional<ast::Expr> {
        const auto elems = wave_ctx.waveform_element();
        if (elems.empty() || elems[0]->expression().empty()) {
            return std::nullopt;
        }
        return makeExpr(elems[0]->expression(0));
    };

    auto assign = make<ast::ConcurrentAssign>(ctx);

    if (auto *target_ctx = ctx->target()) {
        assign.target = makeTarget(target_ctx);
    }

    auto *cond_wave = ctx->conditional_waveforms();
    if (cond_wave == nullptr) {
        return assign;
    }

    for (auto *current = cond_wave; current != nullptr;
         current = current->conditional_waveforms()) {
        auto *wave = current->waveform();
        if (wave == nullptr) {
            continue;
        }

        auto value = extract_wave_expr(*wave);
        if (!value.has_value()) {
            continue;
        }

        ast::ConditionalWaveform waveform{};
        waveform.value = std::move(*value);

        if (auto *cond_ctx = current->condition()) {
            if (auto *expr_ctx = cond_ctx->expression()) {
                waveform.condition = makeExpr(expr_ctx);
            }
        }

        assign.conditional_waveforms.push_back(std::move(waveform));
    }

    if (!assign.conditional_waveforms.empty()) {
        assign.value = cloneExpr(assign.conditional_waveforms.front().value);
    }

    return assign;
}

auto Translator::makeSelectedAssign(vhdlParser::Selected_signal_assignmentContext *ctx)
  -> ast::ConcurrentAssign
{
    if (ctx == nullptr) {
        return {};
    }

    const auto extract_wave_expr
      = [this](vhdlParser::WaveformContext &wave_ctx) -> std::optional<ast::Expr> {
        const auto elems = wave_ctx.waveform_element();
        if (elems.empty() || elems[0]->expression().empty()) {
            return std::nullopt;
        }
        return makeExpr(elems[0]->expression(0));
    };

    auto assign = make<ast::ConcurrentAssign>(ctx);

    if (auto *target_ctx = ctx->target()) {
        assign.target = makeTarget(target_ctx);
    }

    if (auto *selector = ctx->expression()) {
        assign.select = makeExpr(selector);
    }

    auto *sel_waves = ctx->selected_waveforms();
    if (sel_waves == nullptr) {
        return assign;
    }

    const auto waves = sel_waves->waveform();
    const auto choices = sel_waves->choices();
    const auto count = std::min(waves.size(), choices.size());

    for (std::size_t i = 0; i < count; ++i) {
        auto value = extract_wave_expr(*waves[i]);
        if (!value.has_value()) {
            continue;
        }

        ast::SelectedWaveform waveform{};
        waveform.value = std::move(*value);

        waveform.choices = choices[i]->choice()
                         | std::views::transform([this](auto *ch) { return makeChoice(ch); })
                         | std::ranges::to<std::vector>();

        assign.selected_waveforms.push_back(std::move(waveform));
    }

    if (!assign.selected_waveforms.empty()) {
        assign.value = cloneExpr(assign.selected_waveforms.front().value);
    }

    return assign;
}

auto Translator::makeProcess(vhdlParser::Process_statementContext *ctx) -> ast::Process
{
    if (ctx == nullptr) {
        return {};
    }

    auto proc = make<ast::Process>(ctx);

    // Extract label if present
    if (auto *label = ctx->label_colon()) {
        if (auto *id = label->identifier()) {
            proc.label = id->getText();
        }
    }

    // Extract sensitivity list
    if (auto *sens_list = ctx->sensitivity_list()) {
        proc.sensitivity_list = sens_list->name()
                              | std::views::transform([](auto *name) { return name->getText(); })
                              | std::ranges::to<std::vector>();
    }

    // Extract sequential statements
    if (auto *stmt_part = ctx->process_statement_part()) {
        proc.body
          = stmt_part->sequential_statement()
          | std::views::transform([this](auto *stmt) { return makeSequentialStatement(stmt); })
          | std::ranges::to<std::vector>();
    }

    return proc;
}

} // namespace builder
