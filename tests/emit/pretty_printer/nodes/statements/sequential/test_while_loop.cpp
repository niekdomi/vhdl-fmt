#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <utility>

TEST_CASE("While Loop Rendering", "[pretty_printer][statements][loop]")
{
    ast::WhileLoop loop{.condition{ast::TokenExpr{.text = "enabled"}}};

    ast::SequentialStatement body_stmt{.kind = ast::NullStatement{}};
    loop.body.push_back(std::move(body_stmt));

    SECTION("Basic While Loop")
    {
        const std::string_view expected = "while enabled loop\n  null;\nend loop;";
        REQUIRE(emit::test::render(loop) == expected);
    }
}
