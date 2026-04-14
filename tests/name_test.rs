mod common;

use common::assert_format;

// TODO: Is this even the desired behavior?
fn wrap(expr: &str) -> String {
    format!(
        "architecture rtl of e is begin process begin v := {expr}; end process; end rtl;",
        expr = expr
    )
}

//===----------------------------------------------------------------------===//
// Names (designator, selected, slice, call/indexed)
//===----------------------------------------------------------------------===//

#[test]
fn selected_name() {
    assert_format(
        &wrap("pkg.item"),
        r#"architecture rtl of e is
begin
    process
    begin
        v := pkg.item;
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Association lists (port map / generic map / call arguments)
//===----------------------------------------------------------------------===//

#[test]
fn function_call_with_args() {
    assert_format(
        &wrap("to_integer(unsigned(data))"),
        r#"architecture rtl of e is
begin
    process
    begin
        v := to_integer(unsigned(data));
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Indexed names
//===----------------------------------------------------------------------===//

#[test]
fn indexed_name() {
    assert_format(
        &wrap("arr(5)"),
        r#"architecture rtl of e is
begin
    process
    begin
        v := arr(5);
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Sliced names
//===----------------------------------------------------------------------===//

#[test]
fn sliced_name() {
    assert_format(
        &wrap("vec(7 downto 0)"),
        r#"architecture rtl of e is
begin
    process
    begin
        v := vec(7 downto 0);
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Selected-all names
//===----------------------------------------------------------------------===//

#[test]
fn selected_all_name() {
    assert_format(
        "package p is use work.pkg.all; end p;",
        r#"package p is
    use work.pkg.all;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Attribute names
//===----------------------------------------------------------------------===//

#[test]
fn attribute_event() {
    assert_format(
        &wrap("clk'event"),
        r#"architecture rtl of e is
begin
    process
    begin
        v := clk'event;
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn attribute_length() {
    assert_format(
        &wrap("arr'length"),
        r#"architecture rtl of e is
begin
    process
    begin
        v := arr'length;
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn attribute_range() {
    assert_format(
        "package p is subtype r is integer range arr'range; end p;",
        r#"package p is
    subtype r is integer range arr'range;
end package p;"#,
    );
}

#[test]
fn attribute_with_expression() {
    assert_format(
        &wrap("arr'left(1)"),
        r#"architecture rtl of e is
begin
    process
    begin
        v := arr'left(1);
    end process;
end architecture rtl;"#,
    );
}
