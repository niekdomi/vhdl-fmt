#include "emit/pretty_printer/doc_impl.hpp"

#include <algorithm>
#include <array>
#include <catch2/catch_test_macros.hpp>
#include <string_view>
#include <utility>
#include <variant>

using emit::DocPtr;
using emit::makeConcat;
using emit::makeEmpty;
using emit::makeHardLine;
using emit::makeHardLines;
using emit::makeText;

namespace {
// Helper lambda for counting all nodes in a Doc tree
constexpr auto NODE_COUNTER = [](int count, const auto & /*node*/) { return count + 1; };
} // namespace

TEST_CASE("Smart Constructor Optimization", "[pretty_printer][smart_ctor]")
{
    SECTION("Rule 1: Identity (Empty Elimination)")
    {
        // Case: a + empty -> a
        const DocPtr res1 = makeConcat(makeText("a"), makeEmpty());

        // Verification: Should be 1 node (Text), not 2 (Concat(Text, Empty))
        REQUIRE(emit::foldImpl(res1, 0, NODE_COUNTER) == 1);

        const auto *text1 = std::get_if<emit::Text>(&res1->value);
        REQUIRE(text1 != nullptr);
        REQUIRE(text1->content == "a");

        // Case: empty + a -> a
        const DocPtr res2 = makeConcat(makeEmpty(), makeText("a"));
        REQUIRE(emit::foldImpl(res2, 0, NODE_COUNTER) == 1);

        // Case: empty + empty -> empty
        const DocPtr res3 = makeConcat(makeEmpty(), makeEmpty());
        REQUIRE(std::holds_alternative<emit::Empty>(res3->value));
    }

    SECTION("Rule 2: Text Merging")
    {
        // makeConcat("a", "b") -> Text("ab")
        const DocPtr res = makeConcat(makeText("a"), makeText("b"));

        REQUIRE(emit::foldImpl(res, 0, NODE_COUNTER) == 1);

        const auto *text = std::get_if<emit::Text>(&res->value);
        REQUIRE(text != nullptr);
        REQUIRE(text->content == "ab");
    }

    SECTION("Rule 3: HardLine Merging")
    {
        // (HardLines(2) + HardLine) + HardLines(3) -> HardLines(6)
        const DocPtr res1
          = makeConcat(makeConcat(makeHardLines(2), makeHardLine()), makeHardLines(3));

        REQUIRE(emit::foldImpl(res1, 0, NODE_COUNTER) == 1);

        const auto *lines1 = std::get_if<emit::HardLines>(&res1->value);
        REQUIRE(lines1 != nullptr);
        REQUIRE(lines1->count == 6);

        // HardLines(1) + HardLines(0) -> HardLine(1)
        // Note: HardLines(0) is a break enforcer, HardLines(1) is a newline.
        // Merging them technically results in 1 newline.
        const DocPtr res2 = makeConcat(makeHardLines(1), makeHardLines(0));

        // Should decay to canonical HardLine
        REQUIRE(emit::foldImpl(res2, 0, NODE_COUNTER) == 1);
        REQUIRE(std::holds_alternative<emit::HardLine>(res2->value));
    }

    SECTION("Complex Text Chain Folding")
    {
        // Simulate building a long string from many small parts
        constexpr auto PARTS = std::to_array<std::string_view>(
          { "This", " ", "is", " ", "a", " ", "complex", " ", "merge." });

        const DocPtr result
          = std::ranges::fold_left(PARTS, makeEmpty(), [](auto acc, const auto &str) {
                return makeConcat(std::move(acc), makeText(str));
            });

        // Verification: The tree should be fully flattened into one Text node
        REQUIRE(emit::foldImpl(result, 0, NODE_COUNTER) == 1);

        const auto *text = std::get_if<emit::Text>(&result->value);
        REQUIRE(text != nullptr);
        REQUIRE(text->content == "This is a complex merge.");
    }

    SECTION("Interleaved Optimization")
    {
        // ("A" + (Empty + "B")) + ("C" + Empty) -> "ABC"

        const DocPtr lhs = makeConcat(makeText("A"), makeConcat(makeEmpty(), makeText("B")));
        const DocPtr rhs = makeConcat(makeText("C"), makeEmpty());
        const DocPtr final_doc = makeConcat(lhs, rhs);

        REQUIRE(emit::foldImpl(final_doc, 0, NODE_COUNTER) == 1);

        const auto *text = std::get_if<emit::Text>(&final_doc->value);
        REQUIRE(text != nullptr);
        REQUIRE(text->content == "ABC");
    }
}
