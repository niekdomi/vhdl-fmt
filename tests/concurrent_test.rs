mod common;

use common::assert_format;

fn wrap(body: &str) -> String {
    format!(
        r#"architecture rtl of e is
begin
{body}
end architecture rtl;"#,
        body = body
    )
}

//===---------------------------------------------------------------------===//
// Concurrent procedure call
//===---------------------------------------------------------------------===//

#[test]
fn concurrent_procedure_call() {
    assert_format(
        &wrap("check_inputs;"),
        r#"architecture rtl of e is
begin
    check_inputs();
end architecture rtl;"#,
    )
}

//===---------------------------------------------------------------------===//
// Block statement
//===---------------------------------------------------------------------===//

#[test]
fn block_statement_simple() {
    assert_format(
        &wrap("blk : block begin end block blk;"),
        r#"architecture rtl of e is
begin
    blk: block
    begin

    end block blk;
end architecture rtl;"#,
    )
}

//===---------------------------------------------------------------------===//
// Process statement
//===---------------------------------------------------------------------===//

#[test]
fn process_empty() {
    assert_format(
        &wrap("process begin end process;"),
        r#"architecture rtl of e is
begin
    process
    begin

    end process;
end architecture rtl;"#,
    )
}

//===---------------------------------------------------------------------===//
// Concurrent assert
//===---------------------------------------------------------------------===//

#[test]
fn concurrent_assert() {
    assert_format(
        &wrap("assert false report \"fail\";"),
        r#"architecture rtl of e is
begin
    assert false report "fail";
end architecture rtl;"#,
    )
}

//===---------------------------------------------------------------------===//
// Concurrent signal assignment
//===---------------------------------------------------------------------===//

#[test]
fn concurrent_signal_assignment_simple() {
    assert_format(
        &wrap("y <= a and b;"),
        r#"architecture rtl of e is
begin
    y <= a and b;
end architecture rtl;"#,
    )
}

#[test]
fn concurrent_signal_assignment_conditional() {
    assert_format(
        &wrap("y <= a when sel else b;"),
        r#"architecture rtl of e is
begin
    y <= a when sel else b;
end architecture rtl;"#,
    )
}

#[test]
fn concurrent_signal_assignment_selected() {
    assert_format(
        &wrap("with sel select y <= a when '0', b when '1';"),
        r#"architecture rtl of e is
begin
    with sel select y <= a when '0',
    b when '1';
end architecture rtl;"#,
    )
}

#[test]
fn concurrent_signal_assignment_with_comments() {
    assert_format(
        &wrap("-- leading comment\ny <= a and b; -- trailing comment"),
        r#"architecture rtl of e is
begin
    -- leading comment
    y <= a and b; -- trailing comment
end architecture rtl;"#,
    )
}

//===---------------------------------------------------------------------===//
// Instantiation statement
//===---------------------------------------------------------------------===//

#[test]
fn component_instantiation() {
    assert_format(
        &wrap("u0 : comp port map(a => a, b => b);"),
        r#"architecture rtl of e is
begin
    u0: component comp
        port map (
            a => a,
            b => b
        );
end architecture rtl;"#,
    )
}

//===---------------------------------------------------------------------===//
// Generate statements
//===---------------------------------------------------------------------===//

#[test]
fn for_generate() {
    assert_format(
        &wrap("gen : for i in 0 to 3 generate end generate gen;"),
        r#"architecture rtl of e is
begin
    gen: for i in 0 to 3 generate

    end generate gen;
end architecture rtl;"#,
    )
}
