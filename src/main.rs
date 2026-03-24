mod config;
mod fmt;

use std::fs;
use std::path::{Path, PathBuf};
use std::process;
use std::sync::atomic::{AtomicBool, Ordering};

use clap::{Arg, ArgAction, Command};
use pretty::Arena;
use rayon::prelude::*;
use vhdl_lang::{VHDLParser, VHDLStandard};

use config::FormatConfig;
use fmt::Formatter;

fn main() {
    let matches = Command::new("vhdl-fmt")
        .version(env!("CARGO_PKG_VERSION"))
        .about("A fast and opinionated VHDL code formatter")
        .arg(
            Arg::new("files")
                .help("VHDL files or directories to format (directories are searched recursively for .vhd/.vhdl)")
                .num_args(1..)
                .required(true),
        )
        .arg(
            Arg::new("write")
                .long("write")
                .short('w')
                .help("Overwrite the input file(s) with the formatted output")
                .action(ArgAction::SetTrue),
        )
        .arg(
            Arg::new("check")
                .long("check")
                .short('c')
                .help("Check whether file(s) are already formatted; exit non-zero if not")
                .action(ArgAction::SetTrue),
        )
        .arg(
            Arg::new("location")
                .long("location")
                .short('l')
                .help("Path to a vhdl-fmt.toml configuration file")
                .value_name("path"),
        )
        .get_matches();

    let config = load_config(matches.get_one::<String>("location").map(Path::new));

    let args: Vec<&String> = matches.get_many("files").unwrap().collect();
    let write = matches.get_flag("write");
    let check = matches.get_flag("check");

    let files = resolve_paths(&args);
    if files.is_empty() {
        eprintln!("error: no .vhd or .vhdl files found");
        process::exit(1);
    }

    if write || check {
        // Parallel: each file is independent when writing in-place or checking.
        let had_error = AtomicBool::new(false);
        let any_unformatted = AtomicBool::new(false);

        files.par_iter().for_each(|path| {
            let source = match fs::read_to_string(path) {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("error: could not read {}: {}", path.display(), e);
                    had_error.store(true, Ordering::Relaxed);
                    return;
                }
            };
            let formatted = match format_source(&source, &config) {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("error: could not parse {}: {}", path.display(), e);
                    had_error.store(true, Ordering::Relaxed);
                    return;
                }
            };
            if source == formatted {
                return;
            }
            if check {
                eprintln!("{} is not formatted", path.display());
                any_unformatted.store(true, Ordering::Relaxed);
            } else if let Err(e) = fs::write(path, &formatted) {
                eprintln!("error: could not write {}: {}", path.display(), e);
                had_error.store(true, Ordering::Relaxed);
            }
        });

        if had_error.load(Ordering::Relaxed) || any_unformatted.load(Ordering::Relaxed) {
            process::exit(1);
        }
    } else {
        // Sequential: stdout output must preserve file order.
        for path in &files {
            let source = match fs::read_to_string(path) {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("error: could not read {}: {}", path.display(), e);
                    process::exit(1);
                }
            };
            let formatted = match format_source(&source, &config) {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("error: could not parse {}: {}", path.display(), e);
                    process::exit(1);
                }
            };
            print!("{formatted}");
        }
    }
}

// ---------------------------------------------------------------------------
// Path resolution (files + recursive directory traversal)
// ---------------------------------------------------------------------------

fn resolve_paths(args: &[&String]) -> Vec<PathBuf> {
    let mut files = Vec::new();
    for arg in args {
        let path = Path::new(arg);
        if path.is_dir() {
            collect_vhdl_files(path, &mut files);
        } else if let Some(ext) = path.extension() {
            if ext == "vhd" || ext == "vhdl" {
                files.push(path.to_path_buf());
            } else {
                eprintln!(
                    "error: {} is not a VHDL file (expected .vhd or .vhdl extension)",
                    path.display()
                );
                process::exit(1);
            }
        } else {
            eprintln!(
                "error: {} is not a VHDL file (expected .vhd or .vhdl extension)",
                path.display()
            );
            process::exit(1);
        }
    }
    files.sort();
    files
}

fn collect_vhdl_files(dir: &Path, out: &mut Vec<PathBuf>) {
    let entries = match fs::read_dir(dir) {
        Ok(e) => e,
        Err(e) => {
            eprintln!("warning: could not read directory {}: {}", dir.display(), e);
            return;
        }
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            collect_vhdl_files(&path, out);
        } else if let Some(ext) = path.extension()
            && (ext == "vhd" || ext == "vhdl")
        {
            out.push(path);
        }
    }
}

// ---------------------------------------------------------------------------
// Config loading
// ---------------------------------------------------------------------------

fn load_config(location: Option<&Path>) -> FormatConfig {
    let config_path: Option<PathBuf> = if let Some(p) = location {
        Some(p.to_path_buf())
    } else {
        let candidate = Path::new("vhdl-fmt.toml");
        candidate.exists().then(|| candidate.to_path_buf())
    };

    if let Some(path) = config_path {
        let content = match fs::read_to_string(&path) {
            Ok(c) => c,
            Err(e) => {
                eprintln!("error: could not read config {}: {}", path.display(), e);
                process::exit(1);
            }
        };
        match toml::from_str(&content) {
            Ok(cfg) => return cfg,
            Err(e) => {
                eprintln!("error: could not parse config {}: {}", path.display(), e);
                process::exit(1);
            }
        }
    }

    FormatConfig::default()
}

// ---------------------------------------------------------------------------
// Core formatting entry point
// ---------------------------------------------------------------------------

pub fn format_source(source: &str, config: &FormatConfig) -> Result<String, String> {
    let parser = VHDLParser::new(VHDLStandard::default());
    let vhdl_source = vhdl_lang::Source::inline(Path::new("<stdin>"), source);
    let mut diagnostics = Vec::new();
    let design_file = parser.parse_design_source(&vhdl_source, &mut diagnostics);

    // Surface parse errors as a combined error string.
    if !diagnostics.is_empty() {
        let errors: Vec<String> = diagnostics.iter().map(|d| d.message.clone()).collect();
        return Err(errors.join("\n"));
    }

    let arena = Arena::new();

    // Format each design unit with its own token slice (which carries comments).
    // We need to accumulate into a String directly because Doc borrows arena
    // and we can't collect Vec<Doc<'_>> with different lifetimes cleanly.
    let mut output = String::new();
    for (i, (tokens, unit)) in design_file.design_units.iter().enumerate() {
        if i > 0 {
            output.push('\n'); // blank line between design units
        }
        let formatter = Formatter::with_tokens(&arena, config, tokens.as_slice());
        let doc = formatter.format_design_unit(unit);
        doc.render_fmt(config.line_length, &mut output).map_err(|e| e.to_string())?;
        output.push('\n');
    }

    // Ensure a single trailing newline (deduplicate multiple trailing newlines).
    while output.ends_with("\n\n") {
        output.pop();
    }
    if !output.ends_with('\n') {
        output.push('\n');
    }

    Ok(output)
}
