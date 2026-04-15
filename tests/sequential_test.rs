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

//===----------------------------------------------------------------------===//
// Wait statement
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Assert / report
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Assignment statements
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Delay mechanism
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Waveforms
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// If statement
//===----------------------------------------------------------------------===//

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
        if cond then -- then comment
            v := 1; -- assignment comment
        else -- else comment
            v := 0; -- else assignment
        end if; -- end comment
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Case statement
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Loop statement
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Next / exit statements
//===----------------------------------------------------------------------===//

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

#[test]
fn next_statement() {
    assert_format(
        &wrap("for i in 0 to 9 loop next; end loop;"),
        r#"architecture rtl of e is
begin
    process
    begin
        for i in 0 to 9 loop
            next;
        end loop;
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn next_with_label_and_condition() {
    assert_format(
        &wrap("lp : for i in 0 to 9 loop next lp when i > 5; end loop;"),
        r#"architecture rtl of e is
begin
    process
    begin
        lp: for i in 0 to 9 loop
            next lp when i > 5;
        end loop lp;
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Report statement
//===----------------------------------------------------------------------===//

#[test]
fn report_statement() {
    assert_format(
        &wrap("report \"hello\";"),
        r#"architecture rtl of e is
begin
    process
    begin
        report "hello";
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn report_with_severity() {
    assert_format(
        &wrap("report \"error message\" severity error;"),
        r#"architecture rtl of e is
begin
    process
    begin
        report "error message" severity error;
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Null statement
//===----------------------------------------------------------------------===//

#[test]
fn null_statement() {
    assert_format(
        &wrap("null;"),
        r#"architecture rtl of e is
begin
    process
    begin
        null;
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Procedure call statement
//===----------------------------------------------------------------------===//

#[test]
fn procedure_call_statement() {
    assert_format(
        &wrap("do_something(a, b);"),
        r#"architecture rtl of e is
begin
    process
    begin
        do_something(a, b);
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Bare loop
//===----------------------------------------------------------------------===//

#[test]
fn bare_loop() {
    assert_format(
        &wrap("loop null; end loop;"),
        r#"architecture rtl of e is
begin
    process
    begin
        loop
            null;
        end loop;
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Wait statement variants
//===----------------------------------------------------------------------===//

#[test]
fn wait_with_sensitivity() {
    assert_format(
        &wrap("wait on clk, rst;"),
        r#"architecture rtl of e is
begin
    process
    begin
        wait on clk, rst;
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn wait_with_condition() {
    assert_format(
        &wrap("wait until clk = '1';"),
        r#"architecture rtl of e is
begin
    process
    begin
        wait until clk = '1';
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn wait_with_timeout() {
    assert_format(
        &wrap("wait for 10 ns;"),
        r#"architecture rtl of e is
begin
    process
    begin
        wait for 10 ns;
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn wait_full() {
    assert_format(
        &wrap("wait on clk until clk = '1' for 100 ns;"),
        r#"architecture rtl of e is
begin
    process
    begin
        wait on clk until clk = '1' for 100 ns;
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Case statement variants
//===----------------------------------------------------------------------===//

#[test]
fn case_with_multi_statement_alt() {
    assert_format(
        &wrap("case sel is when \"00\" => v := 0; s <= '0'; when others => null; end case;"),
        r#"architecture rtl of e is
begin
    process
    begin
        case sel is
            when "00" =>
                v := 0;
                s <= '0';
            when others => null;
        end case;
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Labeled if statement
//===----------------------------------------------------------------------===//

#[test]
fn labeled_if_statement() {
    assert_format(
        &wrap("chk : if cond then v := 1; end if chk;"),
        r#"architecture rtl of e is
begin
    process
    begin
        chk: if cond then
            v := 1;
        end if chk;
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Aligned sequential assignments
//===----------------------------------------------------------------------===//

#[test]
fn aligned_variable_assignments() {
    assert_format(
        &wrap("x := 1;\nlong_var := 2;"),
        r#"architecture rtl of e is
begin
    process
    begin
        x        := 1;
        long_var := 2;
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Comment handling in sequential statements
//===----------------------------------------------------------------------===//

#[test]
fn case_with_comments() {
    assert_format(
        &wrap(
            "-- case leading\ncase sel is -- case comment\nwhen \"00\" => v := 0; -- stmt comment\nwhen others => v := 1;\nend case; -- end comment",
        ),
        r#"architecture rtl of e is
begin
    process
    begin
        -- case leading
        case sel is -- case comment
            when "00"   => v := 0; -- stmt comment
            when others => v := 1;
        end case; -- end comment
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn while_loop_with_comments() {
    assert_format(
        &wrap(
            "-- loop leading\nwhile running loop -- loop comment\nnull; -- body comment\nend loop; -- end comment",
        ),
        r#"architecture rtl of e is
begin
    process
    begin
        -- loop leading
        while running loop -- loop comment
            null; -- body comment
        end loop; -- end comment
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn if_then_elsif_with_comments() {
    assert_format(
        &wrap(
            "if a then -- a comment\nv := 1;\nelsif b then -- b comment\nv := 2;\nelse -- else comment\nv := 0;\nend if; -- end comment",
        ),
        r#"architecture rtl of e is
begin
    process
    begin
        if a then -- a comment
            v := 1;
        elsif b then -- b comment
            v := 2;
        else -- else comment
            v := 0;
        end if; -- end comment
    end process;
end architecture rtl;"#,
    );
}
