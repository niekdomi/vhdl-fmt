#ifndef COMMON_RANGE_HELPERS_HPP
#define COMMON_RANGE_HELPERS_HPP

#include <ranges>

namespace common {

/// @brief Applies a transformation function to each element in the range, providing a boolean flag
/// indicating if the element is the last in the range.
template<typename Range, typename Func>
auto transformWithLast(Range&& range, Func func)
{
    const auto size = std::ranges::size(range);
    return std::forward<Range>(range)
         | std::views::enumerate
         | std::views::transform([=, func_transformed = std::move(func)](auto&& pair) {
               return func_transformed(std::get<1>(pair), std::get<0>(pair) == size - 1);
           });
}

} // namespace common

#endif // COMMON_RANGE_HELPERS_HPP
