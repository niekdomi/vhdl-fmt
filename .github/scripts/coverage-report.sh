#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE=${1:-"code-coverage-results.md"}
JSON_DATA="coverage.json"

# 1. Generate the JSON data if it doesn't exist
if [ ! -f "$JSON_DATA" ]; then
    cargo llvm-cov --locked --workspace --json --output-path "$JSON_DATA"
fi

# 2. Extract Totals and determine badge color
# Note: JSON structure is .data[0].totals
TOTAL_LINES_PCT=$(jq -r '(.data[0].totals.lines.percent * 100 | round) / 100' "$JSON_DATA")
TOTAL_FUNCTIONS_PCT=$(jq -r '(.data[0].totals.functions.percent * 100 | round) / 100' "$JSON_DATA")
TOTAL_REGIONS=$(jq -r '.data[0].totals.regions.count' "$JSON_DATA")

COLOR="red"
if (( $(echo "$TOTAL_LINES_PCT >= 80" | bc -l) )); then COLOR="success"
elif (( $(echo "$TOTAL_LINES_PCT >= 50" | bc -l) )); then COLOR="yellow"
fi

# 3. Start building the Markdown
echo "![Code Coverage](https://img.shields.io/badge/Code%20Coverage-${TOTAL_LINES_PCT}%25-${COLOR}?style=flat)" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Package | Function Coverage | Line Coverage | Region Coverage | " >> "$OUTPUT_FILE"
echo "-------- | --------- | ----------- | ---------- | ---" >> "$OUTPUT_FILE"

# 4. Process individual files/packages
# We use a threshold of 50% for the ❌ icon
jq -r '.data[0].files[] |
    "\(.filename) | \((.summary.functions.percent * 100 | round) / 100)% | \((.summary.lines.percent * 100 | round) / 100)% | \(.summary.regions.count) | \(if .summary.lines.percent >= 50 then "✔" else "❌" end)"' \
    "$JSON_DATA" >> "$OUTPUT_FILE"

# 5. Add the Summary row
SUMMARY_ICON=$( [ "$(echo "$TOTAL_LINES_PCT >= 50" | bc -l)" -eq 1 ] && echo "✔" || echo "❌" )
TOTAL_LINES_COUNT=$(jq -r '.data[0].totals.lines.count' "$JSON_DATA")
TOTAL_LINES_COVERED=$(jq -r '.data[0].totals.lines.covered' "$JSON_DATA")
TOTAL_FUNC_COUNT=$(jq -r '.data[0].totals.functions.count' "$JSON_DATA")
TOTAL_FUNC_COVERED=$(jq -r '.data[0].totals.functions.covered' "$JSON_DATA")

echo "**Summary** | **${TOTAL_FUNCTIONS_PCT}%** (${TOTAL_FUNC_COVERED} / ${TOTAL_FUNC_COUNT}) | **${TOTAL_LINES_PCT}%** (${TOTAL_LINES_COVERED} / ${TOTAL_LINES_COUNT}) | ${TOTAL_REGIONS} | ${SUMMARY_ICON}" >> "$OUTPUT_FILE"
