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

# Copy README.md to docs/index.md and update the title and image paths
# Replace the first H1 heading with a cleaner title
# Fix image paths: ./docs/images/ -> ./images/ (since we're now in docs/)
sed -e "1s/^#.*/$NEW_TITLE/" \
    -e 's|\./docs/images/|./images/|g' \
    "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Copied $INPUT_FILE to $OUTPUT_FILE for mkdocs (title and image paths updated)"

