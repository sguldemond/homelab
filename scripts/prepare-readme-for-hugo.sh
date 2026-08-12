#!/bin/bash

# Generates web/content/homelab.md from README.md.
# The repo README is the source of truth; this adds Hugo front matter, drops
# the leading H1 (the theme renders the title) and fixes image paths.

set -euo pipefail

INPUT_FILE="README.md"
OUTPUT_FILE="web/content/homelab.md"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Warning: $INPUT_FILE not found, skipping..." >&2
    exit 0
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

{
    printf -- '---\ntitle: "homelab"\nShowToc: true\nTocOpen: true\n---\n\n'
    sed -e '1{/^# /d}' \
        -e 's|\./web/static/images/|/images/|g' \
        -e 's|\./images/|/images/|g' \
        -e 's|^\[<img src="\([^"]*/\([^"/]*\)\.[a-z]*\)"[^]]*/>\]()|![\2](\1)|' \
        "$INPUT_FILE" \
      | sed -e '/./,$!d'
} > "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE from $INPUT_FILE"
