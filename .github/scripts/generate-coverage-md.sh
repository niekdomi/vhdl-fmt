#!/usr/bin/env bash
set -euo pipefail

INPUT="build/Debug/coverage/coverage.txt"
OUTPUT="coverage.md"

if [[ ! -f "$INPUT" ]]; then
    echo "Warning: Coverage file not found at $INPUT" >&2
    exit 0
fi

echo "### 📊 Test Coverage Report" >"$OUTPUT"
echo "" >>"$OUTPUT"

###############################################################################
# Compute true total branch coverage = (branches - missed) / branches
###############################################################################

TABLE_LINES=$(grep -E '^\S' "$INPUT" | grep -v -E '^-{5,}|Filename')

total_branches=0
total_missed=0

while read -r line; do
    branches=$(echo "$line" | awk '{print $(NF-2)}')
    missed=$(echo "$line" | awk '{print $(NF-1)}')

    if [[ "$branches" =~ ^[0-9]+$ ]]; then
        total_branches=$((total_branches + branches))
        total_missed=$((total_missed + missed))
    fi
done <<<"$TABLE_LINES"

if [[ "$total_branches" -gt 0 ]]; then
    total_covered=$((total_branches - total_missed))
    total_percent=$(awk -v c=$total_covered -v t=$total_branches 'BEGIN { printf("%.2f%%", (c/t)*100) }')
else
    total_percent="N/A"
fi

echo "> **Overall Coverage**: $total_percent" >>"$OUTPUT"
echo "" >>"$OUTPUT"

###############################################################################
# Collapsible table
###############################################################################

echo "<details>" >>"$OUTPUT"
echo "<summary>📁 Full Coverage Table</summary>" >>"$OUTPUT"
echo "" >>"$OUTPUT"

# Markdown header with only function + branch metrics
echo '| Filename | Funcs | Missed Funcs | Func Cover | Branches | Missed Branches | Branch Cover |' >>"$OUTPUT"
echo '|----------|-------|--------------|------------|----------|-----------------|--------------|' >>"$OUTPUT"

while read -r line; do
    filename=$(echo "$line" | awk '{print $1}')
    funcs=$(echo "$line" | awk '{print $2}')
    missed_funcs=$(echo "$line" | awk '{print $3}')
    func_cover=$(echo "$line" | awk '{print $4}')
    branches=$(echo "$line" | awk '{print $(NF-2)}')
    missed_branches=$(echo "$line" | awk '{print $(NF-1)}')
    branch_cover=$(echo "$line" | awk '{print $NF}')

    echo "| $filename | $funcs | $missed_funcs | $func_cover | $branches | $missed_branches | $branch_cover |" >>"$OUTPUT"
done <<<"$TABLE_LINES"

echo "" >>"$OUTPUT"
echo "</details>" >>"$OUTPUT"
echo "" >>"$OUTPUT"

###############################################################################
# Local instructions
###############################################################################

echo "_Generated on $(date -u '+%Y-%m-%d %H:%M:%S UTC')_" >>"$OUTPUT"
echo "" >>"$OUTPUT"

echo "<details>" >>"$OUTPUT"
echo "<summary>📝 How to view locally</summary>" >>"$OUTPUT"
echo "" >>"$OUTPUT"
echo '```bash' >>"$OUTPUT"
echo "make coverage" >>"$OUTPUT"
echo "make coverage-show" >>"$OUTPUT"
echo '```' >>"$OUTPUT"
echo "</details>" >>"$OUTPUT"
