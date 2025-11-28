#!/usr/bin/env bash
set -euo pipefail

INPUT="build/Debug/coverage/coverage.txt"
OUTPUT="coverage.md"

if [[ ! -f "$INPUT" ]]; then
  echo "Warning: Coverage file not found at $INPUT" >&2
  exit 0
fi

###############################################################################
# Header
###############################################################################
{
  echo "### 📊 Test Coverage Report"
  echo
} > "$OUTPUT"

###############################################################################
# Compute true total branch coverage
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
done <<< "$TABLE_LINES"

if [[ "$total_branches" -gt 0 ]]; then
  total_covered=$((total_branches - total_missed))
  total_percent=$(awk -v c=$total_covered -v t=$total_branches \
    'BEGIN { printf("%.2f%%", (c/t)*100) }')
else
  total_percent="N/A"
fi

{
  echo "> **Overall Coverage**: $total_percent"
  echo
} >> "$OUTPUT"

###############################################################################
# Start collapsible table
###############################################################################
{
  echo "<details>"
  echo "<summary>📁 Full Coverage Table</summary>"
  echo
  echo '| Filename | Funcs | Missed Funcs | Func Cover | Branches | Missed Branches | Branch Cover |'
  echo '|----------|-------|--------------|------------|----------|-----------------|--------------|'
} >> "$OUTPUT"

###############################################################################
# Collect rows, sort by branch coverage
###############################################################################
rows=()

while read -r line; do
  filename=$(echo "$line" | awk '{print $1}')
  funcs=$(echo "$line" | awk '{print $2}')
  missed_funcs=$(echo "$line" | awk '{print $3}')
  func_cover=$(echo "$line" | awk '{print $4}')
  branches=$(echo "$line" | awk '{print $(NF-2)}')
  missed_branches=$(echo "$line" | awk '{print $(NF-1)}')
  branch_cover=$(echo "$line" | awk '{print $NF}')

  pct=$(echo "$branch_cover" | tr -d '%')

  # Store "pct|data…" for sorting
  rows+=( "${pct}|${filename}|${funcs}|${missed_funcs}|${func_cover}|${branches}|${missed_branches}|${branch_cover}" )
done <<< "$TABLE_LINES"

sorted_rows=$(printf "%s\n" "${rows[@]}" | sort -t '|' -k1,1nr)

###############################################################################
# Emit sorted rows
###############################################################################
while IFS='|' read -r pct filename funcs missed_funcs func_cover branches missed_branches branch_cover; do
  if [[ "$filename" == "TOTAL" ]]; then
    echo "| **$filename** | **$funcs** | **$missed_funcs** | **$func_cover** | **$branches** | **$missed_branches** | **$branch_cover** |" \
      >> "$OUTPUT"
  else
    echo "| $filename | $funcs | $missed_funcs | $func_cover | $branches | $missed_branches | $branch_cover |" \
      >> "$OUTPUT"
  fi
done <<< "$sorted_rows"

###############################################################################
# Close collapsible
###############################################################################
{
  echo
  echo "</details>"
  echo
} >> "$OUTPUT"

###############################################################################
# Local instructions
###############################################################################
{
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
} >> "$OUTPUT"
