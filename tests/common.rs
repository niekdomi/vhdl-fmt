// vhdl-fmt/tests/common.rs
use std::panic::Location;
use vhdl_fmt::config::FormatConfig;
use vhdl_fmt::format_source;
use vhdl_lang::VHDLStandard;

/// Format VHDL source with default config. Panics on parse errors.
#[allow(dead_code)]
pub fn fmt(input: &str) -> String {
    let config = FormatConfig::default();
    format_source(input, &config, VHDLStandard::VHDL2008).expect("parse failed")
}

/// Format VHDL source and assert the result matches `expected` exactly.
///
/// This function is annotated with `#[track_caller]` so it can discover the
/// location (file/line) of the test that invoked it. When an assertion fails
/// it will panic with a message that prints both:
///  - the caller location (the test case that called `assert_format`)
///  - the assert helper location (this file and the assert's line)
///
/// This makes it easier to see which test failed even when test harnesses
/// show the panic originating from the assert helper.
#[track_caller]
#[allow(dead_code)]
pub fn assert_format(input: &str, expected: &str) {
    let result = fmt(input);
    if result != expected {
        // Location of the test that invoked this function
        let caller_loc: &'static Location<'static> = Location::caller();
        // Location of this helper (file/line within this file)
        let helper_loc = concat!(file!(), ":", line!());

        let msg = format!(
            r#"
ASSERT_FORMAT FAILED

--- caller (test) ---
{}:{}

--- helper (assert_format) ---
{}

--- input ---
{}

--- expected ---
{}

--- got ---
{}
"#,
            caller_loc.file(),
            caller_loc.line(),
            helper_loc,
            input,
            expected,
            result
        );

        // Print to stderr to make it visible in test logs, then panic with the same message.
        eprintln!("{}", msg);
        panic!("{}", msg);
    }
}

/// Format VHDL source with custom config. Panics on parse errors.
#[allow(dead_code)]
pub fn fmt_with_config(input: &str, config: &FormatConfig) -> String {
    format_source(input, config, VHDLStandard::VHDL2008).expect("parse failed")
}

/// Format VHDL source with custom config and assert the result matches `expected` exactly.
///
/// This function is annotated with `#[track_caller]` so it can discover the
/// location (file/line) of the test that invoked it. When an assertion fails
/// it will panic with a message that prints both:
///  - the caller location (the test case that called `assert_format_with_config`)
///  - the assert helper location (this file and the assert's line)
///
/// This makes it easier to see which test failed even when test harnesses
/// show the panic originating from the assert helper.
#[track_caller]
#[allow(dead_code)]
pub fn assert_format_with_config(input: &str, expected: &str, config: &FormatConfig) {
    let result = fmt_with_config(input, config);
    if result != expected {
        // Location of the test that invoked this function
        let caller_loc: &'static Location<'static> = Location::caller();
        // Location of this helper (file/line within this file)
        let helper_loc = concat!(file!(), ":", line!());

        let msg = format!(
            r#"
ASSERT_FORMAT_WITH_CONFIG FAILED

--- caller (test) ---
{}:{}

--- helper (assert_format_with_config) ---
{}

--- input ---
{}

--- expected ---
{}

--- got ---
{}

--- config ---
{:?}
"#,
            caller_loc.file(),
            caller_loc.line(),
            helper_loc,
            input,
            expected,
            result,
            config
        );

        // Print to stderr to make it visible in test logs, then panic with the same message.
        eprintln!("{}", msg);
        panic!("{}", msg);
    }
}

/// Format already-formatted VHDL and assert idempotency.
///
/// The same caller-aware behavior is applied so test failures are easier to
/// trace back to the invoking test case.
#[track_caller]
#[allow(dead_code)]
pub fn assert_idempotent(input: &str) {
    let first = fmt(input);
    let second = fmt(&first);
    if first != second {
        let caller_loc: &'static Location<'static> = Location::caller();
        let helper_loc = concat!(file!(), ":", line!());

        let msg = format!(
            r#"
ASSERT_IDEMPOTENT FAILED

--- caller (test) ---
{}:{}

--- helper (assert_idempotent) ---
{}

--- first run ---
{}
--- second run ---
{}
"#,
            caller_loc.file(),
            caller_loc.line(),
            helper_loc,
            first,
            second
        );

        eprintln!("{}", msg);
        panic!("{}", msg);
    }
}
