#!/bin/bash

# Script to extract Ingress host values from YAML files
# Usage: ./update-hosts.sh
# Output: Host entries that can be appended to /etc/hosts

# Configuration
CONTROL_NODE_IP="192.168.1.100"
HOMELAB_DIR="/home/stan/Development/DevOps/homelab"

# Function to extract hosts from YAML files
extract_hosts() {
    local hosts=()
    
    # Find all YAML files in the homelab directory
    find "$HOMELAB_DIR" -name "*.yaml" -o -name "*.yml" | while read -r file; do
        if [[ -f "$file" ]]; then
            # Extract hosts using grep/sed (simple and reliable)
            grep -A 20 "kind: Ingress" "$file" | grep -E "^\s*-\s*host:" | sed 's/.*host:\s*//' | tr -d ' ' | grep -v '^$'
        fi
    done | sort -u
}

# Main function
main() {
    echo "# Update /etc/hosts with the following hosts:"
    # Extract and display hosts
    local hosts
    mapfile -t hosts < <(extract_hosts)
    
    if [[ ${#hosts[@]} -eq 0 ]]; then
        echo "# No Ingress hosts found in YAML files"
        exit 0
    fi
    
    for host in "${hosts[@]}"; do
        echo "$CONTROL_NODE_IP $host"
    done
}

# Run main function
main "$@"
