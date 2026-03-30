use vhdl_fmt::config::{CasingMode, FormatConfig};
use vhdl_lang::VHDLStandard;

fn fmt_with_config(input: &str, config: &FormatConfig) -> String {
    vhdl_fmt::format_source(input, config, VHDLStandard::VHDL2008).expect("parse failed")
}

fn assert_format_config(input: &str, expected: &str, config: &FormatConfig) {
    let result = fmt_with_config(input, config);
    if result != expected {
        eprintln!(
            r#"
ASSERT_FORMAT_CONFIG FAILED

--- input ---
{}

--- expected ---
{}

--- got ---
{}

--- config ---
{:?}
"#,
            input, expected, result, config
        );
        panic!("ASSERT_FORMAT_CONFIG FAILED");
    }
}

#[test]
fn line_length_wrapping() {
    let mut config = FormatConfig::default();
    config.line_length = 50;

    let input = r#"architecture rtl of e is begin u : entity work.long_component_name generic map(param1 => value1, param2 => value2) port map(a => b, c => d); end rtl;"#;
    let expected = r#"architecture rtl of e is
begin
    u: entity work.long_component_name
        generic map (
            param1 => value1,
            param2 => value2
        )
        port map (
            a => b,
            c => d
        );
end architecture rtl;"#;

    assert_format_config(input, expected, &config);
}

#[test]
fn indentation_size() {
    let mut config = FormatConfig::default();
    config.indentation.size = 2;

    let input = r#"architecture rtl of e is begin process begin if cond then v := 1; end if; end process; end rtl;"#;
    let expected = r#"architecture rtl of e is
begin
  process
  begin
    if cond then
      v := 1;
    end if;
  end process;
end architecture rtl;"#;

    assert_format_config(input, expected, &config);
}

#[test]
fn casing_keywords_uppercase() {
    let mut config = FormatConfig::default();
    config.casing.keywords = CasingMode::UpperCase;

    let input = r#"architecture rtl of e is begin process begin if cond then v := 1; end if; end process; end rtl;"#;
    let expected = r#"ARCHITECTURE rtl OF e IS
BEGIN
    PROCESS
    BEGIN
        IF cond THEN
            v := 1;
        END IF;
    END PROCESS;
END ARCHITECTURE rtl;"#;

    assert_format_config(input, expected, &config);
}

#[test]
fn casing_identifiers_lowercase() {
    let mut config = FormatConfig::default();
    config.casing.identifiers = CasingMode::LowerCase;

    let input = r#"architecture RTL of E is signal CLK : std_logic; begin end RTL;"#;
    let expected = r#"architecture rtl of e is
    signal clk : std_logic;
begin

end architecture rtl;"#;

    assert_format_config(input, expected, &config);
}

#[test]
fn casing_identifiers_uppercase() {
    let mut config = FormatConfig::default();
    config.casing.identifiers = CasingMode::UpperCase;

    let input = r#"package p is constant my_const : integer := 42; end p;"#;
    let expected = r#"package P is
    constant MY_CONST : INTEGER := 42;
end package P;"#;

    assert_format_config(input, expected, &config);
}

#[test]
fn combined_config() {
    let mut config = FormatConfig::default();
    config.line_length = 60;
    config.indentation.size = 2;
    config.casing.keywords = CasingMode::UpperCase;
    config.casing.identifiers = CasingMode::LowerCase;

    let input = r#"architecture RTL of E is signal CLK : std_logic; begin PROCESS begin if COND then CLK <= '1'; end if; end PROCESS; end RTL;"#;
    let expected = r#"ARCHITECTURE rtl OF e IS
  SIGNAL clk : std_logic;
BEGIN
  PROCESS
  BEGIN
    IF cond THEN
      clk <= '1';
    END IF;
  END PROCESS;
END ARCHITECTURE rtl;"#;

    assert_format_config(input, expected, &config);
}
