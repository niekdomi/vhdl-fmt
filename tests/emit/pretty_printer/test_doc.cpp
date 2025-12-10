#include "common/config.hpp"
#include "emit/pretty_printer/doc.hpp"
#include "emit/pretty_printer/doc_impl.hpp"
#include "emit/test_utils.hpp"

#include <algorithm>
#include <array>
#include <catch2/catch_test_macros.hpp>
#include <string>
#include <utility>
#include <variant>

using emit::Doc;
using emit::test::defaultConfig;

namespace {
// Helper lambda for counting all nodes in a Doc tree (used in Optimization section)
constexpr auto NODE_COUNTER = [](int count, const auto & /*node*/) { return count + 1; };
} // namespace

TEST_CASE("Doc System", "[doc]")
{
    // ==============================================================================
    // 1. Primitive Creation
    // ==============================================================================
    SECTION("Primitives")
    {
        SECTION("Empty document renders empty string")
        {
            const Doc doc = Doc::empty();
            REQUIRE(doc.isEmpty());
            REQUIRE(doc.render(defaultConfig()).empty());
        }

        SECTION("Text document renders string verbatim")
        {
            const Doc doc = Doc::text("hello world");
            REQUIRE_FALSE(doc.isEmpty());
            REQUIRE(doc.render(defaultConfig()) == "hello world");
        }

        SECTION("Hardline renders as newline")
        {
            const Doc doc = Doc::hardline();
            REQUIRE(doc.render(defaultConfig()) == "\n");
        }

        SECTION("Hardlines(n) renders n newlines")
        {
            REQUIRE(Doc::hardlines(1).render(defaultConfig()) == "\n");
            REQUIRE(Doc::hardlines(2).render(defaultConfig()) == "\n\n");
            REQUIRE(Doc::hardlines(3).render(defaultConfig()) == "\n\n\n");
        }
    }

    // ==============================================================================
    // 2. Keyword Logic
    // ==============================================================================
    SECTION("Keywords")
    {
        common::Config config = defaultConfig();

        SECTION("Default rendering (Lower case)")
        {
            config.casing.keywords = common::CaseStyle::LOWER;
            const Doc doc = Doc::keyword("Select");
            REQUIRE(doc.render(config) == "select");
        }

        SECTION("Upper case rendering")
        {
            config.casing.keywords = common::CaseStyle::UPPER;
            const Doc doc = Doc::keyword("select");
            REQUIRE(doc.render(config) == "SELECT");
        }

        SECTION("Keyword concatenation (Preserves identity)")
        {
            // Ensure adjacent keywords don't merge into text and lose their casing property
            config.casing.keywords = common::CaseStyle::UPPER;
            const Doc doc = Doc::keyword("end") & Doc::keyword("process"); // "END PROCESS"

            REQUIRE(doc.render(config) == "END PROCESS");
        }

        SECTION("Mixed Text and Keywords")
        {
            config.casing.keywords = common::CaseStyle::UPPER;
            const Doc doc = Doc::keyword("signal") & Doc::text("my_sig");
            REQUIRE(doc.render(config) == "SIGNAL my_sig");
        }
    }

    // ==============================================================================
    // 3. Operators & Combinators
    // ==============================================================================
    SECTION("Operators")
    {
        const Doc a = Doc::text("a");
        const Doc b = Doc::text("b");

        SECTION("Binary Operators")
        {
            SECTION("Direct concatenation (+)")
            {
                REQUIRE((a + b).render(defaultConfig()) == "ab");
            }
            SECTION("Space concatenation (&)")
            {
                REQUIRE((a & b).render(defaultConfig()) == "a b");
            }
            SECTION("Soft line concatenation (/)")
            {
                REQUIRE((a / b).render(defaultConfig()) == "a\nb");
            }
            SECTION("Hard line concatenation (|)")
            {
                REQUIRE((a | b).render(defaultConfig()) == "a\nb");
            }
            SECTION("Nest operator (<<)")
            {
                const Doc doc = Doc::text("begin") << Doc::text("end");
                REQUIRE(doc.render(defaultConfig()) == "begin\n  end");
            }
        }

        SECTION("Compound Assignment Operators")
        {
            SECTION("Direct Append (+=)")
            {
                Doc doc = a;
                doc += b;
                REQUIRE(doc.render(defaultConfig()) == "ab");
            }
            SECTION("Space Append (&=)")
            {
                Doc doc = a;
                doc &= b;
                REQUIRE(doc.render(defaultConfig()) == "a b");
            }
            SECTION("Softline Append (/=)")
            {
                Doc doc = a;
                doc /= b;
                REQUIRE(doc.render(defaultConfig()) == "a\nb");
            }
            SECTION("Hardline Append (|=)")
            {
                Doc doc = a;
                doc |= b;
                REQUIRE(doc.render(defaultConfig()) == "a\nb");
            }
            SECTION("Nest Append (<<=)")
            {
                Doc doc = Doc::text("root");
                doc <<= Doc::text("child");
                REQUIRE(doc.render(defaultConfig()) == "root\n  child");
            }
        }
    }

    // ==============================================================================
    // 4. Layout & Grouping
    // ==============================================================================
    SECTION("Layout")
    {
        SECTION("Basic Grouping behavior")
        {
            const Doc doc = Doc::group(Doc::text("hello") / Doc::text("world"));
            REQUIRE(doc.render(defaultConfig()) == "hello world");
        }

        SECTION("Hardlines inside groups never collapse")
        {
            const Doc doc = Doc::group(Doc::text("hello") | Doc::text("world"));
            REQUIRE(doc.render(defaultConfig()) == "hello\nworld");
        }

        SECTION("hardIndent always forces break")
        {
            const Doc doc = Doc::group(Doc::text("begin").hardIndent(Doc::text("end")));
            REQUIRE(doc.render(defaultConfig()) == "begin\n  end");
        }

        SECTION("Width sensitivity")
        {
            const Doc doc = Doc::group(Doc::text("short") / Doc::text("text"));

            SECTION("Wide enough")
            {
                auto config = defaultConfig();
                config.line_config.line_length = 80;
                REQUIRE(doc.render(config) == "short text");
            }

            SECTION("Too narrow")
            {
                auto config = defaultConfig();
                config.line_config.line_length = 5;
                REQUIRE(doc.render(config) == "short\ntext");
            }
        }

        SECTION("hardlines(0) as break enforcer")
        {
            const Doc doc = Doc::group(Doc::text("A") / Doc::text("B") + Doc::hardlines(0));
            REQUIRE(doc.render(defaultConfig()) == "A\nB");
        }
    }

    // ==============================================================================
    // 5. High-Level Patterns
    // ==============================================================================
    SECTION("Patterns")
    {
        SECTION("Bracket Pattern")
        {
            const Doc doc = Doc::bracket(Doc::text("begin"), Doc::text("stmt;"), Doc::text("end"));
            REQUIRE(doc.render(defaultConfig()) == "begin\n  stmt;\nend");
        }

        SECTION("Nested Indentation Accumulation")
        {
            const Doc doc = Doc::text("L1") << (Doc::text("L2") << Doc::text("L3"));
            REQUIRE(doc.render(defaultConfig()) == "L1\n  L2\n    L3");
        }

        SECTION("Complex Conditional Structure")
        {
            const Doc header = Doc::text("if") & Doc::text("cond") & Doc::text("then");
            const Doc body = Doc::text("A;") / Doc::text("B;");
            const Doc footer = Doc::text("end if;");

            const Doc doc = (header << body) / footer;
            REQUIRE(doc.render(defaultConfig()) == "if cond then\n  A;\n  B;\nend if;");
        }
    }

    // ==============================================================================
    // 6. Alignment Logic
    // ==============================================================================
    SECTION("Alignment")
    {
        common::Config config = defaultConfig();
        config.port_map.align_signals = true;

        SECTION("Basic Alignment")
        {
            // "1  " (3 chars)
            // "12 " (3 chars)
            // "123" (3 chars)
            const Doc doc
              = Doc::align(Doc::text("1", 1) / Doc::text("12", 1) / Doc::text("123", 1));
            REQUIRE(doc.render(config) == "1  \n12 \n123");
        }

        SECTION("Multiple Alignment Columns")
        {
            const Doc row1 = Doc::text("col1", 1) & Doc::text(":") & Doc::text("val1", 2);
            const Doc row2 = Doc::text("c1", 1) & Doc::text(":") & Doc::text("v1", 2);

            const Doc doc = Doc::align(row1 / row2);

            constexpr std::string_view EXPECTED = "col1 : val1\n"
                                                  "c1   : v1  ";
            REQUIRE(doc.render(config) == EXPECTED);
        }

        SECTION("Keyword Alignment Preservation")
        {
            config.casing.keywords = common::CaseStyle::UPPER;

            // "in" should act as a keyword (UPPER) AND be aligned
            const Doc row1 = Doc::keyword("in", 1);
            const Doc row2 = Doc::keyword("out", 1);

            const Doc doc = Doc::align(row1 / row2);

            // Expected: "IN \nOUT"
            REQUIRE(doc.render(config) == "IN \nOUT");
        }
    }

    // ==============================================================================
    // 7. Smart Constructor Optimizations (White-box Internal Tests)
    // ==============================================================================
    SECTION("Smart Optimizations")
    {
        // Using internal types/functions to verify tree structure
        using emit::DocPtr;
        using emit::makeConcat;
        using emit::makeEmpty;
        using emit::makeHardLine;
        using emit::makeHardLines;
        using emit::makeText;

        SECTION("Rule 1: Identity (Empty Elimination)")
        {
            // Case: a + empty -> a
            const DocPtr res1 = makeConcat(makeText("a"), makeEmpty());
            REQUIRE(emit::foldImpl(res1, 0, NODE_COUNTER) == 1); // 1 Text node

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
            const DocPtr res2 = makeConcat(makeHardLines(1), makeHardLines(0));

            REQUIRE(emit::foldImpl(res2, 0, NODE_COUNTER) == 1);
            REQUIRE(std::holds_alternative<emit::HardLine>(res2->value));
        }

        SECTION("Complex Text Chain Folding")
        {
            constexpr auto PARTS = std::to_array<std::string_view>(
              { "This", " ", "is", " ", "a", " ", "complex", " ", "merge." });

            const DocPtr result
              = std::ranges::fold_left(PARTS, makeEmpty(), [](auto acc, const auto &str) {
                    return makeConcat(std::move(acc), makeText(str));
                });

            // The tree should be fully flattened into one Text node
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

    // ==============================================================================
    // 8. Lifecycle & Safety
    // ==============================================================================
    SECTION("Lifecycle")
    {
        SECTION("Copy Semantics")
        {
            const Doc original = Doc::text("A");
            const Doc copy = original; // NOLINT
            REQUIRE(original.render(defaultConfig()) == "A");
            REQUIRE(copy.render(defaultConfig()) == "A");
        }

        SECTION("Move Semantics")
        {
            Doc original = Doc::text("A");
            const Doc moved = std::move(original);
            REQUIRE(moved.render(defaultConfig()) == "A");
        }

        SECTION("Immutability via Compound Assignment")
        {
            const Doc base = Doc::text("base");
            Doc modified = base;
            modified += Doc::text(" appended");

            REQUIRE(base.render(defaultConfig()) == "base");
            REQUIRE(modified.render(defaultConfig()) == "base appended");
        }

        SECTION("Structural Sharing")
        {
            const Doc shared = Doc::text("shared");
            const Doc d1 = shared + Doc::text("1");
            const Doc d2 = shared + Doc::text("2");

            REQUIRE(d1.render(defaultConfig()) == "shared1");
            REQUIRE(d2.render(defaultConfig()) == "shared2");
        }
    }

    // ==============================================================================
    // 9. Edge Cases
    // ==============================================================================
    SECTION("Edge Cases")
    {
        SECTION("Empty document interaction")
        {
            const Doc doc = Doc::text("A") + Doc::empty() + Doc::text("B");
            REQUIRE(doc.render(defaultConfig()) == "AB");
        }

        SECTION("Empty string text vs Empty doc")
        {
            const Doc t = Doc::text("");
            const Doc e = Doc::empty();
            REQUIRE(t.render(defaultConfig()).empty());
            REQUIRE(e.render(defaultConfig()).empty());
        }
    }
}