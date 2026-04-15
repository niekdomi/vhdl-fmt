mod common;
use common::assert_format;

//===----------------------------------------------------------------------===//
// Multiple leading comments
//===----------------------------------------------------------------------===//

#[test]
fn multiple_leading_comments() {
    assert_format(
        r#"-- comment 1
-- comment 2
-- comment 3
entity e is
end e;"#,
        r#"-- comment 1
-- comment 2
-- comment 3
entity e is
end entity e;"#,
    );
}

#[test]
fn leading_comment_with_blank_line_before_decl() {
    assert_format(
        r#"package p is
-- leading
signal s : std_logic;
end p;"#,
        r#"package p is
    -- leading
    signal s : std_logic;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Blank line preservation between declarations
//===----------------------------------------------------------------------===//

#[test]
fn multiple_blank_line_between_signals() {
    assert_format(
        r#"package p is
signal a : std_logic;


signal b : std_logic;
end p;"#,
        r#"package p is
    signal a : std_logic;

    signal b : std_logic;
end package p;"#,
    );
}

#[test]
fn blank_line_between_signal_groups() {
    assert_format(
        r#"package p is
signal clk : std_logic;
signal rst : std_logic;

signal data : integer;
signal valid : std_logic;
end p;"#,
        r#"package p is
    signal clk : std_logic;
    signal rst : std_logic;

    signal data  : integer;
    signal valid : std_logic;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Trailing comments preserved in place
//===----------------------------------------------------------------------===//

#[test]
fn trailing_comment_on_signal() {
    assert_format(
        r#"package p is
signal clk : std_logic; -- system clock
signal rst : std_logic; -- active high reset
end p;"#,
        r#"package p is
    signal clk : std_logic; -- system clock
    signal rst : std_logic; -- active high reset
end package p;"#,
    );
}

#[test]
fn trailing_comment_on_constant() {
    assert_format(
        r#"package p is
constant WIDTH : integer := 8; -- data bus width
end p;"#,
        r#"package p is
    constant WIDTH : integer := 8; -- data bus width
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Leading + trailing comments combined
//===----------------------------------------------------------------------===//

#[test]
fn leading_and_trailing_on_signal() {
    assert_format(
        r#"package p is
-- leading comment
signal clk : std_logic; -- trailing comment
end p;"#,
        r#"package p is
    -- leading comment
    signal clk : std_logic; -- trailing comment
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Comments on structural keywords (is, begin, etc.)
// These move to the nearest end keyword of the enclosing construct.
//===----------------------------------------------------------------------===//

#[test]
fn comment_on_entity_is_stays_inline() {
    assert_format(
        r#"entity e is -- entity comment
end e;"#,
        r#"entity e is -- entity comment
end entity e;"#,
    );
}

#[test]
fn comment_on_arch_is_stays_inline() {
    assert_format(
        r#"architecture rtl of e is -- arch comment
begin
end rtl;"#,
        r#"architecture rtl of e is -- arch comment
begin

end architecture rtl;"#,
    );
}

#[test]
fn comment_on_begin_stays_inline() {
    assert_format(
        r#"architecture rtl of e is
begin -- begin comment
end rtl;"#,
        r#"architecture rtl of e is
begin -- begin comment

end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Comments in process bodies
//===----------------------------------------------------------------------===//

#[test]
fn comment_between_process_statements() {
    assert_format(
        r#"architecture rtl of e is
begin
    process
    begin
        -- first leading
        a <= '1'; -- first trailing
        -- second leading
        b <= '0'; -- second trailing
    end process;
end rtl;"#,
        r#"architecture rtl of e is
begin
    process
    begin
        -- first leading
        a <= '1'; -- first trailing
        -- second leading
        b <= '0'; -- second trailing
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn comment_on_process_sensitivity_moves_to_end() {
    assert_format(
        r#"architecture rtl of e is
begin
    process(clk) -- clk comment
    begin
        null;
    end process;
end rtl;"#,
        r#"architecture rtl of e is
begin
    process(clk) -- clk comment
    begin
        null;
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Comments in if-generate
//===----------------------------------------------------------------------===//

#[test]
fn comment_on_generate_keyword_moves_to_end() {
    assert_format(
        r#"architecture rtl of e is
begin
    gen: if en = '1' generate -- gen comment
        y <= a;
    end generate gen;
end rtl;"#,
        r#"architecture rtl of e is
begin
    gen: if en = '1' generate
        y <= a;
    end generate gen; -- gen comment
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Comments in case generate
//===----------------------------------------------------------------------===//

#[test]
fn comment_in_case_generate_body() {
    assert_format(
        r#"architecture rtl of e is
begin
    gen: case sel generate
        when "00" =>
            -- branch comment
            y <= a;
        when others =>
            y <= '0';
    end generate gen;
end rtl;"#,
        r#"architecture rtl of e is
begin
    gen: case sel generate
        when "00" =>
            -- branch comment
            y <= a;
        when others =>
            y <= '0';
    end generate gen;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Comments in if/elsif/else branches
//===----------------------------------------------------------------------===//

#[test]
fn leading_comment_in_if_branch() {
    assert_format(
        r#"architecture rtl of e is
begin
    process
    begin
        if cond then
            -- branch body comment
            v := 1;
        end if;
    end process;
end rtl;"#,
        r#"architecture rtl of e is
begin
    process
    begin
        if cond then
            -- branch body comment
            v := 1;
        end if;
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Block comments (/* ... */)
//===----------------------------------------------------------------------===//

#[test]
fn block_comment_leading() {
    assert_format(
        r#"/* file header comment */
entity e is
end e;"#,
        r#"/* file header comment */
entity e is
end entity e;"#,
    );
}

#[test]
fn block_comment_on_declaration() {
    assert_format(
        r#"package p is
/* multi-line
   block comment */
signal s : std_logic;
end p;"#,
        r#"package p is
    /* multi-line
   block comment */
    signal s : std_logic;
end package p;"#,
    );
}

#[test]
fn block_comment_after_semicolon_becomes_leading_of_next() {
    assert_format(
        r#"package p is
signal s : std_logic; /* trailing block comment */
end p;"#,
        r#"package p is
    signal s : std_logic; /* trailing block comment */
end package p;"#,
    );
}

#[test]
fn block_comment_after_is_becomes_leading_of_end() {
    assert_format(
        r#"entity e is /* is comment */
end e;"#,
        r#"entity e is /* is comment */
end entity e;"#,
    );
}

#[test]
fn block_comment_between_process_statements() {
    assert_format(
        r#"architecture rtl of e is
begin
    process
    begin
        /* reset */
        a <= '0';
        /* compute */
        b <= a;
    end process;
end rtl;"#,
        r#"architecture rtl of e is
begin
    process
    begin
        /* reset */
        a <= '0';
        /* compute */
        b <= a;
    end process;
end architecture rtl;"#,
    );
}

#[test]
fn block_comment_multiple_leading() {
    assert_format(
        r#"/* copyright notice */
/* version: 1.0 */
entity e is
end e;"#,
        r#"/* copyright notice */
/* version: 1.0 */
entity e is
end entity e;"#,
    );
}

#[test]
fn block_comment_mixed_with_line_comment() {
    assert_format(
        r#"package p is
/* block leading */
-- line leading
signal s : std_logic;
end p;"#,
        r#"package p is
    /* block leading */
    -- line leading
    signal s : std_logic;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Comments preserved across design units
//===----------------------------------------------------------------------===//

#[test]
fn comment_between_design_units() {
    assert_format(
        r#"entity e is end e;
-- between comment
architecture rtl of e is begin end rtl;"#,
        r#"entity e is
end entity e;

-- between comment
architecture rtl of e is
begin

end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Trailing comments in port maps / generic maps
//===----------------------------------------------------------------------===//

#[test]
fn trailing_comment_in_port_map() {
    assert_format(
        r#"architecture rtl of e is
begin
    inst : entity work.foo
        port map (
            a => sig_a, -- port a
            b => sig_b, -- port b
            c => sig_c
        );
end rtl;"#,
        r#"architecture rtl of e is
begin
    inst: entity work.foo
        port map (
            a => sig_a, -- port a
            b => sig_b, -- port b
            c => sig_c
        );
end architecture rtl;"#,
    );
}

#[test]
fn trailing_comment_on_last_port_map_item() {
    assert_format(
        r#"architecture rtl of e is
begin
    inst : entity work.foo
        port map (
            a => sig_a, -- port a
            b => sig_b  -- port b
        );
end rtl;"#,
        r#"architecture rtl of e is
begin
    inst: entity work.foo
        port map (
            a => sig_a, -- port a
            b => sig_b -- port b
        );
end architecture rtl;"#,
    );
}

#[test]
fn trailing_comment_in_generic_map() {
    assert_format(
        r#"architecture rtl of e is
begin
    inst : entity work.foo
        generic map (
            G1 => 1, -- generic 1
            G2 => 2  -- generic 2
        )
        port map (
            a => sig_a
        );
end rtl;"#,
        r#"architecture rtl of e is
begin
    inst: entity work.foo
        generic map (
            G1 => 1, -- generic 1
            G2 => 2 -- generic 2
        )
        port map (a => sig_a);
end architecture rtl;"#,
    );
}

#[test]
fn trailing_comment_in_function_call() {
    assert_format(
        r#"architecture rtl of e is
begin
    result <= func(
        x, -- arg x
        y, -- arg y
        z
    );
end rtl;"#,
        r#"architecture rtl of e is
begin
    result <= func(
                  x, -- arg x
                  y, -- arg y
                  z
              );
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Blank line between context clause and unit keyword
//===----------------------------------------------------------------------===//

#[test]
fn blank_line_between_context_and_entity_preserved() {
    assert_format(
        r#"library ieee;
use ieee.std_logic_1164.all;

entity e is
end e;"#,
        r#"library ieee;
use ieee.std_logic_1164.all;

entity e is
end entity e;"#,
    );
}

#[test]
fn no_blank_line_between_context_and_entity_not_added() {
    assert_format(
        r#"library ieee;
use ieee.std_logic_1164.all;
entity e is
end e;"#,
        r#"library ieee;
use ieee.std_logic_1164.all;
entity e is
end entity e;"#,
    );
}

#[test]
fn blank_line_between_context_and_architecture_preserved() {
    assert_format(
        r#"library ieee;
use ieee.std_logic_1164.all;

architecture rtl of e is
begin
end rtl;"#,
        r#"library ieee;
use ieee.std_logic_1164.all;

architecture rtl of e is
begin

end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// Trailing comment on if/elsif then keyword
//===----------------------------------------------------------------------===//

#[test]
fn trailing_comment_on_elsif_then_preserved() {
    assert_format(
        r#"architecture rtl of e is
begin
    process
    begin
        if a then -- first
            null;
        elsif b then -- second
            null;
        end if;
    end process;
end rtl;"#,
        r#"architecture rtl of e is
begin
    process
    begin
        if a then -- first
            null;
        elsif b then -- second
            null;
        end if;
    end process;
end architecture rtl;"#,
    );
}

//===----------------------------------------------------------------------===//
// EOF comments
//===----------------------------------------------------------------------===//

#[test]
fn comment_at_eof_preserved() {
    assert_format(
        "entity e is\nend e;\n-- eof comment",
        "entity e is\nend entity e;\n-- eof comment",
    );
}

#[test]
fn multiple_comments_at_eof_preserved() {
    assert_format(
        r#"entity e is
end e;
-- first eof
-- second eof"#,
        r#"entity e is
end entity e;
-- first eof
-- second eof"#,
    );
}

//===----------------------------------------------------------------------===//
// Trailing comment does not count toward line length
//===----------------------------------------------------------------------===//

#[test]
fn trailing_comment_does_not_cause_code_wrap_when_code_fits() {
    assert_format(
        r#"entity e is
port (
    my_output_port : out std_logic_vector(DATA_BUS - 1 downto 0); -- this is the output data bus port here
    other : in std_logic
);
end e;"#,
        r#"entity e is
    port (
        my_output_port : out std_logic_vector(DATA_BUS - 1 downto 0); -- this is the output data bus port here
        other          : in  std_logic
    );
end entity e;"#,
    );
}

#[test]
fn code_that_exceeds_line_length_wraps_even_with_comment() {
    assert_format(
        r#"entity e is
port (
    very_long_output_port_name_here_extra : out std_logic_vector(SOME_VERY_LONG_CONSTANT_WIDTH - 1 downto 0); -- comment
    other : in std_logic
);
end e;"#,
        r#"entity e is
    port (
        very_long_output_port_name_here_extra : out std_logic_vector(SOME_VERY_LONG_CONSTANT_WIDTH -
                                                                     1 downto 0); -- comment
        other                                 : in  std_logic
    );
end entity e;"#,
    );
}
