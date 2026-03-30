"""Generates a Markdown coverage report from cargo-llvm-cov JSON output."""

import json
import sys
from pathlib import Path
from typing import Any

# TODO: Pass thresholds as arguments
MIN_SUCCESS_PCT = 80
MIN_ACCEPTABLE_PCT = 50

REQUIRED_ARGS_COUNT = 2


def generate_report(json_path: Path | str, output_path: Path | str) -> None:
    """Parse LLVM coverage JSON and write a formatted Markdown table.

    Args:
        json_path: Path to the input coverage.json file.
        output_path: Path where the markdown report will be saved.

    """
    path_in = Path(json_path)
    if not path_in.exists():
        print(f"Error: {json_path} not found.")
        sys.exit(1)

    with path_in.open(encoding="utf-8") as f:
        data = json.load(f)["data"][0]

    totals: dict[str, Any] = data["totals"]
    line_pct: float = float(totals["lines"]["percent"])

    # Determine badge color
    if line_pct >= MIN_SUCCESS_PCT:
        color = "success"
    elif line_pct >= MIN_ACCEPTABLE_PCT:
        color = "yellow"
    else:
        color = "critical"

    lines = [
        f"![Code Coverage](https://img.shields.io/badge/Code%20Coverage-{line_pct:.0f}%25-{color}?style=flat)",
        "",
        "| File | Line Coverage | Function Coverage | Region Coverage | Status |",
        "|:---|:---|:---|:---|:---:|",
    ]

    # Sort files by filename for consistent PR diffs
    for file_data in sorted(data["files"], key=lambda x: str(x["filename"])):
        filename = file_data["filename"]
        display_name = filename.split("src/", 1)[-1] if "src/" in filename else filename

        s = file_data["summary"]
        lp, fp, rp = (
            s["lines"]["percent"],
            s["functions"]["percent"],
            s["regions"]["percent"],
        )

        status = "✔" if lp >= MIN_ACCEPTABLE_PCT else "❌"

        lines.append(
            f"| `{display_name}` | {lp:.1f}% | {fp:.1f}% | {rp:.1f}% | {status} |",
        )

    # Add Summary Footer
    tl, tf, tr = totals["lines"], totals["functions"], totals["regions"]
    summary_status = "✔" if line_pct >= MIN_ACCEPTABLE_PCT else "❌"
    lines.append(
        f"| **Summary** | "
        f"**{tl['percent']:.1f}%** ({tl['covered']}/{tl['count']}) | "
        f"**{tf['percent']:.1f}%** ({tf['covered']}/{tf['count']}) | "
        f"**{tr['percent']:.1f}%** ({tr['covered']}/{tr['count']}) | "
        f"{summary_status} |",
    )

    path_out = Path(output_path)
    with path_out.open("w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    # Usage: python3 coverage_report.py coverage.json coverage.md
    json_input = sys.argv[1] if len(sys.argv) > 1 else "coverage.json"
    md_output = (
        sys.argv[REQUIRED_ARGS_COUNT]
        if len(sys.argv) > REQUIRED_ARGS_COUNT
        else "code-coverage-results.md"
    )
    generate_report(json_input, md_output)
