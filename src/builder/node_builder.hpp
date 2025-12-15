#ifndef BUILDER_NODE_BUILDER_HPP
#define BUILDER_NODE_BUILDER_HPP

#include "builder/trivia/trivia_binder.hpp"

#include <memory>
#include <ranges>
#include <utility>
#include <vector>

namespace builder {

/// @brief Fluent builder for constructing AST nodes with trivia binding.
/// @tparam T The AST node type to build.
///
/// Uses C++23 deducing this for perfect forwarding through the chain,
/// enabling move semantics on the final build() when used as a temporary.
///
/// Example usage (via Translator::build<T>):
/// @code
/// return build<ast::Entity>(ctx)
///     .set(&ast::Entity::name, ctx.identifier(0)->getText())
///     .maybe(&ast::Entity::generic_clause, ctx.entity_header()->generic_clause(),
///            [&](auto& gc) { return makeGenericClause(gc); })
///     .collect(&ast::Entity::ports, ctx.port_list(),
///              [&](auto* p) { return makePort(*p); })
///     .build();
/// @endcode
template<typename T>
class NodeBuilder
{
    T node_{};

  public:
    /// @brief Constructs a builder, without binding trivia.
    explicit NodeBuilder() = default;

    /// @brief Constructs a builder, binding trivia from the parse context.
    template<typename Ctx>
    explicit NodeBuilder(Ctx &ctx, TriviaBinder &trivia)
    {
        trivia.bind(node_, ctx);
    }

    ~NodeBuilder() = default;
    NodeBuilder(const NodeBuilder &) = delete;
    auto operator=(const NodeBuilder &) -> NodeBuilder & = delete;
    NodeBuilder(NodeBuilder &&) = delete;
    auto operator=(NodeBuilder &&) -> NodeBuilder & = delete;

    /// @brief Sets a field to a value unconditionally.
    /// @param self Deduced self reference (lvalue or rvalue).
    /// @param field Pointer-to-member for the target field.
    /// @param value The value to assign.
    template<typename Self, typename Field, typename Value>
    auto set(this Self &&self, Field T::*field, Value &&value) -> Self &&
    {
        self.node_.*field = std::forward<Value>(value);
        return std::forward<Self>(self);
    }

    /// @brief Sets a unique_ptr field by wrapping the value automatically (boxing).
    /// @param self Deduced self reference (lvalue or rvalue).
    /// @param field Pointer-to-member for the target unique_ptr field.
    /// @param value The value to wrap in std::make_unique.
    template<typename Self, typename Inner, typename Value>
    auto setBox(this Self &&self, std::unique_ptr<Inner> T::*field, Value &&value) -> Self &&
    {
        self.node_.*field = std::make_unique<Inner>(std::forward<Value>(value));
        return std::forward<Self>(self);
    }

    /// @brief Sets a field only if the context pointer is non-null.
    /// @param self Deduced self reference.
    /// @param field Pointer-to-member for the target field.
    /// @param ctx Nullable pointer to parse context.
    /// @param fn Transformation function to apply if ctx is non-null.
    template<typename Self, typename Field, typename Ctx, typename Fn>
    auto maybe(this Self &&self, Field T::*field, Ctx *ctx, Fn &&fn) -> Self &&
    {
        if (ctx != nullptr) {
            self.node_.*field = std::forward<Fn>(fn)(*ctx);
        }

        return std::forward<Self>(self);
    }

    /// @brief Sets a unique_ptr field by wrapping result if context is non-null (boxing).
    /// @param self Deduced self reference.
    /// @param field Pointer-to-member for the target unique_ptr field.
    /// @param ctx Nullable pointer to parse context.
    /// @param fn Transformation function to apply if ctx is non-null.
    template<typename Self, typename Inner, typename Ctx, typename Fn>
    auto maybeBox(this Self &&self, std::unique_ptr<Inner> T::*field, Ctx *ctx, Fn &&fn) -> Self &&
    {
        if (ctx != nullptr) {
            self.node_.*field = std::make_unique<Inner>(std::forward<Fn>(fn)(*ctx));
        }

        return std::forward<Self>(self);
    }

    /// @brief Applies a function if context is non-null (for side effects or complex logic).
    /// @param self Deduced self reference.
    /// @param ctx Nullable pointer to parse context.
    /// @param fn Function to apply, receives a reference to the node and the context.
    template<typename Self, typename Ctx, typename Fn>
    auto with(this Self &&self, Ctx *ctx, Fn &&fn) -> Self &&
    {
        if (ctx != nullptr) {
            std::forward<Fn>(fn)(self.node_, *ctx);
        }

        return std::forward<Self>(self);
    }

    /// @brief Applies a function unconditionally to the node being built.
    /// @param self Deduced self reference.
    /// @param fn Function to apply, receives a reference to the node.
    template<typename Self, typename Fn>
    auto apply(this Self &&self, Fn &&fn) -> Self &&
    {
        std::forward<Fn>(fn)(self.node_);
        return std::forward<Self>(self);
    }

    /// @brief Collects a range into a vector field using a transformation.
    /// @param self Deduced self reference.
    /// @param field Pointer-to-member for the target vector field.
    /// @param range The source range to transform.
    /// @param fn Transformation function for each element.
    template<typename Self, typename Field, typename Range, typename Fn>
    auto collect(this Self &&self, Field T::*field, Range &&range, Fn &&fn) -> Self &&
    {
        self.node_.*field = std::forward<Range>(range)
                          | std::views::transform(std::forward<Fn>(fn))
                          | std::ranges::to<std::vector>();

        return std::forward<Self>(self);
    }

    /// @brief Collects from a nullable context's range into a vector field.
    /// @param self Deduced self reference.
    /// @param field Pointer-to-member for the target vector field.
    /// @param ctx Nullable pointer that provides the range.
    /// @param rangeAccessor Function to get the range from the context.
    /// @param fn Transformation function for each element.
    template<typename Self, typename Field, typename Ctx, typename RangeAccessor, typename Fn>
    auto collectFrom(this Self &&self,
                     Field T::*field,
                     Ctx *ctx,
                     RangeAccessor &&range_accessor,
                     Fn &&fn) -> Self &&
    {
        if (ctx != nullptr) {
            self.node_.*field = std::forward<RangeAccessor>(range_accessor)(*ctx)
                              | std::views::transform(std::forward<Fn>(fn))
                              | std::ranges::to<std::vector>();
        }

        return std::forward<Self>(self);
    }

    /// @brief Finalizes and returns the constructed node.
    [[nodiscard]]
    auto build() && -> T
    {
        return std::move(node_);
    }
};

} // namespace builder

#endif /* BUILDER_NODE_BUILDER_HPP */
