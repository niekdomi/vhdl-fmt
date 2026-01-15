#include "ast/nodes/statements/sequential.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Null Statement", "[pretty_printer][control_flow][sequential]")
{
    const ast::NullStatement stmt;
    const std::string_view expected = "null;";
    REQUIRE(emit::test::render(stmt) == expected);
}
