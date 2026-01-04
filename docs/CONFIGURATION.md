# Configuration Guide

This document covers all configuration options for LLM Workspace.

## Quick Reference

| Config | Location | Purpose |
|--------|----------|---------|
| Worktree selection | `~/.config/llm-workspace/config` | Saved worktree paths |
| Provider | `~/.config/llm-workspace/provider` | Active LLM provider |
| Custom worktrees | `~/.config/llm-workspace/custom-worktrees` | Additional paths |
| Claude limits | `~/.config/claude-usage/config.json` | Usage limit calibration |
| tmux config | `~/.tmux.conf` | tmux settings |

## Environment Variables

### Workspace Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_WORKSPACE_PROVIDER` | `claude` | Default LLM provider |
| `LLM_WORKSPACE_DIR` | `~/.llm-workspace` | Installation directory |

### Claude-Specific

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_COST_LIMIT` | `418` | Weekly cost limit in USD |
| `CLAUDE_SESSION_COST_LIMIT` | `22` | Per-session cost limit in USD |
| `CLAUDE_SONNET_COST_LIMIT` | `170` | Sonnet model limit in USD |
| `CLAUDE_USAGE_REFRESH` | `3` | Monitor refresh interval (seconds) |

### Setting Environment Variables

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
# Customize workspace
export LLM_WORKSPACE_PROVIDER=claude
export CLAUDE_COST_LIMIT=500
export CLAUDE_SESSION_COST_LIMIT=30
```

## Worktree Configuration

### Automatic Discovery

The workspace automatically discovers git worktrees from your current directory:

```bash
# In any git repo with worktrees
workspace --list
```

### Adding Custom Paths

Add directories that aren't git worktrees:

```bash
# Add a custom path
workspace --add ~/Dev/side-project

# Remove a custom path
workspace --remove ~/Dev/side-project
```

Custom paths are stored in `~/.config/llm-workspace/custom-worktrees`.

### Saving Selection

Your worktree selection is saved after first run. To change:

```bash
# Re-select worktrees
ws-fresh
# or
workspace --reset
```

## tmux Configuration

### Modifying tmux Settings

The workspace installs a tmux config at `~/.tmux.conf`. To customize:

1. Edit `~/.tmux.conf` directly
2. Or add overrides after the main config

### Key Bindings

Default prefix is `Ctrl+a`. To change:

```tmux
# In ~/.tmux.conf
set-option -g prefix C-b
bind-key C-b send-prefix
```

### Colors and Styling

Modify the status bar colors:

```tmux
# In ~/.tmux.conf
set -g status-bg colour236
set -g status-fg colour250
```

### Pane Border Format

Customize what shows in pane borders:

```tmux
# In ~/.tmux.conf
set -g pane-border-format '#{pane_title}'
```

## Claude Code Settings

### Settings File

Create `.claude/settings.json` in your project:

```json
{
  "statusLine": {
    "type": "command",
    "command": ".claude/statusline-command.sh"
  },
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/pane-status.sh"
          }
        ]
      }
    ]
  }
}
```

### Copying Settings to Projects

```bash
# Copy all Claude integration files
cp -r ~/.llm-workspace/providers/claude/* .claude/
```

### Usage Calibration

The usage monitor can auto-calibrate limits from Claude's usage page:

1. Navigate to claude.ai/settings/usage
2. Use the calibration bookmarklet
3. Limits are saved to `~/.config/claude-usage/config.json`

## Layout Configuration

### Pane Arrangement

The default layout is 3 columns (LLM + CLI pairs) + monitor:

```
┌─────────────┬─────────────┬─────────────┐
│   LLM 1     │   LLM 2     │   LLM 3     │
│   (70%)     │   (70%)     │   (70%)     │
├─────────────┼─────────────┼─────────────┤
│   CLI 1     │   CLI 2     │   CLI 3     │
│   (30%)     │   (30%)     │   (30%)     │
├─────────────┴─────────────┴─────────────┤
│              MONITOR (4 lines)          │
└─────────────────────────────────────────┘
```

To modify the layout, edit `create_layout()` in `bin/workspace`.

### Monitor Pane Height

Change the monitor pane height:

```bash
# In bin/workspace, find this line:
tmux split-window -f -v -t "$SESSION_NAME" -c "$wt1" -l 4

# Change -l 4 to desired height
```

## Troubleshooting

### Reset All Configuration

```bash
rm -rf ~/.config/llm-workspace
rm -rf ~/.config/claude-usage
workspace --setup
```

### tmux Config Issues

```bash
# Backup and regenerate
mv ~/.tmux.conf ~/.tmux.conf.old
workspace --setup
```

### Worktree Discovery Issues

```bash
# Check what's being discovered
workspace --list

# Add paths manually if needed
workspace --add /path/to/directory
```

---

*Need help? Open an issue on GitHub.*
