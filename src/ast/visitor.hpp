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
    /// @brief Visit a concrete node with optional additional arguments.
    template<typename Self, typename T, typename... Args>
        requires std::is_base_of_v<NodeBase, T>
    auto visit(this const Self& self, const T& node, Args&&... args) -> ReturnType
    {
        if constexpr (std::is_void_v<ReturnType>) {
            self(node, std::forward<Args>(args)...);
        } else {
            return self.wrapResult(node, self(node, std::forward<Args>(args)...));
        }
    }

    /// @brief Visit a variant node with optional additional arguments.
    template<typename Self, typename... Ts, typename... Args>
    auto visit(this const Self& self, const std::variant<Ts...>& node, Args&&... args) -> ReturnType
    {
        return std::visit(
          [&](const auto& n) -> ReturnType { return self.visit(n, std::forward<Args>(args)...); },
          node);
    }
};

} // namespace ast

#endif /* AST_VISITOR_HPP */
