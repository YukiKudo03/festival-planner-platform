#!/bin/bash

# Log cleanup script for Festival Planner Platform
# This script truncates log files that exceed size limits

set -e

LOG_DIR="$(dirname "$0")/../log"
MAX_SIZE_MB=50

echo "🧹 Festival Planner Platform - Log Cleanup"
echo "==========================================="

# Function to check and truncate log file if it exceeds max size
check_and_truncate() {
    local file="$1"
    local max_size_bytes=$((MAX_SIZE_MB * 1024 * 1024))
    
    if [ -f "$file" ]; then
        local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        local file_size_mb=$((file_size / 1024 / 1024))
        
        if [ "$file_size" -gt "$max_size_bytes" ]; then
            echo "📁 $file (${file_size_mb}MB) exceeds ${MAX_SIZE_MB}MB limit - truncating..."
            
            # Backup last 1000 lines before truncating
            tail -n 1000 "$file" > "${file}.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Truncate the file
            truncate -s 0 "$file"
            
            echo "✅ Truncated $file (backup created)"
        else
            echo "✅ $file (${file_size_mb}MB) is within limits"
        fi
    else
        echo "ℹ️  $file does not exist"
    fi
}

# Check common log files
cd "$LOG_DIR"

echo ""
echo "Checking log files in: $(pwd)"
echo ""

check_and_truncate "development.log"
check_and_truncate "test.log"
check_and_truncate "production.log"

# Clean up old test log rotations that are too large
for file in test.log.*; do
    if [ -f "$file" ]; then
        check_and_truncate "$file"
    fi
done

# Clean up old backup files (older than 7 days)
echo ""
echo "🗑️  Cleaning up old backup files (>7 days)..."
find . -name "*.backup.*" -mtime +7 -delete 2>/dev/null || true

echo ""
echo "✨ Log cleanup completed!"
echo ""

# Show current log file sizes
echo "Current log file sizes:"
ls -lh *.log* 2>/dev/null || echo "No log files found"