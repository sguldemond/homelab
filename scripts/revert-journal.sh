#!/bin/bash

# Script to revert JOURNAL.md by reversing sections delimited by "---"
# Output saved to docs/journal.md

INPUT_FILE="JOURNAL.md"
OUTPUT_FILE="docs/journal.md"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found" >&2
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Use awk to split by "---" delimiter and reverse sections
awk '
BEGIN {
    RS = "\n---\n"
    section_count = 0
}
{
    # Store each section, trimming leading/trailing whitespace
    gsub(/^[ \t\n\r]+|[ \t\n\r]+$/, "", $0)
    if (length($0) > 0 || section_count == 0) {
        sections[section_count++] = $0
    }
}
END {
    # Check if first section is a header (starts with "# Journal")
    start_idx = 0
    if (section_count > 0 && sections[0] ~ /^# Journal/) {
        # Print header
        print sections[0]
        print ""
        print "---"
        print ""
        start_idx = 1
    }
    
    # Print sections in reverse order
    for (i = section_count - 1; i >= start_idx; i--) {
        if (i < section_count - 1) {
            print ""
            print "---"
            print ""
        }
        print sections[i]
    }
}' "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Reversed journal saved to $OUTPUT_FILE"
