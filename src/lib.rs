pub mod config;
pub mod fmt;

use std::collections::BTreeSet;
use std::path::Path;

use pretty::Arena;
use vhdl_lang::{Token, VHDLParser, VHDLStandard};

use config::FormatConfig;
use fmt::Formatter;

pub fn format_source(
    source: &str,
    config: &FormatConfig,
    standard: VHDLStandard,
) -> Result<String, String> {
    let parser = VHDLParser::new(standard);
    let vhdl_source = vhdl_lang::Source::inline(Path::new("<stdin>"), source);
    let mut diagnostics = Vec::new();
    let design_file = parser.parse_design_source(&vhdl_source, &mut diagnostics);

    if !diagnostics.is_empty() {
        let errors: Vec<String> = diagnostics
            .iter()
            .map(|d| {
                let pos = d.pos.range();
                format!("{}:{}: {}", pos.start.line + 1, pos.start.character + 1, d.message)
            })
            .collect();
        return Err(errors.join("\n"));
    }

    let arena = Arena::new();

    let mut output = String::new();
    for (i, (tokens, unit)) in design_file.design_units.iter().enumerate() {
        if i > 0 {
            output.push('\n');
        }
        let formatter = Formatter::with_tokens(&arena, config, tokens.as_slice());
        let doc = formatter.format_design_unit(unit);
        doc.render_fmt(config.line_length, &mut output).map_err(|e| e.to_string())?;
        output.push('\n');
    }

    output = output.lines().map(str::trim_end).collect::<Vec<_>>().join("\n");

    output = output.trim_end().to_string();

    Ok(output)
}

/// Verify formatting by re-parsing, checking idempotency, and checking comment preservation.
pub fn verify_formatting(
    source: &str,
    formatted: &str,
    config: &FormatConfig,
    standard: VHDLStandard,
) -> Result<String, String> {
    let parser = VHDLParser::new(standard);
    let out_source = vhdl_lang::Source::inline(Path::new("<verify>"), formatted);
    let mut diagnostics = Vec::new();
    let _out_file = parser.parse_design_source(&out_source, &mut diagnostics);
    if !diagnostics.is_empty() {
        let errors: Vec<String> = diagnostics
            .iter()
            .map(|d| {
                let pos = d.pos.range();
                format!("{}:{}: {}", pos.start.line + 1, pos.start.character + 1, d.message)
            })
            .collect();
        return Err(format!("formatted output has parse errors:\n{}", errors.join("\n")));
    }

    let mut stable = formatted.to_string();
    for _ in 0..4 {
        let reformatted = format_source(&stable, config, standard)
            .map_err(|e| format!("re-format failed: {e}"))?;
        if stable == reformatted {
            break;
        }
        stable = reformatted;
    }
    let final_check =
        format_source(&stable, config, standard).map_err(|e| format!("re-format failed: {e}"))?;
    if stable != final_check {
        return Err("formatting does not converge after 5 passes".into());
    }

    let in_source = vhdl_lang::Source::inline(Path::new("<verify-in>"), source);
    let mut in_diag = Vec::new();
    let in_file = parser.parse_design_source(&in_source, &mut in_diag);

    let stable_source = vhdl_lang::Source::inline(Path::new("<verify-out>"), &stable);
    let mut stable_diag = Vec::new();
    let stable_file = parser.parse_design_source(&stable_source, &mut stable_diag);

    let in_comments = collect_comments(&in_file.design_units);
    let out_comments = collect_comments(&stable_file.design_units);

    let missing: BTreeSet<_> = in_comments.difference(&out_comments).collect();
    if !missing.is_empty() {
        return Err(format!("{} comment(s) lost during formatting", missing.len()));
    }

    Ok(stable)
}

fn collect_comments(
    design_units: &[(Vec<Token>, vhdl_lang::ast::AnyDesignUnit)],
) -> BTreeSet<String> {
    let mut comments = BTreeSet::new();
    for (tokens, _) in design_units {
        for token in tokens {
            if let Some(tc) = &token.comments {
                for c in &tc.leading {
                    comments.insert(c.value.trim_end().to_string());
                }
                if let Some(c) = &tc.trailing {
                    comments.insert(c.value.trim_end().to_string());
                }
            }
        }
    }
    comments
}
