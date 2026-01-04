#!/bin/bash
#
# Claude Code Pane Status Hook
# Updates tmux pane status indicator based on Claude Code activity
#
# Copy to: .claude/pane-status.sh in your project
# Referenced by: .claude/settings.json hooks
#
# Sets a tmux user option @llm_status which is displayed in pane borders

# Get the event type from the hook input (passed via stdin as JSON)
INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "unknown"' 2>/dev/null)

# Check if we're in a tmux session
if [ -z "$TMUX" ]; then
    exit 0
fi

# Use TMUX_PANE to target the correct pane
PANE_ID="${TMUX_PANE}"
if [ -z "$PANE_ID" ]; then
    exit 0
fi

case "$EVENT" in
    "UserPromptSubmit"|"PostToolUse"|"PreToolUse")
        # Claude is working - set status indicator
        tmux set-option -p -t "$PANE_ID" @llm_status "* WORKING" 2>/dev/null
        ;;
    "SessionStart"|"Stop"|"SessionEnd")
        # Claude is idle - clear status
        tmux set-option -p -t "$PANE_ID" @llm_status "" 2>/dev/null
        ;;
    *)
        # Unknown event, don't change anything
        ;;
esac

exit 0
