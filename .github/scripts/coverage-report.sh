#!/usr/bin/env bash
# Generates a markdown coverage report from cargo-llvm-cov JSON output.
# Usage: ./coverage-report.sh [output-file]
set -euo pipefail

OUTPUT_FILE="${1:-code-coverage-results.md}"

cargo llvm-cov --json --output-path /tmp/coverage.json

python3 -c "
import json, sys

with open('/tmp/coverage.json') as f:
    d = json.load(f)['data'][0]

totals = d['totals']
overall = int(totals['lines']['percent'])
color = 'success' if overall >= 80 else 'yellow' if overall >= 50 else 'critical'

lines = [
    f'![Code Coverage](https://img.shields.io/badge/Code%20Coverage-{overall}%25-{color}?style=flat)',
    '',
    '| File | Line Coverage | Function Coverage | Region Coverage |',
    '|:-----|:-------------|:-----------------|:----------------|',
]

for f in sorted(d['files'], key=lambda x: x['filename']):
    p = f['filename']
    name = p[p.index('src/') + 4:] if 'src/' in p else p.split('/')[-1]
    s = f['summary']
    lp, fp, rp = s['lines']['percent'], s['functions']['percent'], s['regions']['percent']
    lines.append(f'| \`{name}\` | {lp:.0f}% | {fp:.0f}% | {rp:.0f}% |')

tl, tf, tr = totals['lines'], totals['functions'], totals['regions']
lines.append(f'| **Summary** | **{tl[\"percent\"]:.0f}%** ({tl[\"covered\"]}/{tl[\"count\"]}) | **{tf[\"percent\"]:.0f}%** ({tf[\"covered\"]}/{tf[\"count\"]}) | **{tr[\"percent\"]:.0f}%** ({tr[\"covered\"]}/{tr[\"count\"]}) |')

with open('$OUTPUT_FILE', 'w') as out:
    out.write('\n'.join(lines) + '\n')

print(f'Coverage report written to $OUTPUT_FILE')
"
