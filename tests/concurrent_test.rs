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

//===----------------------------------------------------------------------===//
// Concurrent procedure call
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Block statement
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Process statement
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Concurrent assert
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Concurrent signal assignment
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Instantiation statement
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Generate statements
//===----------------------------------------------------------------------===//

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

#[test]
fn for_generate_with_statements() {
    assert_format(
        &wrap("gen : for i in 0 to 3 generate y(i) <= a(i) and b; end generate gen;"),
        r#"architecture rtl of e is
begin
    gen: for i in 0 to 3 generate
        y(i) <= a(i) and b;
    end generate gen;
end architecture rtl;"#,
    )
}

#[test]
fn if_generate_with_else() {
    assert_format(
        &wrap("gen : if en = '1' generate y <= a; else generate y <= '0'; end generate gen;"),
        r#"architecture rtl of e is
begin
    gen: if en = '1' generate
        y <= a;
    else generate
        y <= '0';
    end generate gen;
end architecture rtl;"#,
    )
}

#[test]
fn if_generate_with_elsif() {
    assert_format(
        &wrap("gen : if sel = \"00\" generate y <= a; elsif sel = \"01\" generate y <= b; else generate y <= '0'; end generate gen;"),
        r#"architecture rtl of e is
begin
    gen: if sel = "00" generate
        y <= a;
    elsif sel = "01" generate
        y <= b;
    else generate
        y <= '0';
    end generate gen;
end architecture rtl;"#,
    )
}

#[test]
fn case_generate() {
    assert_format(
        &wrap("gen : case sel generate when \"00\" => y <= a; when others => y <= '0'; end generate gen;"),
        r#"architecture rtl of e is
begin
    gen: case sel generate
        when "00" =>
            y <= a;
        when others =>
            y <= '0';
    end generate gen;
end architecture rtl;"#,
    )
}

//===----------------------------------------------------------------------===//
// Process statement variants
//===----------------------------------------------------------------------===//

#[test]
fn process_with_sensitivity() {
    assert_format(
        &wrap("process(clk, rst) begin end process;"),
        r#"architecture rtl of e is
begin
    process(clk, rst)
    begin

    end process;
end architecture rtl;"#,
    )
}

#[test]
fn process_with_sensitivity_all() {
    assert_format(
        &wrap("process(all) begin end process;"),
        r#"architecture rtl of e is
begin
    process(all)
    begin

    end process;
end architecture rtl;"#,
    )
}

#[test]
fn process_with_variable() {
    assert_format(
        &wrap("process variable v : integer := 0; begin null; end process;"),
        r#"architecture rtl of e is
begin
    process
        variable v : integer := 0;
    begin
        null;
    end process;
end architecture rtl;"#,
    )
}

#[test]
fn process_is_keyword() {
    assert_format(
        &wrap("process is begin null; end process;"),
        r#"architecture rtl of e is
begin
    process is
    begin
        null;
    end process;
end architecture rtl;"#,
    )
}

//===----------------------------------------------------------------------===//
// Block statement variants
//===----------------------------------------------------------------------===//

#[test]
fn block_with_guard() {
    assert_format(
        &wrap("blk : block(en = '1') begin end block blk;"),
        r#"architecture rtl of e is
begin
    blk: block(en = '1')
    begin

    end block blk;
end architecture rtl;"#,
    )
}

//===----------------------------------------------------------------------===//
// Entity/configuration instantiation
//===----------------------------------------------------------------------===//

#[test]
fn entity_instantiation() {
    assert_format(
        &wrap("u0 : entity work.comp port map(a => a, b => b);"),
        r#"architecture rtl of e is
begin
    u0: entity work.comp
        port map (
            a => a,
            b => b
        );
end architecture rtl;"#,
    )
}

#[test]
fn entity_instantiation_with_arch() {
    assert_format(
        &wrap("u0 : entity work.comp(rtl) port map(a => a);"),
        r#"architecture rtl of e is
begin
    u0: entity work.comp(rtl)
        port map (a => a);
end architecture rtl;"#,
    )
}

//===----------------------------------------------------------------------===//
// Postponed variants
//===----------------------------------------------------------------------===//

#[test]
fn postponed_concurrent_assert() {
    assert_format(
        &wrap("postponed assert stable report \"unstable\";"),
        r#"architecture rtl of e is
begin
    postponed assert stable report "unstable";
end architecture rtl;"#,
    )
}

//===----------------------------------------------------------------------===//
// Comment handling in concurrent statements
//===----------------------------------------------------------------------===//

#[test]
fn process_with_sensitivity_comment() {
    assert_format(
        &wrap("-- proc leading\nprocess(clk) -- proc comment\nbegin -- begin comment\nnull; -- null comment\nend process; -- end comment"),
        r#"architecture rtl of e is
begin
    -- proc leading
    process(clk)
    begin -- begin comment
        null; -- null comment
    end process; -- proc comment -- end comment
end architecture rtl;"#,
    )
}

#[test]
fn for_generate_with_comments() {
    assert_format(
        &wrap("-- gen leading\ngen : for i in 0 to 3 generate -- gen comment\ny <= a; -- stmt comment\nend generate gen; -- end comment"),
        r#"architecture rtl of e is
begin
    -- gen leading
    gen: for i in 0 to 3 generate
        y <= a; -- stmt comment
    end generate gen; -- gen comment -- end comment
end architecture rtl;"#,
    )
}
