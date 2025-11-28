#include "ast/nodes/design_file.hpp"
#include "ast/nodes/design_units.hpp"
#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/ast_builder.hpp"

#include <catch2/catch_test_macros.hpp>
#include <string_view>

TEST_CASE("Name: Simple identifier name", "[expressions][name]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (a : in std_logic; b : out std_logic);
        end E;
        architecture A of E is
        begin
            b <= a;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    // Names are represented as TokenExpr in the generic AST
    const auto &name = std::get<ast::TokenExpr>(assign.value);
    REQUIRE(name.text == "a");
}

TEST_CASE("Name: Selected name (qualified)", "[expressions][name]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (sig : in std_logic);
        end E;
        architecture A of E is
            signal vec : std_logic_vector(7 downto 0);
        begin
            vec(0) <= sig;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    // Indexed/selected names are represented as CallExpr
    const auto &indexed = std::get<ast::CallExpr>(assign.target);
    REQUIRE(indexed.callee != nullptr);
    const auto &callee_token = std::get<ast::TokenExpr>(*indexed.callee);
    REQUIRE(callee_token.text == "vec");
    REQUIRE(indexed.args != nullptr);
    const auto &arg_token = std::get<ast::TokenExpr>(*indexed.args);
    REQUIRE(arg_token.text == "0");
}

TEST_CASE("Name: Aggregate in assignment", "[expressions][name]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            signal vec : std_logic_vector(1 downto 0);
        begin
            vec <= (others => '0');
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    // Aggregates are represented as GroupExpr
    const auto &agg = std::get<ast::GroupExpr>(assign.value);
    REQUIRE(agg.children.size() == 1);
    const auto &assoc = std::get<ast::BinaryExpr>(agg.children[0]);
    REQUIRE(assoc.op == "=>");
    REQUIRE(std::get<ast::TokenExpr>(*assoc.left).text == "others");
    REQUIRE(std::get<ast::TokenExpr>(*assoc.right).text == "'0'");
}

TEST_CASE("Name: Function call expression", "[expressions][name]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
            port (clk : in std_logic; result : out std_logic);
        end E;
        architecture A of E is
        begin
            process(clk)
            begin
                if rising_edge(clk) then
                    result <= '1';
                end if;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 1);

    const auto &if_stmt = std::get<ast::IfStatement>(proc.body[0]);

    // Function calls are represented as CallExpr
    const auto &call = std::get<ast::CallExpr>(if_stmt.if_branch.condition);
    REQUIRE(call.callee != nullptr);
    const auto &callee_token = std::get<ast::TokenExpr>(*call.callee);
    REQUIRE(callee_token.text == "rising_edge");
    REQUIRE(call.args != nullptr);
    const auto &arg_token = std::get<ast::TokenExpr>(*call.args);
    REQUIRE(arg_token.text == "clk");
}

TEST_CASE("Name: Slice expression", "[expressions][name]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            signal vec : std_logic_vector(7 downto 0);
            signal slice : std_logic_vector(3 downto 0);
        begin
            slice <= vec(5 downto 2);
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &assign = std::get<ast::ConcurrentAssign>(arch.stmts[0]);

    // Slice expressions are represented as CallExpr with range argument
    const auto &slice = std::get<ast::CallExpr>(assign.value);
    REQUIRE(slice.callee != nullptr);
    const auto &callee_token = std::get<ast::TokenExpr>(*slice.callee);
    REQUIRE(callee_token.text == "vec");
    REQUIRE(slice.args != nullptr);
    const auto &range_expr = std::get<ast::BinaryExpr>(*slice.args);
    REQUIRE(range_expr.op == "downto");
    REQUIRE(std::get<ast::TokenExpr>(*range_expr.left).text == "5");
    REQUIRE(std::get<ast::TokenExpr>(*range_expr.right).text == "2");
}

TEST_CASE("Name: Attribute name", "[expressions][name]")
{
    constexpr std::string_view VHDL_FILE = R"(
        entity E is
        end E;
        architecture A of E is
            signal vec : std_logic_vector(7 downto 0);
            signal len : integer;
        begin
            process
            begin
                len <= vec'length;
                wait;
            end process;
        end A;
    )";

    const auto design = builder::buildFromString(VHDL_FILE);
    REQUIRE(design.units.size() == 2);

    const auto &arch = std::get<ast::Architecture>(design.units[1]);
    REQUIRE(arch.stmts.size() == 1);

    const auto &proc = std::get<ast::Process>(arch.stmts[0]);
    REQUIRE(proc.body.size() == 2); // assignment + wait

    const auto &assign = std::get<ast::SequentialAssign>(proc.body[0]);
    const auto &attribute = std::get<ast::BinaryExpr>(assign.value);
    REQUIRE(attribute.op == "'");
    REQUIRE(attribute.left != nullptr);
    REQUIRE(attribute.right != nullptr);
    REQUIRE(std::get<ast::TokenExpr>(*attribute.left).text == "vec");
    REQUIRE(std::get<ast::TokenExpr>(*attribute.right).text == "length");
}
