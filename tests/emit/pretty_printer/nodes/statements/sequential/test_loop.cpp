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
        constexpr std::string_view EXPECTED = "loop\n  null;\nend loop;";
        REQUIRE(emit::test::render(loop_kind) == EXPECTED);
    }

    SECTION("Labeled Loop (Wrapper)")
    {
        ast::SequentialStatement wrapper{};
        wrapper.label = "main_loop";
        wrapper.kind = std::move(loop_kind);

        constexpr std::string_view EXPECTED = "main_loop: loop\n  null;\nend loop;";
        REQUIRE(emit::test::render(wrapper) == EXPECTED);
    }
}