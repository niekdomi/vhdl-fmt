mod common;

use common::assert_format;

//===---------------------------------------------------------------------===//
// Interface lists (port / generic / parameter clauses)
//===---------------------------------------------------------------------===//

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

//===---------------------------------------------------------------------===//
// Individual interface declarations
//===---------------------------------------------------------------------===//

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

//===---------------------------------------------------------------------===//
// Mode indications
//===---------------------------------------------------------------------===//

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

//===---------------------------------------------------------------------===//
// Map aspects (generic map / port map)
//===---------------------------------------------------------------------===//

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
