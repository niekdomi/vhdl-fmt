mod common;

use common::assert_format;

// All declarations need a wrapping design unit to parse.
fn wrap(decl: &str) -> String {
    format!(
        r#"package p is
{decl}
end package p;"#,
        decl = decl
    )
}

//===----------------------------------------------------------------------===//
// Object declarations (signal, variable, constant, shared variable)
//===----------------------------------------------------------------------===//

#[test]
fn signal_declaration() {
    assert_format(
        &wrap("signal clk : std_logic;"),
        r#"package p is
    signal clk : std_logic;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// File declarations
//===----------------------------------------------------------------------===//

#[test]
fn file_declaration() {
    assert_format(
        &wrap("file f : text open read_mode is \"data.txt\";"),
        r#"package p is
    file f: text open read_mode is "data.txt";
end package p;"#,
    );
}

#[test]
fn signal_declaration_with_comments() {
    assert_format(
        &wrap("-- leading comment\nsignal clk : std_logic; -- trailing comment"),
        r#"package p is
    -- leading comment
    signal clk : std_logic; -- trailing comment
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Type declarations
//===----------------------------------------------------------------------===//

#[test]
fn enumeration_type() {
    assert_format(
        &wrap("type state is (idle, running, done);"),
        r#"package p is
    type state is (idle, running, done);
end package p;"#,
    );
}

#[test]
fn record_type() {
    assert_format(
        &wrap("type rec is record a : integer; b : bit; end record;"),
        r#"package p is
    type rec is record
        a : integer;
        b : bit;
    end record rec;
end package p;"#,
    );
}

#[test]
fn array_type() {
    assert_format(
        &wrap("type arr is array (0 to 7) of bit;"),
        r#"package p is
    type arr is array (0 to 7) of bit;
end package p;"#,
    );
}

#[test]
fn subtype_declaration() {
    assert_format(
        &wrap("subtype small_int is integer range 0 to 255;"),
        r#"package p is
    subtype small_int is integer range 0 to 255;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Component declarations
//===----------------------------------------------------------------------===//

#[test]
fn component_declaration_empty() {
    assert_format(
        &wrap("component comp is end component comp;"),
        r#"package p is
    component comp is
    end component comp;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Attribute declarations and specifications
//===----------------------------------------------------------------------===//

#[test]
fn attribute_declaration() {
    assert_format(
        &wrap("attribute syn_encoding : string;"),
        r#"package p is
    attribute syn_encoding: string;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Alias declarations
//===----------------------------------------------------------------------===//

#[test]
fn alias_simple() {
    assert_format(
        &wrap("alias addr is bus_addr;"),
        r#"package p is
    alias addr is bus_addr;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Use / library / context-reference clauses
//===----------------------------------------------------------------------===//

#[test]
fn use_clause() {
    assert_format(
        &wrap("use work.pkg.all;"),
        r#"package p is
    use work.pkg.all;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Package instantiation (as a declaration)
//===----------------------------------------------------------------------===//

#[test]
fn package_instantiation() {
    assert_format(
        &wrap("package inst is new work.generic_pkg;"),
        r#"package p is
    package inst is new work.generic_pkg;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Configuration specification
//===----------------------------------------------------------------------===//

#[test]
fn configuration_specification() {
    assert_format(
        r#"architecture a of e is for all : comp use entity work.comp; end for; begin end a;"#,
        r#"architecture a of e is
    for all: comp
    use entity work.comp;
    end for;
begin

end architecture a;"#,
    );
}

//===----------------------------------------------------------------------===//
// View (mode view) declarations
//===----------------------------------------------------------------------===//

#[test]
fn view_declaration() {
    assert_format(
        &wrap("type simple_t is (a, b, c);"),
        r#"package p is
    type simple_t is (a, b, c);
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Multiple identifiers in one declaration
//===----------------------------------------------------------------------===//

#[test]
fn multiple_signal_identifiers() {
    assert_format(
        &wrap("signal a, b, c : std_logic;"),
        r#"package p is
    signal a, b, c : std_logic;
end package p;"#,
    );
}

#[test]
fn multiple_constant_identifiers() {
    assert_format(
        &wrap("constant W, H : integer := 8;"),
        r#"package p is
    constant W, H : integer := 8;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Aligned object declaration groups
//===----------------------------------------------------------------------===//

#[test]
fn aligned_signal_group() {
    assert_format(
        &wrap(
            "signal clk : std_logic;\nsignal data : std_logic_vector(7 downto 0);\nsignal valid : std_logic;",
        ),
        r#"package p is
    signal clk   : std_logic;
    signal data  : std_logic_vector(7 downto 0);
    signal valid : std_logic;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Incomplete type declarations
//===----------------------------------------------------------------------===//

#[test]
fn incomplete_type_declaration() {
    assert_format(
        &wrap("type t;"),
        r#"package p is
    type t;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Access type declarations
//===----------------------------------------------------------------------===//

#[test]
fn access_type() {
    assert_format(
        &wrap("type ptr is access integer;"),
        r#"package p is
    type ptr is access integer;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// File type definitions
//===----------------------------------------------------------------------===//

#[test]
fn file_type_definition() {
    assert_format(
        &wrap("type text_file is file of character;"),
        r#"package p is
    type text_file is file of character;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Physical type declarations
//===----------------------------------------------------------------------===//

#[test]
fn physical_type() {
    assert_format(
        &wrap("type time_t is range 0 to integer'high units fs; ps = 1000 fs; end units;"),
        r#"package p is
    type time_t is range 0 to integer'high
    units
            fs;
            ps = 1000 fs;
    end units;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Protected type declarations and bodies
//===----------------------------------------------------------------------===//

#[test]
fn protected_type_declaration() {
    assert_format(
        &wrap(
            "type counter is protected procedure increment; function get return integer; end protected counter;",
        ),
        r#"package p is
    type counter is protected
        procedure increment;
        pure function get return integer;
    end protected counter;
end package p;"#,
    );
}

#[test]
fn protected_type_body() {
    assert_format(
        r#"package body p is type counter is protected body variable v : integer := 0; procedure increment is begin v := v + 1; end increment; end protected body counter; end p;"#,
        r#"package body p is
    type counter is protected body
        variable v : integer := 0;
        procedure increment is
        begin
            v := v + 1;
        end procedure increment;
    end protected body counter;
end package body p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Attribute specifications
//===----------------------------------------------------------------------===//

#[test]
fn attribute_specification_all() {
    assert_format(
        r#"architecture a of e is attribute keep : boolean; attribute keep of all : signal is true; begin end a;"#,
        r#"architecture a of e is
    attribute keep: boolean;
    attribute keep of all: signal is true;
begin

end architecture a;"#,
    );
}

#[test]
fn attribute_specification_others() {
    assert_format(
        r#"architecture a of e is attribute keep : boolean; attribute keep of others : signal is false; begin end a;"#,
        r#"architecture a of e is
    attribute keep: boolean;
    attribute keep of others: signal is false;
begin

end architecture a;"#,
    );
}

//===----------------------------------------------------------------------===//
// Comment handling in declarations
//===----------------------------------------------------------------------===//

#[test]
fn record_type_with_comments() {
    assert_format(
        &wrap(
            "-- rec leading\ntype rec is record -- rec comment\na : integer; -- a comment\nb : bit; -- b comment\nend record; -- end comment",
        ),
        r#"package p is
    -- rec leading
    type rec is record
        a : integer;
        b : bit;
    end record rec; -- rec comment -- a comment -- b comment -- end comment
end package p;"#,
    );
}

#[test]
fn multiple_declarations_with_blank_line() {
    assert_format(
        &wrap("signal a : std_logic;\n\nsignal b : std_logic;"),
        r#"package p is
    signal a : std_logic;

    signal b : std_logic;
end package p;"#,
    );
}

#[test]
fn declarations_with_leading_comments() {
    assert_format(
        &wrap("-- first group\nsignal clk : std_logic;\n-- second group\nsignal data : integer;"),
        r#"package p is
    -- first group
    signal clk : std_logic;
    -- second group
    signal data : integer;
end package p;"#,
    );
}
