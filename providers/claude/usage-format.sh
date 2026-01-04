#!/bin/bash
#
# Claude Usage Monitor - Formatting Utilities
# Shared functions for formatting token counts, time, and colors
#

# Format number to K/M suffix
# Usage: format_number 45200 -> "45.2K"
format_number() {
    local num=$1

    if [ -z "$num" ] || [ "$num" = "null" ]; then
        echo "0"
        return
    fi

    local result=$(awk -v n="$num" 'BEGIN {
        if (n >= 1000000) {
            printf "%.1fM", n/1000000
        } else if (n >= 1000) {
            printf "%.1fK", n/1000
        } else {
            printf "%.0f", n
        }
    }')
    echo "$result"
}

# Format seconds to human-readable time
# Usage: format_time 3645 -> "1h 0m"
format_time() {
    local sec=$1

    if [ -z "$sec" ] || [ "$sec" = "null" ] || [ "$sec" -le 0 ]; then
        echo "0m"
        return
    fi

    local h=$((sec / 3600))
    local m=$(((sec % 3600) / 60))

    if [ $h -gt 0 ]; then
        echo "${h}h ${m}m"
    else
        echo "${m}m"
    fi
}

# Format dollars with 2 decimal places
# Usage: format_cost 2.4567 -> "2.46"
format_cost() {
    local cost=$1

    if [ -z "$cost" ] || [ "$cost" = "null" ]; then
        echo "0.00"
        return
    fi

    awk -v c="$cost" 'BEGIN {printf "%.2f", c}'
}

# Get ANSI color code based on percentage
# Usage: get_warning_color 75 -> returns yellow color code
get_warning_color() {
    local pct=$1

    if [ -z "$pct" ]; then
        echo '\033[2m'  # Dim for unknown
        return
    fi

    if [ "$pct" -lt 50 ]; then
        echo '\033[0;32m'  # Green
    elif [ "$pct" -lt 80 ]; then
        echo '\033[1;33m'  # Yellow
    else
        echo '\033[0;31m'  # Red
    fi
}

# Get status emoji based on percentage
# Usage: get_status_emoji 75 -> "[yellow]"
get_status_emoji() {
    local pct=$1

    if [ -z "$pct" ]; then
        echo "[--]"
        return
    fi

    if [ "$pct" -lt 50 ]; then
        echo "[OK]"
    elif [ "$pct" -lt 80 ]; then
        echo "[!!]"
    else
        echo "[XX]"
    fi
}

# Export functions if sourced
export -f format_number
export -f format_time
export -f format_cost
export -f get_warning_color
export -f get_status_emoji
