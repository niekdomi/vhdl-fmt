#ifndef AST_VISITOR_HPP
#define AST_VISITOR_HPP

#include "node.hpp"

#include <type_traits>
#include <variant>

namespace ast {

/// @brief Base class for stateful visitors using C++23 Deducing This.
/// @tparam ReturnType The return type of the visit operation.
template<typename ReturnType = void>
class VisitorBase
{
  public:
    /// @brief Visit a concrete node.
    template<typename Self, typename T>
        requires std::is_base_of_v<NodeBase, T>
    auto visit(this const Self &self, const T &node) -> ReturnType
    {
        if constexpr (std::is_void_v<ReturnType>) {
            self(node);
        } else {
            return self.wrapResult(node, self(node));
        }
    }

    /// @brief Visit a variant node.
    template<typename Self, typename... Ts>
    auto visit(this const Self &self, const std::variant<Ts...> &node) -> ReturnType
    {
        return std::visit([&self](const auto &n) -> ReturnType { return self.visit(n); }, node);
    }
};

} // namespace ast

#endif /* AST_VISITOR_HPP */
