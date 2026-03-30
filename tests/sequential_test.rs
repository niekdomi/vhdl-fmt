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
