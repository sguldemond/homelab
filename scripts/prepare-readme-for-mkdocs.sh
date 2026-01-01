#!/bin/bash

# Script to copy README.md to docs/index.md for mkdocs-terminal
# mkdocs expects the homepage to be named index.md
# Also updates the title to be more readable for terminal theme

INPUT_FILE="README.md"
OUTPUT_FILE="docs/index.md"
NEW_TITLE="# Homelab"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Warning: $INPUT_FILE not found, skipping..." >&2
    exit 0  # Don't fail if README.md doesn't exist
fi

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Remove symlink if it exists (to replace with actual file)
if [ -L "$OUTPUT_FILE" ]; then
    rm "$OUTPUT_FILE"
fi

# Copy README.md to docs/index.md and update the title
# Replace the first H1 heading with a cleaner title
sed "1s/^#.*/$NEW_TITLE/" "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Copied $INPUT_FILE to $OUTPUT_FILE for mkdocs (title updated to: $NEW_TITLE)"

