#!/usr/bin/env python3
import json
import os
import sys


def generate_report(json_path, output_path):
    if not os.path.exists(json_path):
        print(f"Error: {json_path} not found.")
        sys.exit(1)

    with open(json_path) as f:
        data = json.load(f)["data"][0]

    totals = data["totals"]
    line_pct = totals["lines"]["percent"]

    # Determine badge color
    color = "success" if line_pct >= 80 else "yellow" if line_pct >= 50 else "critical"

    lines = [
        f"![Code Coverage](https://img.shields.io/badge/Code%20Coverage-{line_pct:.0f}%25-{color}?style=flat)",
        "",
        "| File | Line Coverage | Function Coverage | Region Coverage | Status |",
        "|:---|:---|:---|:---|:---:|",
    ]

    # Sort files by filename for consistent PR diffs
    for file_data in sorted(data["files"], key=lambda x: x["filename"]):
        filename = file_data["filename"]
        # Clean up path: strip 'src/' prefix if present
        display_name = filename.split("src/", 1)[-1] if "src/" in filename else filename

        s = file_data["summary"]
        lp, fp, rp = (
            s["lines"]["percent"],
            s["functions"]["percent"],
            s["regions"]["percent"],
        )

        # Add a visual health indicator per file
        status = "✔" if lp >= 50 else "❌"

        lines.append(
            f"| `{display_name}` | {lp:.1f}% | {fp:.1f}% | {rp:.1f}% | {status} |"
        )

    # Add Summary Footer
    tl, tf, tr = totals["lines"], totals["functions"], totals["regions"]
    lines.append(
        f"| **Summary** | "
        f"**{tl['percent']:.1f}%** ({tl['covered']}/{tl['count']}) | "
        f"**{tf['percent']:.1f}%** ({tf['covered']}/{tf['count']}) | "
        f"**{tr['percent']:.1f}%** ({tr['covered']}/{tr['count']}) | "
        f"{'✔' if line_pct >= 50 else '❌'} |"
    )

    with open(output_path, "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    # Usage: python3 coverage_report.py coverage.json coverage.md
    json_in = sys.argv[1] if len(sys.argv) > 1 else "coverage.json"
    md_out = sys.argv[2] if len(sys.argv) > 2 else "code-coverage-results.md"
    generate_report(json_in, md_out)
