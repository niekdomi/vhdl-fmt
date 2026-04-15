mod common;

use common::assert_format;

fn wrap(expr: &str) -> String {
    format!(
        "architecture rtl of e is begin process begin v := {expr}; end process; end rtl;",
        expr = expr
    )
}

fn wrap_decl(decl: &str) -> String {
    format!(
        r#"package p is
{decl}
end p;"#,
        decl = decl
    )
}

//===----------------------------------------------------------------------===//
// Expressions
//===----------------------------------------------------------------------===//

#[test]
fn binary_expression() {
    assert_format(
        &wrap("a and b"),
        r#"architecture rtl of e is
begin
    process
    begin
        v := a and b;
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn unary_expression() {
    assert_format(
        &wrap("not a"),
        r#"architecture rtl of e is
begin
    process
    begin
        v := not a;
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn function_call_expression() {
    assert_format(
        &wrap("to_integer(unsigned(a))"),
        r#"architecture rtl of e is
begin
    process
    begin
        v := to_integer(unsigned(a));
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn aggregate_expression() {
    assert_format(
        &wrap("(a => '1', b => '0')"),
        r#"architecture rtl of e is
begin
    process
    begin
        v := (a => '1', b => '0');
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Subtype indication and constraints
//===----------------------------------------------------------------------===//

#[test]
fn subtype_with_range_constraint() {
    assert_format(
        &wrap_decl("subtype byte is integer range 0 to 255;"),
        r#"package p is
    subtype byte is integer range 0 to 255;
end package p;"#,
    );
}

#[test]
fn subtype_with_comments() {
    assert_format(
        &wrap_decl("-- subtype leading\nsubtype byte is integer range 0 to 255; -- trailing"),
        r#"package p is
    -- subtype leading
    subtype byte is integer range 0 to 255; -- trailing
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Ranges and discrete ranges
//===----------------------------------------------------------------------===//

#[test]
fn signal_with_range() {
    assert_format(
        &wrap_decl("signal s : std_logic_vector(7 downto 0);"),
        r#"package p is
    signal s : std_logic_vector(7 downto 0);
end package p;"#,
    );
}

#[test]
fn signal_with_range_and_comments() {
    assert_format(
        &wrap_decl("-- signal leading\nsignal s : std_logic_vector(7 downto 0); -- trailing"),
        r#"package p is
    -- signal leading
    signal s : std_logic_vector(7 downto 0); -- trailing
end package p;"#,
    );
}
