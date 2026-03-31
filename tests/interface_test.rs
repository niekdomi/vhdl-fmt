mod common;

use common::assert_format;

fn wrap(decl: &str) -> String {
    format!(
        r#"package p is
{decl}
end p;"#,
        decl = decl
    )
}

//===----------------------------------------------------------------------===//
// Interface lists (port / generic / parameter clauses)
//===----------------------------------------------------------------------===//

#[test]
fn entity_with_ports() {
    assert_format(
        r#"entity e is port(clk : in std_logic; rst : in std_logic); end e;"#,
        r#"entity e is
    port (
        clk : in std_logic;
        rst : in std_logic
    );
end entity e;"#,
    );
}

//===----------------------------------------------------------------------===//
// Individual interface declarations
//===----------------------------------------------------------------------===//

#[test]
fn generic_constant() {
    assert_format(
        r#"entity e is generic(n : integer := 8); end e;"#,
        r#"entity e is
    generic (
        n : integer := 8
    );
end entity e;"#,
    );
}

//===----------------------------------------------------------------------===//
// Mode indications
//===----------------------------------------------------------------------===//

#[test]
fn port_with_modes() {
    assert_format(
        r#"entity e is port(a : in std_logic; b : out std_logic; c : inout std_logic); end e;"#,
        r#"entity e is
    port (
        a : in    std_logic;
        b : out   std_logic;
        c : inout std_logic
    );
end entity e;"#,
    );
}

//===----------------------------------------------------------------------===//
// Map aspects (generic map / port map)
//===----------------------------------------------------------------------===//

#[test]
fn entity_instantiation_with_maps() {
    assert_format(
        r#"architecture a of e is begin u : entity work.sub generic map(n => 4) port map(clk => clk); end a;"#,
        r#"architecture a of e is
begin
    u: entity work.sub
        generic map (n => 4)
        port map (clk => clk);
end architecture a;"#,
    );
}

//===----------------------------------------------------------------------===//
// Subprogram parameters
//===----------------------------------------------------------------------===//

#[test]
fn procedure_with_parameters() {
    assert_format(
        &wrap(r#"procedure proc(signal a : in std_logic; variable b : out integer);"#),
        r#"package p is
    procedure proc (
        signal a   : in  std_logic;
        variable b : out integer
    );
end package p;"#,
    );
}

#[test]
fn procedure_with_parameters_and_comments() {
    assert_format(
        &wrap(
            r#"-- proc leading
procedure proc( -- param start
signal a : in std_logic; -- a comment
variable b : out integer -- b comment
); -- end param"#,
        ),
        r#"package p is
    -- proc leading
    procedure proc (
        signal a   : in  std_logic; -- a comment
        variable b : out integer -- b comment
    ); -- param start -- end param
end package p;"#,
    );
}

#[test]
fn function_with_parameters() {
    assert_format(
        &wrap(r#"function func(a : integer; b : real := 1.0) return boolean;"#),
        r#"package p is
    pure function func (
        constant a : integer;
        constant b : real := 1
    ) return boolean;
end package p;"#,
    );
}

#[test]
fn function_with_parameters_and_comments() {
    assert_format(
        &wrap(
            r#"-- func leading
function func( -- param start
a : integer; -- a comment
b : real := 1.0 -- b comment
) return boolean; -- return comment"#,
        ),
        r#"package p is
    -- func leading
    pure function func (
        constant a : integer; -- a comment
        constant b : real := 1 -- b comment
    ) return boolean; -- param start -- return comment
end package p;"#,
    );
}
