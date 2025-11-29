#include "common/config.hpp"
#include "emit/pretty_printer/doc.hpp"
#include "emit/test_utils.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string>
#include <utility>

using emit::Doc;
using emit::test::defaultConfig;

TEST_CASE("Doc Primitive Creation", "[doc][primitives]")
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

TEST_CASE("Doc Operators and Combinators", "[doc][operators]")
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

TEST_CASE("Doc Layout and Grouping", "[doc][layout]")
{
    SECTION("Basic Grouping behavior")
    {
        // "hello" + line + "world"
        const Doc doc = Doc::group(Doc::text("hello") / Doc::text("world"));

        // Fits on line -> becomes space
        REQUIRE(doc.render(defaultConfig()) == "hello world");
    }

    SECTION("Hardlines inside groups never collapse")
    {
        // "hello" + hardline + "world"
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
            config.line_config.line_length = 5; // "short" is 5, space + "text" exceeds
            REQUIRE(doc.render(config) == "short\ntext");
        }
    }

    SECTION("hardlines(0) as break enforcer")
    {
        // Used to force a group to break without inserting visual whitespace
        const Doc doc = Doc::group(Doc::text("A") / Doc::text("B") + Doc::hardlines(0));
        REQUIRE(doc.render(defaultConfig()) == "A\nB");
    }
}

TEST_CASE("High-Level Layout Patterns", "[doc][patterns]")
{
    SECTION("Bracket Pattern")
    {
        // bracket(left, inner, right) -> (left << inner) / right
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

TEST_CASE("Alignment Logic", "[doc][alignment]")
{
    common::Config config = defaultConfig();
    config.port_map.align_signals = true;

    SECTION("Basic Alignment")
    {
        const Doc doc
          = Doc::align(Doc::alignText("1", 1) / Doc::alignText("12", 1) / Doc::alignText("123", 1));
        REQUIRE(doc.render(config) == "1  \n12 \n123");
    }

    SECTION("Multiple Alignment Columns")
    {
        const Doc row1 = Doc::alignText("col1", 1) & Doc::text(":") & Doc::alignText("val1", 2);
        const Doc row2 = Doc::alignText("c1", 1) & Doc::text(":") & Doc::alignText("v1", 2);

        const Doc doc = Doc::align(row1 / row2);

        constexpr std::string_view EXPECTED = "col1 : val1\n"
                                              "c1   : v1  ";
        REQUIRE(doc.render(config) == EXPECTED);
    }
}

TEST_CASE("Doc Lifecycle and Safety", "[doc][lifecycle]")
{
    SECTION("Copy Semantics")
    {
        const Doc original = Doc::text("A");
        const Doc copy = original; // NOLINT (performance-unnecessary-copy-initialization)
        REQUIRE(original.render(defaultConfig()) == "A");
        REQUIRE(copy.render(defaultConfig()) == "A");
    }

    SECTION("Move Semantics")
    {
        Doc original = Doc::text("A");
        const Doc moved = std::move(original);
        REQUIRE(moved.render(defaultConfig()) == "A");
        // original is now valid but unspecified (standard move rules)
    }

    SECTION("Immutability via Compound Assignment")
    {
        // Doc uses shared_ptr internals, so we must ensure += creates a NEW node
        // and doesn't mutate the structure pointed to by other copies.
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

TEST_CASE("Edge Cases", "[doc][edge_cases]")
{
    SECTION("Empty document interaction")
    {
        // Empty docs should vanish in concatenation
        const Doc doc = Doc::text("A") + Doc::empty() + Doc::text("B");
        REQUIRE(doc.render(defaultConfig()) == "AB");
    }

    SECTION("Empty string text vs Empty doc")
    {
        // text("") is technically a text node with length 0,
        // which renders identical to Empty, but might be distinct in the tree.
        const Doc t = Doc::text("");
        const Doc e = Doc::empty();

        REQUIRE(t.render(defaultConfig()).empty());
        REQUIRE(e.render(defaultConfig()).empty());
    }
}
