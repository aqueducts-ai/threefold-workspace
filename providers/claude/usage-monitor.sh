#!/bin/bash
#
# Claude Usage Monitor
# Real-time Claude Code token usage monitoring for tmux
#
# Usage:
#   usage-monitor.sh              # Run continuously (3s refresh)
#   usage-monitor.sh --once       # Run once and exit
#   usage-monitor.sh --interval 5 # Custom refresh interval
#
# Requirements:
#   - Node.js/npm (for ccusage)
#   - jq (for JSON parsing)
#

set -e

# Get script directory and load utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/usage-format.sh"

# Configuration
REFRESH_INTERVAL=${CLAUDE_USAGE_REFRESH:-3}
RUN_ONCE=false
CACHE_FILE="/tmp/claude-usage-cache.json"
LAST_UPDATE=0
WEEKLY_CACHE_FILE="/tmp/claude-weekly-cache.txt"
WEEKLY_TOKENS_CACHE_FILE="/tmp/claude-weekly-tokens-cache.txt"
LAST_WEEKLY_UPDATE=0
LAST_WEEKLY_TOKENS_UPDATE=0
CONFIG_FILE="$HOME/.config/claude-usage/config.json"

# Load limits from config file (with fallbacks)
load_limits() {
    if [ -f "$CONFIG_FILE" ] && command -v jq &> /dev/null; then
        CLAUDE_COST_LIMIT=$(jq -r '.limits.weekly // 418' "$CONFIG_FILE" 2>/dev/null)
        CLAUDE_SESSION_COST_LIMIT=$(jq -r '.limits.session // 22' "$CONFIG_FILE" 2>/dev/null)
        CLAUDE_SONNET_COST_LIMIT=$(jq -r '.limits.sonnet // 170' "$CONFIG_FILE" 2>/dev/null)
    else
        # Fallback defaults
        CLAUDE_COST_LIMIT=${CLAUDE_COST_LIMIT:-418}
        CLAUDE_SESSION_COST_LIMIT=${CLAUDE_SESSION_COST_LIMIT:-22}
        CLAUDE_SONNET_COST_LIMIT=${CLAUDE_SONNET_COST_LIMIT:-170}
    fi
    export CLAUDE_COST_LIMIT CLAUDE_SESSION_COST_LIMIT CLAUDE_SONNET_COST_LIMIT
}

# Load limits on startup
load_limits

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'
BOLD='\033[1m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --once)
            RUN_ONCE=true
            shift
            ;;
        --interval)
            REFRESH_INTERVAL="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: usage-monitor.sh [--once] [--interval SECONDS]"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Check if ccusage is available
check_ccusage() {
    if ! command -v npx &> /dev/null; then
        return 1
    fi
    return 0
}

