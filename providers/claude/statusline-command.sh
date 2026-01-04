#!/bin/bash
#
# Claude Code Statusline Command
# Shows git branch, status, and PR info in Claude Code's status line
#
# Copy to: .claude/statusline-command.sh in your project
# Referenced by: .claude/settings.json statusLine configuration
#
# Output format: directory git:(branch) git:status pr:#123 status

# Read JSON input from Claude Code
input=$(cat)

# Extract current directory from JSON
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')

# Get base directory name
dir_name=$(basename "$current_dir")

# Get git branch and status
cd "$current_dir" 2>/dev/null
git_info=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -c core.fileMode=false -c core.preloadIndex=true symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        # Check working directory status
        has_uncommitted=false
        if ! git -c core.fileMode=false diff --quiet 2>/dev/null || \
           ! git -c core.fileMode=false diff --cached --quiet 2>/dev/null || \
           [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
            has_uncommitted=true
        fi

        # Check for unpushed commits
        has_unpushed=false
        upstream=$(git -c core.fileMode=false rev-parse --abbrev-ref @{upstream} 2>/dev/null)
        if [ -n "$upstream" ]; then
            local_commits=$(git -c core.fileMode=false rev-list --count @{upstream}..HEAD 2>/dev/null)
            if [ -n "$local_commits" ] && [ "$local_commits" -gt 0 ]; then
                has_unpushed=true
            fi
        fi

        # Status indicators
        if [ "$has_uncommitted" = true ] && [ "$has_unpushed" = true ]; then
            status_indicators=" [uncommitted+unpushed]"
        elif [ "$has_uncommitted" = true ]; then
            status_indicators=" [uncommitted]"
        elif [ "$has_unpushed" = true ]; then
            status_indicators=" [unpushed]"
        else
            status_indicators=" [clean]"
        fi

        git_info=" git:(${branch})${status_indicators}"
    fi
fi

# Get PR info if gh CLI is available and a PR exists
pr_info=""
if [ -n "$branch" ] && command -v gh &> /dev/null; then
    pr_data=$(gh pr view --json number,state,isDraft,statusCheckRollup,reviewDecision,url 2>/dev/null)
    if [ -n "$pr_data" ]; then
        pr_number=$(echo "$pr_data" | jq -r '.number')
        pr_state=$(echo "$pr_data" | jq -r '.state')
        pr_is_draft=$(echo "$pr_data" | jq -r '.isDraft')
        pr_review=$(echo "$pr_data" | jq -r '.reviewDecision // empty')

        # Get CI status
        ci_status="none"
        check_count=$(echo "$pr_data" | jq '.statusCheckRollup | length')
        if [ "$check_count" != "0" ] && [ "$check_count" != "null" ]; then
            has_failure=$(echo "$pr_data" | jq '[.statusCheckRollup[]? | select(.conclusion == "FAILURE" or .conclusion == "ERROR" or .state == "FAILURE" or .state == "ERROR")] | length')
            has_pending=$(echo "$pr_data" | jq '[.statusCheckRollup[]? | select(.status == "IN_PROGRESS" or .status == "QUEUED" or .status == "PENDING" or (.status == "COMPLETED" and .conclusion == null) or .state == "PENDING")] | length')
            has_success=$(echo "$pr_data" | jq '[.statusCheckRollup[]? | select(.conclusion == "SUCCESS" or .state == "SUCCESS")] | length')

            if [ "$has_failure" != "0" ] && [ "$has_failure" != "null" ]; then
                ci_status="failed"
            elif [ "$has_pending" != "0" ] && [ "$has_pending" != "null" ]; then
                ci_status="pending"
            elif [ "$has_success" != "0" ] && [ "$has_success" != "null" ]; then
                ci_status="passed"
            fi
        fi

        # Determine status text
        if [ "$pr_state" = "MERGED" ]; then
            status_text="merged"
        elif [ "$pr_state" = "CLOSED" ]; then
            status_text="closed"
        elif [ "$pr_is_draft" = "true" ]; then
            status_text="draft"
        elif [ "$ci_status" = "failed" ]; then
            status_text="CI-failed"
        elif [ "$ci_status" = "pending" ]; then
            status_text="CI-pending"
        elif [ "$pr_review" = "APPROVED" ]; then
            status_text="approved"
        elif [ "$pr_review" = "CHANGES_REQUESTED" ]; then
            status_text="changes-requested"
        elif [ "$ci_status" = "passed" ]; then
            status_text="CI-passed"
        else
            status_text="open"
        fi

        pr_info=" pr:#${pr_number} [${status_text}]"
    fi
fi

# Output the statusline
printf "%s%s%s" "$dir_name" "$git_info" "$pr_info"
