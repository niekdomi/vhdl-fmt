#!/bin/bash
set -euo pipefail

INPUT="build/Debug/coverage/coverage.txt"
OUTPUT="coverage.md"

if [[ ! -f "$INPUT" ]]; then
    echo "Warning: Coverage file not found at $INPUT" >&2
    exit 0
fi

# Header
{
    echo "### 📊 Test Coverage Report"
    echo
} >"$OUTPUT"

# Read ONLY valid data rows
# Pattern: filename funcs missed func_cover branches missed_branches branch_cover
TABLE_LINES=$(awk '
    NF >= 7 &&
    $2 ~ /^[0-9]+$/ &&
    $3 ~ /^[0-9]+$/ &&
    $(NF-2) ~ /^[0-9]+$/ &&
    $(NF-1) ~ /^[0-9]+$/
' "$INPUT")

# Compute total branch coverage
total_branches=0
total_missed=0

while read -r line; do
    [[ -z "$line" ]] && continue

    filename=$(echo "$line" | awk '{print $1}')
    [[ "$filename" == "TOTAL" ]] && continue

    branches=$(echo "$line" | awk '{print $(NF-2)}')
    missed=$(echo "$line" | awk '{print $(NF-1)}')

    if [[ "$branches" =~ ^[0-9]+$ ]] && [[ "$missed" =~ ^[0-9]+$ ]]; then
        total_branches=$((total_branches + branches))
        total_missed=$((total_missed + missed))
    fi
done <<<"$TABLE_LINES"

if [[ $total_branches -gt 0 ]]; then
    total_covered=$((total_branches - total_missed))
    total_percent=$(awk -v c=$total_covered -v t=$total_branches \
        'BEGIN { printf("%.2f%%", (c/t)*100) }')
else
    total_percent="N/A"
fi

{
    echo "> **Overall Coverage**: $total_percent"
    echo
} >>"$OUTPUT"

# Start collapsible table
{
    echo "<details>"
    echo "<summary>📁 Full Coverage Table</summary>"
    echo
    echo '| Filename | Funcs | Missed Funcs | Func Cover | Branches | Missed Branches | Branch Cover |'
    echo '|----------|-------|--------------|------------|----------|-----------------|--------------|'
} >>"$OUTPUT"

# Collect rows, sort by branch coverage
rows=()
total_entry=""

while read -r line; do
    [[ -z "$line" ]] && continue

    filename=$(echo "$line" | awk '{print $1}')
    funcs=$(echo "$line" | awk '{print $2}')
    missed_funcs=$(echo "$line" | awk '{print $3}')
    func_cover=$(echo "$line" | awk '{print $4}')
    branches=$(echo "$line" | awk '{print $(NF-2)}')
    missed_branches=$(echo "$line" | awk '{print $(NF-1)}')
    branch_cover=$(echo "$line" | awk '{print $NF}')

    # Extract number (supports “75%” or “75.1”)
    pct=$(echo "$branch_cover" | grep -oE '[0-9]+([.][0-9]+)?' || echo "0")

    # Handle TOTAL cleanly
    if [[ "$filename" == "TOTAL" ]]; then
        total_entry="${filename}|${funcs}|${missed_funcs}|${func_cover}|${branches}|${missed_branches}|${branch_cover}"
        continue
    fi

    rows+=("${pct}|${filename}|${funcs}|${missed_funcs}|${func_cover}|${branches}|${missed_branches}|${branch_cover}")
done <<<"$TABLE_LINES"

# Sorting
if [[ ${#rows[@]} -gt 0 ]]; then
    sorted_rows=$(printf "%s\n" "${rows[@]}" | sort -t '|' -k1,1nr)
else
    sorted_rows=""
fi

# Emit sorted rows
if [[ -n "$sorted_rows" ]]; then
    while IFS='|' read -r pct filename funcs missed_funcs func_cover branches missed_branches branch_cover; do
        [[ -z "$filename" ]] && continue
        echo "| $filename | $funcs | $missed_funcs | $func_cover | $branches | $missed_branches | $branch_cover |" \
            >>"$OUTPUT"
    done <<<"$sorted_rows"
fi

# Emit TOTAL last
if [[ -n "$total_entry" ]]; then
    IFS='|' read -r total_filename total_funcs total_missed_funcs total_func_cover total_branches_row total_missed_branches_row total_branch_cover <<<"$total_entry"

    echo "| **$total_filename** | **$total_funcs** | **$total_missed_funcs** | **$total_func_cover** | **$total_branches_row** | **$total_missed_branches_row** | **$total_branch_cover** |" \
        >>"$OUTPUT"
fi

# Close collapsible + instructions
{
    echo
    echo "</details>"
    echo
    echo "<details>"
    echo "<summary>📝 How to view locally</summary>"
    echo
    echo '```bash'
    echo "make coverage"
    echo "make coverage-show"
    echo '```'
    echo "</details>"
    echo
    echo "_Generated on $(date -u '+%Y-%m-%d %H:%M:%S UTC')_"
} >>"$OUTPUT"
