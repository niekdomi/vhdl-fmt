#ifndef BUILDER_TRANSLATOR_HPP
#define BUILDER_TRANSLATOR_HPP

#include "ast/nodes/declarations.hpp"
#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/declarations/objects.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "ast/nodes/statements/waveform.hpp"
#include "ast/nodes/types.hpp"
#include "builder/node_builder.hpp"
#include "builder/trivia/trivia_binder.hpp"
#include "vhdlParser.h"

#include <optional>
#include <ranges>
#include <string>
#include <utility>
#include <vector>

namespace builder {

class Translator final
{
    TriviaBinder trivia_;

  public:
    explicit Translator(antlr4::CommonTokenStream &tokens) : trivia_(tokens) {}

    /// @brief Build the entire design file by walking the CST
    void buildDesignFile(ast::DesignFile &dest, vhdlParser::Design_fileContext *ctx);

    ~Translator() = default;

    Translator(const Translator &) = delete;
    auto operator=(const Translator &) -> Translator & = delete;
    Translator(Translator &&) = delete;
    auto operator=(Translator &&) -> Translator & = delete;

  private:
    // Design units
    [[nodiscard]]
    auto makeArchitecture(vhdlParser::Architecture_bodyContext &ctx) -> ast::Architecture;
    [[nodiscard]]
    auto makeArchitectureDeclarativeItem(vhdlParser::Block_declarative_itemContext &ctx)
      -> ast::Declaration;
    [[nodiscard]]
    auto makeEntity(vhdlParser::Entity_declarationContext &ctx) -> ast::Entity;

    // Clauses
    [[nodiscard]]
    auto makeGenericClause(vhdlParser::Generic_clauseContext &ctx) -> ast::GenericClause;
    [[nodiscard]]
    auto makePortClause(vhdlParser::Port_clauseContext &ctx) -> ast::PortClause;

    // Context clauses
    [[nodiscard]]
    auto makeContextClause(vhdlParser::Context_clauseContext &ctx) -> std::vector<ast::ContextItem>;
    [[nodiscard]]
    auto makeLibraryClause(vhdlParser::Library_clauseContext &ctx) -> ast::LibraryClause;
    [[nodiscard]]
    auto makeUseClause(vhdlParser::Use_clauseContext &ctx) -> ast::UseClause;

    // Declarations
    [[nodiscard]]
    auto makeComponentDecl(vhdlParser::Component_declarationContext &ctx) -> ast::ComponentDecl;
    [[nodiscard]]
    auto makeConstantDecl(vhdlParser::Constant_declarationContext &ctx) -> ast::ConstantDecl;
    [[nodiscard]]
    auto makeGenericParam(vhdlParser::Interface_constant_declarationContext &ctx)
      -> ast::GenericParam;
    [[nodiscard]]
    auto makeSignalDecl(vhdlParser::Signal_declarationContext &ctx) -> ast::SignalDecl;
    [[nodiscard]]
    auto makeSignalPort(vhdlParser::Interface_port_declarationContext &ctx) -> ast::Port;
    [[nodiscard]]
    auto makeVariableDecl(vhdlParser::Variable_declarationContext &ctx) -> ast::VariableDecl;
    [[nodiscard]]
    auto makeTypeDecl(vhdlParser::Type_declarationContext &ctx) -> ast::TypeDecl;

    // Type Definitions
    [[nodiscard]]
    auto makeTypeDefinition(vhdlParser::Type_definitionContext &ctx) -> ast::TypeDefinition;
    [[nodiscard]]
    auto makeEnumerationType(vhdlParser::Enumeration_type_definitionContext &ctx)
      -> ast::EnumerationTypeDef;
    [[nodiscard]]
    auto makeRecordType(vhdlParser::Record_type_definitionContext &ctx) -> ast::RecordTypeDef;
    [[nodiscard]]
    auto makeRecordElement(vhdlParser::Element_declarationContext &ctx) -> ast::RecordElement;
    [[nodiscard]]
    auto makeArrayType(vhdlParser::Array_type_definitionContext &ctx) -> ast::ArrayTypeDef;
    [[nodiscard]]
    auto makeUnconstrainedArray(vhdlParser::Unconstrained_array_definitionContext &ctx)
      -> ast::ArrayTypeDef;
    [[nodiscard]]
    auto makeConstrainedArray(vhdlParser::Constrained_array_definitionContext &ctx)
      -> ast::ArrayTypeDef;
    [[nodiscard]]
    auto makeAccessType(vhdlParser::Access_type_definitionContext &ctx) -> ast::AccessTypeDef;
    [[nodiscard]]
    auto makeFileType(vhdlParser::File_type_definitionContext &ctx) -> ast::FileTypeDef;

    // Statements
    [[nodiscard]]
    auto makeConcurrentStatement(vhdlParser::Architecture_statementContext &ctx)
      -> ast::ConcurrentStatement;
    [[nodiscard]]
    auto makeSequentialStatement(vhdlParser::Sequential_statementContext &ctx)
      -> ast::SequentialStatement;
    [[nodiscard]]
    auto makeSequenceOfStatements(vhdlParser::Sequence_of_statementsContext &ctx)
      -> std::vector<ast::SequentialStatement>;