# Fetch usage data from ccusage
fetch_usage_data() {
    local data

    # Try to fetch current usage
    data=$(npx ccusage@latest blocks --active --json 2>/dev/null)

    if [ -z "$data" ] || [ "$data" = "null" ]; then
        # No active block, try getting most recent
        data=$(npx ccusage@latest blocks --recent --json 2>/dev/null | head -1)
    fi

    if [ -n "$data" ] && [ "$data" != "null" ]; then
        echo "$data" > "$CACHE_FILE"
        LAST_UPDATE=$(date +%s)
        echo "$data"
    elif [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
    else
        echo ""
    fi
}

# Parse and display usage data
display_usage() {
    local data="$1"
    local weekly_info="${2:-0|0|0}"

    if [ -z "$data" ]; then
        echo -e "${DIM}Start using Claude Code to see token usage data.${NC}"
        return
    fi

    # Parse weekly info
    IFS='|' read -r weekly_cost pct tokens <<< "$weekly_info"

    local limit burn_rate time_remaining cost

    if command -v jq &> /dev/null; then
        local session_input=$(echo "$data" | jq -r '.blocks[0].tokenCounts.inputTokens // 0')
        local session_output=$(echo "$data" | jq -r '.blocks[0].tokenCounts.outputTokens // 0')
        local session_tokens=$((session_input + session_output))

        local block_cost=$(echo "$data" | jq -r '.blocks[0].costUSD // 0')
        local session_baseline=0
        if [ -f "/tmp/claude-session-baseline-cost.txt" ]; then
            session_baseline=$(cat /tmp/claude-session-baseline-cost.txt 2>/dev/null || echo "0")
        fi
        cost=$(awk -v block="$block_cost" -v baseline="$session_baseline" 'BEGIN {printf "%.4f", block - baseline}')

        local session_cost_limit=${CLAUDE_SESSION_COST_LIMIT:-22.38}
        burn_rate=$(echo "$data" | jq -r '.blocks[0].burnRate.tokensPerMinuteForIndicator // 0')
        cost_per_hour=$(echo "$data" | jq -r '.blocks[0].burnRate.costPerHour // 0')

        if [ -f "/tmp/claude-session-reset-time.txt" ]; then
            local reset_timestamp=$(cat /tmp/claude-session-reset-time.txt 2>/dev/null || echo "0")
            local current_timestamp=$(date +%s)000
            local remaining_ms=$((reset_timestamp - current_timestamp))
            if [ "$remaining_ms" -gt 0 ]; then
                time_remaining=$((remaining_ms / 1000))
            else
                time_remaining=$(echo "$data" | jq -r '.blocks[0].projection.remainingMinutes // 0')
                time_remaining=$((time_remaining * 60))
            fi
        else
            time_remaining=$(echo "$data" | jq -r '.blocks[0].projection.remainingMinutes // 0')
            time_remaining=$((time_remaining * 60))
        fi
    else
        local session_tokens=$(echo "$data" | grep -o '"totalTokens":[0-9]*' | head -1 | cut -d: -f2)
        burn_rate=$(echo "$data" | grep -o '"tokensPerMinuteForIndicator":[0-9.]*' | head -1 | cut -d: -f2)
        time_remaining=$(echo "$data" | grep -o '"remainingMinutes":[0-9]*' | head -1 | cut -d: -f2)
        time_remaining=$((time_remaining * 60))
        cost=$(echo "$data" | grep -o '"costUSD":[0-9.]*' | head -1 | cut -d: -f2)
        local session_cost_limit=22.38

        session_tokens=${session_tokens:-0}
        burn_rate=${burn_rate:-0}
        time_remaining=${time_remaining:-0}
        cost=${cost:-0}
    fi

    # Calculate session percentage
    local conv_pct=0
    if [ -n "$cost" ] && [ "${cost%.*}" -gt 0 ] && [ "${session_cost_limit%.*}" -gt 0 ]; then
        conv_pct=$(awk -v c="$cost" -v l="$session_cost_limit" 'BEGIN {printf "%.0f", (c/l)*100}')
    fi

    # Format values
    local time_fmt=$(format_time "$time_remaining")

    # Get color and emoji based on percentage
    local color=$(get_warning_color "$pct")
    local emoji=$(get_status_emoji "$pct")

    local critical_pct=${pct:-0}
    if [ "${conv_pct:-0}" -gt "${pct:-0}" ]; then
        critical_pct=$conv_pct
    fi
    local critical_color=$(get_warning_color "$critical_pct")
    local critical_emoji=$(get_status_emoji "$critical_pct")

    # Spinner for refresh indicator
    local spinner_chars="-\\|/"
    local spinner_index=$(($(date +%s) % 4))
    local spinner_char="${spinner_chars:$spinner_index:1}"

    # Display line
    echo -e "${critical_emoji} ${critical_color}Week: ${pct}% | Session: ${conv_pct}%${NC} | Time left: ${time_fmt} | ${DIM}${spinner_char}${NC}"
}

# Get current week usage info
get_weekly_usage_info() {
    local now=$(date +%s)
    local age=$((now - LAST_WEEKLY_TOKENS_UPDATE))

    if [ -f "$WEEKLY_TOKENS_CACHE_FILE" ] && [ $age -lt 60 ]; then
        cat "$WEEKLY_TOKENS_CACHE_FILE"
        return
    fi

    local weekly_data=$(npx ccusage@latest weekly --json 2>/dev/null | jq -r '.weekly[-1] // empty' 2>/dev/null)
    if [ -n "$weekly_data" ]; then
        local weekly_cost=$(echo "$weekly_data" | jq -r '.totalCost // 0' 2>/dev/null)
        local cost_limit=${CLAUDE_COST_LIMIT:-418}
        local cost_pct=0
        if [ "${cost_limit:-0}" -gt 0 ]; then
            cost_pct=$(awk -v c="$weekly_cost" -v l="$cost_limit" 'BEGIN {printf "%.0f", (c/l)*100}')
        fi

        local weekly_input=$(echo "$weekly_data" | jq -r '.inputTokens // 0' 2>/dev/null)
        local weekly_output=$(echo "$weekly_data" | jq -r '.outputTokens // 0' 2>/dev/null)
        local display_tokens=$((weekly_input + weekly_output))

        local result="$weekly_cost|$cost_pct|$display_tokens"
        echo "$result" > "$WEEKLY_TOKENS_CACHE_FILE"
        LAST_WEEKLY_TOKENS_UPDATE=$now
        echo "$result"
    else
        echo "0|0|0"
    fi
}

# Render dashboard
render_dashboard() {
    if ! check_ccusage; then
        tput cup 0 0 2>/dev/null || printf '\033[H'
        tput ed 2>/dev/null || printf '\033[J'
        echo -e "${YELLOW}npm/npx not found. Install Node.js for usage monitoring.${NC}"
        return
    fi

    local data=$(fetch_usage_data)
    local weekly_info=$(get_weekly_usage_info)

    # Clear and render
    tput cup 0 0 2>/dev/null || printf '\033[H'
    tput ed 2>/dev/null || printf '\033[J'

    display_usage "$data" "$weekly_info"
}

# Main loop
main() {
    if [ "$RUN_ONCE" = true ]; then
        render_dashboard
        exit 0
    fi

    # Hide cursor
    tput civis 2>/dev/null || true

    # Restore cursor on exit
    trap 'tput cnorm 2>/dev/null; exit' INT TERM EXIT

    while true; do
        render_dashboard
        sleep "$REFRESH_INTERVAL"
    done
}

main
