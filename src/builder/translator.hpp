#ifndef BUILDER_TRANSLATOR_HPP
#define BUILDER_TRANSLATOR_HPP

#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/trivia/trivia_binder.hpp"
#include "vhdlParser.h"

#include <CommonTokenStream.h>
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

namespace builder {

class Translator final
{
    TriviaBinder trivia_;
    antlr4::CommonTokenStream &tokens_;

  public:
    explicit Translator(antlr4::CommonTokenStream &tokens) : trivia_(tokens), tokens_(tokens) {}

    /// @brief Build the entire design file by walking the CST
    void buildDesignFile(ast::DesignFile &dest, vhdlParser::Design_fileContext &ctx);

    ~Translator() = default;

    Translator(const Translator &) = delete;
    auto operator=(const Translator &) -> Translator & = delete;
    Translator(Translator &&) = delete;
    auto operator=(Translator &&) -> Translator & = delete;

  private:
    // reference: https://faculty-web.msoe.edu/johnsontimoj/Common/FILES/VHDL_2008.pdf

    // clang-format off

    // Design units
    [[nodiscard]] auto makeArchitecture(vhdlParser::Architecture_bodyContext *ctx) -> ast::Architecture;
    [[nodiscard]] auto makeContextClause(vhdlParser::Context_clauseContext *ctx) -> std::vector<ast::ContextItem>;
    [[nodiscard]] auto makeContextDeclaration(vhdlParser::Context_declarationContext *ctx) -> ast::ContextDeclaration;
    [[nodiscard]] auto makeContextItem(vhdlParser::Context_itemContext *ctx) -> ast::ContextItem;
    [[nodiscard]] auto makeEntity(vhdlParser::Entity_declarationContext *ctx) -> ast::Entity;
    [[nodiscard]] auto makeLibraryClause(vhdlParser::Library_clauseContext *ctx) -> ast::LibraryClause;
    [[nodiscard]] auto makeUseClause(vhdlParser::Use_clauseContext *ctx) -> ast::UseClause;

    // Clauses
    [[nodiscard]] auto makeGenericClause(vhdlParser::Generic_clauseContext *ctx) -> ast::GenericClause;
    [[nodiscard]] auto makePortClause(vhdlParser::Port_clauseContext *ctx) -> ast::PortClause;

    // Declarations
    [[nodiscard]] auto makeAliasDecl(vhdlParser::Alias_declarationContext *ctx) -> ast::AliasDecl;
    [[nodiscard]] auto makeConstantDecl(vhdlParser::Constant_declarationContext *ctx) -> ast::ConstantDecl;
    [[nodiscard]] auto makeFunction(vhdlParser::Function_specificationContext *ctx) -> ast::FunctionDecl;
    [[nodiscard]] auto makeGenericParam(vhdlParser::Interface_constant_declarationContext *ctx, bool is_last) -> ast::GenericParam;
    [[nodiscard]] auto makeParameterList(vhdlParser::Formal_parameter_listContext *ctx) -> std::vector<ast::SubprogramParam>;
    [[nodiscard]] auto makeProcedure(vhdlParser::Procedure_specificationContext *ctx) -> ast::ProcedureDecl;
    [[nodiscard]] auto makeSignalDecl(vhdlParser::Signal_declarationContext *ctx) -> ast::SignalDecl;
    [[nodiscard]] auto makeSignalPort(vhdlParser::Interface_port_declarationContext *ctx, bool is_last) -> ast::Port;
    [[nodiscard]] auto makeSubprogramBody(vhdlParser::Subprogram_bodyContext *ctx) -> std::optional<ast::Declaration>;
    [[nodiscard]] auto makeSubprogramDeclaration(vhdlParser::Subprogram_declarationContext *ctx) -> std::optional<ast::Declaration>;
    [[nodiscard]] auto makeSubprogramDecls(vhdlParser::Subprogram_declarative_partContext *ctx) -> std::vector<ast::Declaration>;
    [[nodiscard]] auto makeSubprogramParam(vhdlParser::Interface_declarationContext *ctx, bool is_last) -> ast::SubprogramParam;
    [[nodiscard]] auto makeSubprogramStatements(vhdlParser::Subprogram_statement_partContext *ctx) -> std::vector<ast::SequentialStatement>;
    [[nodiscard]] auto makeSubtypeDecl(vhdlParser::Subtype_declarationContext *ctx) -> ast::SubtypeDecl;
    [[nodiscard]] auto makeTypeDecl(vhdlParser::Type_declarationContext *ctx) -> ast::TypeDecl;

    // Concurrent statements
    [[nodiscard]] auto makeConcurrentAssign(vhdlParser::Concurrent_signal_assignment_statementContext *ctx) -> ast::ConcurrentAssign;
    [[nodiscard]] auto makeConditionalAssign(vhdlParser::Conditional_signal_assignmentContext *ctx) -> ast::ConcurrentAssign;
    [[nodiscard]] auto makeSelectedAssign(vhdlParser::Selected_signal_assignmentContext *ctx) -> ast::ConcurrentAssign;

