#include "ast/nodes/statements.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <utility>

TEST_CASE("Infinite Loop Rendering", "[pretty_printer][statements][loop]")
{
    ast::Loop loop_kind{};

    ast::SequentialStatement body_stmt{};
    body_stmt.kind = ast::NullStatement{};
    loop_kind.body.push_back(std::move(body_stmt));

    SECTION("Simple Loop (Unlabeled)")
    {
        const std::string_view expected = "loop\n  null;\nend loop;";
        REQUIRE(emit::test::render(loop_kind) == expected);
    }

    SECTION("Labeled Loop (Wrapper)")
    {
        ast::SequentialStatement wrapper{};
        wrapper.label = "main_loop";
        wrapper.kind = std::move(loop_kind);

        const std::string_view expected = "main_loop: loop\n  null;\nend loop;";
        REQUIRE(emit::test::render(wrapper) == expected);
    }
}
