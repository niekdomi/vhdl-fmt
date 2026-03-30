mod common;

use common::assert_format;

fn wrap(expr: &str) -> String {
    format!(
        "architecture rtl of e is begin process begin v := {expr}; end process; end rtl;",
        expr = expr
    )
}

//===---------------------------------------------------------------------===//
// Names (designator, selected, slice, call/indexed)
//===---------------------------------------------------------------------===//

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

//===---------------------------------------------------------------------===//
// Association lists (port map / generic map / call arguments)
//===---------------------------------------------------------------------===//

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

//===---------------------------------------------------------------------===//
// Indexed names
//===---------------------------------------------------------------------===//

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

//===---------------------------------------------------------------------===//
// Sliced names
//===---------------------------------------------------------------------===//

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
