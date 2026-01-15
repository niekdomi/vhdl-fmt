#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <string_view>
#include <utility>

TEST_CASE("For Loop Rendering", "[pretty_printer][statements][loop]")
{
    ast::ForLoop loop;
    loop.iterator = "i";

    // Setup Range: 0 to 7
    auto range = std::make_unique<ast::BinaryExpr>();
    range->left = std::make_unique<ast::Expr>(ast::TokenExpr{.text = "0"});
    range->op = "to";
    range->right = std::make_unique<ast::Expr>(ast::TokenExpr{.text = "7"});
    loop.range = std::move(*range);

    // Setup Body: Null Statement
    ast::SequentialStatement body_stmt;
    body_stmt.kind = ast::NullStatement{};
    loop.body.push_back(std::move(body_stmt));

    SECTION("Basic For Loop")
    {
        const std::string_view expected = "for i in 0 to 7 loop\n  null;\nend loop;";
        REQUIRE(emit::test::render(loop) == expected);
    }
}
