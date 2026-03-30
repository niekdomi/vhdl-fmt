mod common;

use common::assert_format;

fn wrap(stmts: &str) -> String {
    format!(
        r#"architecture rtl of e is begin process begin
{stmts}
end process; end rtl;"#,
        stmts = stmts
    )
}

//===---------------------------------------------------------------------===//
// Wait statement
//===---------------------------------------------------------------------===//

#[test]
fn wait_unconditional() {
    assert_format(
        &wrap("wait;"),
        r#"architecture rtl of e is
begin
    process
    begin
        wait;
    end process;
end architecture rtl;"#,
    );
}

//===---------------------------------------------------------------------===//
// Assert / report
//===---------------------------------------------------------------------===//

#[test]
fn assert_statement() {
    assert_format(
        &wrap("assert x = 1 report \"bad\";"),
        r#"architecture rtl of e is
begin
    process
    begin
        assert x = 1 report "bad";
    end process;
end architecture rtl;"#,
    );
}

//===---------------------------------------------------------------------===//
// Assignment statements
//===---------------------------------------------------------------------===//

#[test]
fn variable_assignment() {
    assert_format(
        &wrap("v := 42;"),
        r#"architecture rtl of e is
begin
    process
    begin
        v := 42;
    end process;
end architecture rtl;"#,
    );
}

//===---------------------------------------------------------------------===//
// Delay mechanism
//===---------------------------------------------------------------------===//

#[test]
fn signal_assignment_after() {
    assert_format(
        &wrap("s <= transport '1' after 10 ns;"),
        r#"architecture rtl of e is
begin
    process
    begin
        s <= transport '1' after 10 ns;
    end process;
end architecture rtl;"#,
    );
}

//===---------------------------------------------------------------------===//
// Waveforms
//===---------------------------------------------------------------------===//

#[test]
fn signal_assignment_waveform() {
    assert_format(
        &wrap("s <= '0', '1' after 10 ns;"),
        r#"architecture rtl of e is
begin
    process
    begin
        s <= '0', '1' after 10 ns;
    end process;
end architecture rtl;"#,
    );
}

//===---------------------------------------------------------------------===//
// If statement
//===---------------------------------------------------------------------===//

#[test]
fn if_then_else() {
    assert_format(
        &wrap("if cond then v := 1; else v := 0; end if;"),
        r#"architecture rtl of e is
begin
    process
    begin
        if cond then
            v := 1;
        else
            v := 0;
        end if;
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn if_then_else_with_comments() {
    assert_format(
        &wrap(
            "-- leading comment\nif cond then -- then comment\nv := 1; -- assignment comment\nelse -- else comment\nv := 0; -- else assignment\nend if; -- end comment",
        ),
        r#"architecture rtl of e is
begin
    process
    begin
        -- leading comment
        if cond then
            v := 1; -- assignment comment
        else
            v := 0; -- else assignment
        end if; -- then comment -- else comment -- end comment
    end process;
end architecture rtl;"#,
    );
}

//===---------------------------------------------------------------------===//
// Case statement
//===---------------------------------------------------------------------===//

#[test]
fn case_statement() {
    assert_format(
        &wrap("case sel is when \"00\" => v := 0; when others => v := 1; end case;"),
        r#"architecture rtl of e is
begin
    process
    begin
        case sel is
            when "00"   => v := 0;
            when others => v := 1;
        end case;
    end process;
end architecture rtl;"#,
    );
}

//===---------------------------------------------------------------------===//
// Loop statement
//===---------------------------------------------------------------------===//

#[test]
fn while_loop() {
    assert_format(
        &wrap("while running loop null; end loop;"),
        r#"architecture rtl of e is
begin
    process
    begin
        while running loop
            null;
        end loop;
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn for_loop() {
    assert_format(
        &wrap("for i in 0 to 10 loop v := i; end loop;"),
        r#"architecture rtl of e is
begin
    process
    begin
        for i in 0 to 10 loop
            v := i;
        end loop;
    end process;
end architecture rtl;"#,
    );
}

//===---------------------------------------------------------------------===//
// Next / exit statements
//===---------------------------------------------------------------------===//

#[test]
fn exit_statement() {
    assert_format(
        &wrap("lp : loop exit lp; end loop;"),
        r#"architecture rtl of e is
begin
    process
    begin
        lp: loop
            exit lp;
        end loop lp;
    end process;
end architecture rtl;"#,
    );
}
