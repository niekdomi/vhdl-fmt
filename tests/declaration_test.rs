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

//===---------------------------------------------------------------------===//
// Object declarations (signal, variable, constant, shared variable)
//===---------------------------------------------------------------------===//

#[test]
fn signal_declaration() {
    assert_format(
        &wrap("signal clk : std_logic;"),
        r#"package p is
    signal clk : std_logic;
end package p;"#,
    );
}

//===---------------------------------------------------------------------===//
// File declarations
//===---------------------------------------------------------------------===//

#[test]
fn file_declaration() {
    assert_format(
        &wrap("file f : text open read_mode is \"data.txt\";"),
        r#"package p is
    file f: text open read_mode is "data.txt";
end package p;"#,
    );
}

//===---------------------------------------------------------------------===//
// Type declarations
//===---------------------------------------------------------------------===//

#[test]
fn enumeration_type() {
    assert_format(
        &wrap("type state is (idle, running, done);"),
        r#"package p is
    type state is (idle, running, done);
end package p;"#,
    );
}

//===---------------------------------------------------------------------===//
// Component declarations
//===---------------------------------------------------------------------===//

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

//===---------------------------------------------------------------------===//
// Attribute declarations and specifications
//===---------------------------------------------------------------------===//

#[test]
fn attribute_declaration() {
    assert_format(
        &wrap("attribute syn_encoding : string;"),
        r#"package p is
    attribute syn_encoding: string;
end package p;"#,
    );
}

//===---------------------------------------------------------------------===//
// Alias declarations
//===---------------------------------------------------------------------===//

#[test]
fn alias_simple() {
    assert_format(
        &wrap("alias addr is bus_addr;"),
        r#"package p is
    alias addr is bus_addr;
end package p;"#,
    );
}

//===---------------------------------------------------------------------===//
// Use / library / context-reference clauses
//===---------------------------------------------------------------------===//

#[test]
fn use_clause() {
    assert_format(
        &wrap("use work.pkg.all;"),
        r#"package p is
    use work.pkg.all;
end package p;"#,
    );
}

//===---------------------------------------------------------------------===//
// Package instantiation (as a declaration)
//===---------------------------------------------------------------------===//

#[test]
fn package_instantiation() {
    assert_format(
        &wrap("package inst is new work.generic_pkg;"),
        r#"package p is
    package inst is new work.generic_pkg;
end package p;"#,
    );
}

//===---------------------------------------------------------------------===//
// Configuration specification
//===---------------------------------------------------------------------===//

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

//===---------------------------------------------------------------------===//
// View (mode view) declarations
//===---------------------------------------------------------------------===//

#[test]
fn view_declaration() {
    assert_format(
        &wrap("type simple_t is (a, b, c);"),
        r#"package p is
    type simple_t is (a, b, c);
end package p;"#,
    );
}