    // Sequential statements and control flow
    [[nodiscard]] auto makeAssertStatement(vhdlParser::Assertion_statementContext *ctx) -> ast::AssertStatement;
    [[nodiscard]] auto makeBreakStatement(vhdlParser::Break_statementContext *ctx) -> ast::BreakStatement;
    [[nodiscard]] auto makeCaseStatement(vhdlParser::Case_statementContext *ctx) -> ast::CaseStatement;
    [[nodiscard]] auto makeExitStatement(vhdlParser::Exit_statementContext *ctx) -> ast::ExitStatement;
    [[nodiscard]] auto makeForLoop(vhdlParser::Loop_statementContext *ctx) -> ast::ForLoop;
    [[nodiscard]] auto makeIfStatement(vhdlParser::If_statementContext *ctx) -> ast::IfStatement;
    [[nodiscard]] auto makeNextStatement(vhdlParser::Next_statementContext *ctx) -> ast::NextStatement;
    [[nodiscard]] auto makeProcedureCall(vhdlParser::Procedure_call_statementContext *ctx) -> ast::ProcedureCall;
    [[nodiscard]] auto makeProcess(vhdlParser::Process_statementContext *ctx) -> ast::Process;
    [[nodiscard]] auto makeReportStatement(vhdlParser::Report_statementContext *ctx) -> ast::ReportStatement;
    [[nodiscard]] auto makeReturnStatement(vhdlParser::Return_statementContext *ctx) -> ast::ReturnStatement;
    [[nodiscard]] auto makeSequenceOfStatements(vhdlParser::Sequence_of_statementsContext *ctx) -> std::vector<ast::SequentialStatement>;
    [[nodiscard]] auto makeSequentialAssign(vhdlParser::Signal_assignment_statementContext *ctx) -> ast::SequentialAssign;
    [[nodiscard]] auto makeSequentialStatement(vhdlParser::Sequential_statementContext *ctx) -> ast::SequentialStatement;
    [[nodiscard]] auto makeTarget(vhdlParser::TargetContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeVariableAssign(vhdlParser::Variable_assignment_statementContext *ctx) -> ast::SequentialAssign;
    [[nodiscard]] auto makeWaitStatement(vhdlParser::Wait_statementContext *ctx) -> ast::WaitStatement;
    [[nodiscard]] auto makeWhileLoop(vhdlParser::Loop_statementContext *ctx) -> ast::WhileLoop;
    [[nodiscard]] auto tryMakeExpr(vhdlParser::ExpressionContext *ctx) -> std::optional<ast::Expr>;

    // Expressions
    [[nodiscard]] auto makeAggregate(vhdlParser::AggregateContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeAttributeExpr(ast::Expr base, vhdlParser::Attribute_name_partContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeCallArgument(vhdlParser::Association_elementContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeCallExpr(ast::Expr base, vhdlParser::Function_call_or_indexed_name_partContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeChoice(vhdlParser::ChoiceContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeChoices(vhdlParser::ChoicesContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeConstraint(vhdlParser::ConstraintContext *ctx) -> std::optional<ast::Constraint>;
    [[nodiscard]] auto makeExpr(vhdlParser::ExpressionContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeFactor(vhdlParser::FactorContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeIndexConstraint(vhdlParser::Index_constraintContext *ctx) -> ast::IndexConstraint;
    [[nodiscard]] auto makeName(vhdlParser::NameContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makePrimary(vhdlParser::PrimaryContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeRange(vhdlParser::Explicit_rangeContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeRangeConstraint(vhdlParser::Range_constraintContext *ctx) -> std::optional<ast::RangeConstraint>;
    [[nodiscard]] auto makeRelation(vhdlParser::RelationContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeSelectExpr(ast::Expr base, vhdlParser::Selected_name_partContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeShiftExpr(vhdlParser::Shift_expressionContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeSimpleExpr(vhdlParser::Simple_expressionContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeSliceExpr(ast::Expr base, vhdlParser::Slice_name_partContext *ctx) -> ast::Expr;
    [[nodiscard]] auto makeTerm(vhdlParser::TermContext *ctx) -> ast::Expr;

    // clang-format on

    /// @brief Helper to create and bind an AST node with trivia
    template<typename T, typename Ctx>
    [[nodiscard]]
    auto make(const Ctx *ctx) -> T
    {
        T node{};
        trivia_.bind(node, ctx);
        return node;
    }

    /// @brief Helper to create binary expressions
    template<typename Ctx>
    [[nodiscard]]
    auto makeBinary(const Ctx *ctx, std::string op, ast::Expr left, ast::Expr right) -> ast::Expr
    {
        ast::BinaryExpr bin{};
        trivia_.bind(bin, ctx);
        bin.op = std::move(op);
        bin.left = std::make_unique<ast::Expr>(std::move(left));
        bin.right = std::make_unique<ast::Expr>(std::move(right));
        return bin;
    }

    /// @brief Helper to create unary expressions
    template<typename Ctx>
    [[nodiscard]]
    auto makeUnary(const Ctx *ctx, std::string op, ast::Expr value) -> ast::Expr
    {
        ast::UnaryExpr un{};
        trivia_.bind(un, ctx);
        un.op = std::move(op);
        un.value = std::make_unique<ast::Expr>(std::move(value));
        return un;
    }

    /// @brief Helper to create token expressions
    template<typename Ctx>
    [[nodiscard]]
    auto makeToken(const Ctx *ctx, std::string text) -> ast::Expr
    {
        ast::TokenExpr tok{};
        trivia_.bind(tok, ctx);
        tok.text = std::move(text);
        return tok;
    }
};

} // namespace builder

#endif /* BUILDER_TRANSLATOR_HPP */