    // Statements (Kind Dispatchers)
    [[nodiscard]]
    auto makeSequentialStatementKind(vhdlParser::Sequential_statementContext &ctx)
      -> ast::SequentialStmtKind;
    [[nodiscard]]
    auto makeConcurrentStatementKind(vhdlParser::Architecture_statementContext &ctx)
      -> ast::ConcurrentStmtKind;

    [[nodiscard]]
    auto makeCaseStatement(vhdlParser::Case_statementContext &ctx) -> ast::CaseStatement;
    [[nodiscard]]
    auto makeConcurrentAssignBody(vhdlParser::Concurrent_signal_assignment_statementContext &ctx)
      -> ast::ConcurrentStmtKind;
    [[nodiscard]]
    auto makeConditionalAssign(vhdlParser::Conditional_signal_assignmentContext &ctx)
      -> ast::ConditionalConcurrentAssign;
    [[nodiscard]]
    auto makeConditionalWaveform(vhdlParser::Conditional_waveformsContext &ctx)
      -> ast::ConditionalConcurrentAssign::ConditionalWaveform;
    [[nodiscard]]
    auto makeForLoop(vhdlParser::Loop_statementContext &ctx) -> ast::ForLoop;
    [[nodiscard]]
    auto makeIfStatement(vhdlParser::If_statementContext &ctx) -> ast::IfStatement;
    [[nodiscard]]
    auto makeLoop(vhdlParser::Loop_statementContext &ctx) -> ast::Loop;
    [[nodiscard]]
    auto makeProcess(vhdlParser::Process_statementContext &ctx) -> ast::Process;
    [[nodiscard]]
    auto makeProcessDeclarativeItem(vhdlParser::Process_declarative_itemContext &ctx)
      -> ast::Declaration;
    [[nodiscard]]
    auto makeProcessStatementPart(vhdlParser::Process_statement_partContext &ctx)
      -> std::vector<ast::SequentialStatement>;
    [[nodiscard]]
    auto makeSelectedAssign(vhdlParser::Selected_signal_assignmentContext &ctx)
      -> ast::SelectedConcurrentAssign;
    [[nodiscard]]
    auto makeSelection(vhdlParser::WaveformContext &wave, vhdlParser::ChoicesContext &choices)
      -> ast::SelectedConcurrentAssign::Selection;
    [[nodiscard]]
    auto makeSignalAssign(vhdlParser::Signal_assignment_statementContext &ctx) -> ast::SignalAssign;
    [[nodiscard]]
    auto makeTarget(vhdlParser::TargetContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeVariableAssign(vhdlParser::Variable_assignment_statementContext &ctx)
      -> ast::VariableAssign;
    [[nodiscard]]
    auto makeWaveform(vhdlParser::WaveformContext &ctx) -> ast::Waveform;
    [[nodiscard]]
    auto makeWaveformElement(vhdlParser::Waveform_elementContext &ctx) -> ast::Waveform::Element;
    [[nodiscard]]
    auto makeWhenClause(vhdlParser::Case_statement_alternativeContext &ctx)
      -> ast::CaseStatement::WhenClause;
    [[nodiscard]]
    auto makeWhileLoop(vhdlParser::Loop_statementContext &ctx) -> ast::WhileLoop;

    // Expressions
    [[nodiscard]]
    auto makeAggregate(vhdlParser::AggregateContext &ctx) -> ast::GroupExpr;
    [[nodiscard]]
    auto makeAllocator(vhdlParser::AllocatorContext &ctx) -> ast::UnaryExpr;
    [[nodiscard]]
    auto makeAttributeExpr(ast::Expr base, vhdlParser::Attribute_name_partContext &ctx)
      -> ast::Expr;
    [[nodiscard]]
    auto makeCallArgument(vhdlParser::Association_elementContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeCallExpr(ast::Expr base, vhdlParser::Function_call_or_indexed_name_partContext &ctx)
      -> ast::Expr;
    [[nodiscard]]
    auto makeChoice(vhdlParser::ChoiceContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeChoices(vhdlParser::ChoicesContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeDiscreteRange(vhdlParser::Discrete_rangeContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeElementAssociation(vhdlParser::Element_associationContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeExpr(vhdlParser::ExpressionContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeFactor(vhdlParser::FactorContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeLiteral(vhdlParser::LiteralContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeName(vhdlParser::NameContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makePrimary(vhdlParser::PrimaryContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeQualifiedExpr(vhdlParser::Qualified_expressionContext &ctx) -> ast::QualifiedExpr;
    [[nodiscard]]
    auto makeRange(vhdlParser::Explicit_rangeContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeRelation(vhdlParser::RelationContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeShiftExpr(vhdlParser::Shift_expressionContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeSimpleExpr(vhdlParser::Simple_expressionContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeSliceExpr(ast::Expr base, vhdlParser::Slice_name_partContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeTerm(vhdlParser::TermContext &ctx) -> ast::Expr;
    [[nodiscard]]
    auto makeSubtypeIndication(vhdlParser::Subtype_indicationContext &ctx)
      -> ast::SubtypeIndication;

    // Constraints
    [[nodiscard]]
    auto makeConstraint(vhdlParser::ConstraintContext &ctx) -> std::optional<ast::Constraint>;
    [[nodiscard]]
    auto makeIndexConstraint(vhdlParser::Index_constraintContext &ctx) -> ast::IndexConstraint;
    [[nodiscard]]
    auto makeRangeConstraint(vhdlParser::Range_constraintContext &ctx)
      -> std::optional<ast::RangeConstraint>;

    /// @brief Factory to create a NodeBuilder with trivia already bound
    template<typename T, typename Ctx>
    [[nodiscard]]
    auto build(Ctx &ctx) -> NodeBuilder<T>
    {
        return NodeBuilder<T>(ctx, trivia_);
    }

    /// @brief Helper to create binary expressions
    template<typename Ctx>
    [[nodiscard]]
    auto makeBinary(Ctx &ctx, std::string op, ast::Expr left, ast::Expr right) -> ast::BinaryExpr
    {
        return build<ast::BinaryExpr>(ctx)
          .set(&ast::BinaryExpr::op, std::move(op))
          .setBox(&ast::BinaryExpr::left, std::move(left))
          .setBox(&ast::BinaryExpr::right, std::move(right))
          .build();
    }

    /// @brief Helper to create unary expressions
    template<typename Ctx>
    [[nodiscard]]
    auto makeUnary(Ctx &ctx, std::string op, ast::Expr value) -> ast::UnaryExpr
    {
        return build<ast::UnaryExpr>(ctx)
          .set(&ast::UnaryExpr::op, std::move(op))
          .setBox(&ast::UnaryExpr::value, std::move(value))
          .build();
    }

    /// @brief Helper to create token expressions
    template<typename Ctx>
    [[nodiscard]]
    auto makeToken(Ctx &ctx, std::string text) -> ast::TokenExpr
    {
        return build<ast::TokenExpr>(ctx).set(&ast::TokenExpr::text, std::move(text)).build();
    }

    /// @brief Helper to create token expressions using ctx.getText()
    template<typename Ctx>
    [[nodiscard]]
    auto makeToken(Ctx &ctx) -> ast::TokenExpr
    {
        return makeToken(ctx, ctx.getText());
    }

    /// @brief Helper to fold binary operators left-associatively.
    /// Used for expression chains like: a op1 b op2 c → ((a op1 b) op2 c)
    /// @param ctx The parent context (for trivia binding on intermediate nodes).
    /// @param operands Range of operand contexts.
    /// @param operators Range of operator contexts (size = operands.size() - 1).
    /// @param make_operand Function to transform an operand context to ast::Expr.
    template<typename Ctx, typename Operands, typename Operators, typename MakeOperand>
    [[nodiscard]]
    auto foldBinaryLeft(Ctx &ctx, Operands &&operands, Operators &&operators, MakeOperand &&make_op)
      -> ast::Expr
    {
        const auto op_range = std::forward<Operands>(operands);
        const auto end = std::forward<Operators>(operators);
        const auto it = std::ranges::begin(op_range);

        ast::Expr acc = std::forward<MakeOperand>(make_op)(**it);

        for (const auto &[operand, op] : std::views::zip(op_range | std::views::drop(1), end)) {
            acc = makeBinary(ctx, op->getText(), std::move(acc), make_op(*operand));
        }

        return acc;
    }

    static auto extractNames(vhdlParser::Identifier_listContext *ctx) -> std::vector<std::string>
    {
        if (ctx == nullptr) {
            return {};
        }

        return ctx->identifier()
             | std::views::transform([](auto *id) { return id->getText(); })
             | std::ranges::to<std::vector>();
    }

    static auto extractTypeName(vhdlParser::Subtype_indicationContext *ctx) -> std::string
    {
        if (ctx == nullptr || ctx->selected_name().empty()) {
            return {};
        }

        return ctx->selected_name(0)->getText();
    }

    static auto extractTypeFullText(vhdlParser::Subtype_indicationContext *ctx) -> std::string
    {
        if (ctx == nullptr) {
            return {};
        }

        return ctx->getText();
    }

    static auto extractMode(vhdlParser::Signal_modeContext *ctx) -> std::string
    {
        if (ctx == nullptr) {
            return {};
        }

        return ctx->getText();
    }

    template<typename Node>
    static void extractSubtypeInfo(Node &node,
                                   vhdlParser::Subtype_indicationContext *stype,
                                   auto &&make_constraint_fn)
    {
        if (stype == nullptr) {
            return;
        }

        node.type_name = extractTypeName(stype);
        if (auto *constr = stype->constraint()) {
            node.constraint = make_constraint_fn(*constr);
        }
    }
};

} // namespace builder

#endif /* BUILDER_TRANSLATOR_HPP */
