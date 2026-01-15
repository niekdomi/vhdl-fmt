#include "ast/nodes/declarations/interface.hpp"
#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <format>
#include <string_view>
#include <variant>

namespace {

/// @brief Helper to parse a port clause string within an entity.
/// @param port_content The content inside 'port ( ... );'
/// @return Pointer to the parsed Entity node.
[[nodiscard]]
auto parsePorts(std::string_view port_content) -> const ast::Entity*
{
    const auto code = std::format("entity E is port ({}); end E;", port_content);

    static ast::DesignFile design{};
    design = builder::buildFromString(code);

    if (design.units.empty()) {
        return nullptr;
    }

    return std::get_if<ast::Entity>(&design.units.front().unit);
}

} // namespace

TEST_CASE("Declaration: Port", "[builder][decl][interface]")
{
    SECTION("Standard Port")
    {
        const auto* entity = parsePorts("clk : in std_logic");
        REQUIRE(entity != nullptr);

        const auto& ports = entity->port_clause.ports;
        REQUIRE(ports.size() == 1);

        const auto& port = ports.at(0);
        CHECK(port.names.at(0) == "clk");
        CHECK(port.mode == "in");
        CHECK(port.subtype.type_mark == "std_logic");
        CHECK_FALSE(port.default_expr.has_value());
    }

    SECTION("Port with Default Value")
    {
        const auto* entity = parsePorts("bus_sig : inout std_logic := 'Z'");
        REQUIRE(entity != nullptr);

        const auto& port = entity->port_clause.ports.at(0);
        CHECK(port.names.at(0) == "bus_sig");
        CHECK(port.mode == "inout");

        REQUIRE(port.default_expr.has_value());
        const auto* def = std::get_if<ast::TokenExpr>(&port.default_expr.value());
        CHECK(def->text == "'Z'");
    }

    SECTION("Port with multiple names (comma-separated)")
    {
        const auto* entity = parsePorts("a, b : in bit");
        REQUIRE(entity != nullptr);

        const auto& ports = entity->port_clause.ports;
        REQUIRE(ports.size() == 1); // One declaration node

        const auto& port = ports.at(0);
        REQUIRE(port.names.size() == 2);
        CHECK(port.names.at(0) == "a");
        CHECK(port.names.at(1) == "b");
        CHECK(port.mode == "in");
    }

    SECTION("Port with subtype constraint")
    {
        const auto* entity = parsePorts("data : out std_logic_vector(7 downto 0)");
        REQUIRE(entity != nullptr);

        const auto& port = entity->port_clause.ports.at(0);
        CHECK(port.mode == "out");
        CHECK(port.subtype.type_mark == "std_logic_vector");

        // Check constraint inside subtype
        REQUIRE(port.subtype.constraint.has_value());
        const auto* idx = std::get_if<ast::IndexConstraint>(&port.subtype.constraint.value());
        REQUIRE(idx != nullptr);
    }

    SECTION("Multiple port declarations (semicolon-separated)")
    {
        const auto* entity = parsePorts("clk : in bit; rst : in bit");
        REQUIRE(entity != nullptr);

        const auto& ports = entity->port_clause.ports;
        REQUIRE(ports.size() == 2);

        CHECK(ports.at(0).names.at(0) == "clk");
        CHECK(ports.at(1).names.at(0) == "rst");
    }
}
