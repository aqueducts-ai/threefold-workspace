# LLM Providers

LLM Workspace supports multiple AI CLI tools through a provider architecture. This document explains how providers work and how to add new ones.

## Supported Providers

### Claude Code (Anthropic)

**Status**: Full support

Claude Code is an AI coding assistant from Anthropic that runs in your terminal.

**Features**:
- Usage monitoring (weekly/session limits)
- Pane status indicators
- Git-aware status line
- PR integration

**Installation**:
```bash
npm install -g @anthropic-ai/claude-code
```

**Provider files**:
- `providers/claude/settings.json` - Hook configuration
- `providers/claude/usage-monitor.sh` - Real-time usage tracking
- `providers/claude/pane-status.sh` - WORKING indicator
- `providers/claude/statusline-command.sh` - Git/PR status

### Gemini CLI (Google)

**Status**: Planned

Support for Google's Gemini CLI will be added when available.

### GitHub Copilot CLI

**Status**: Considering

May be added if there's community interest.

## Provider Architecture

Each provider lives in `providers/<name>/` and can include:

```
providers/
└── <provider-name>/
    ├── settings.json       # CLI-specific settings
    ├── usage-monitor.sh    # Usage tracking (optional)
    ├── pane-status.sh      # Status hooks (optional)
    └── statusline-command.sh  # Status line (optional)
```

## Adding a New Provider

### Step 1: Create Provider Directory

```bash
mkdir -p providers/my-llm
```

### Step 2: Update bin/workspace

Add your provider to the `get_llm_command()` function:

```bash
get_llm_command() {
    case "$PROVIDER" in
        claude)
            echo "claude"
            ;;
        my-llm)
            echo "my-llm-cli"  # The actual CLI command
            ;;
        *)
            echo "claude"
            ;;
    esac
}
```

### Step 3: Add Settings (Optional)

If your LLM CLI supports a settings file, create `providers/my-llm/settings.json`:

```json
{
  "hooks": {
    "onStart": "...",
    "onComplete": "..."
  }
}
```

Update `sync_provider_settings()` in `bin/workspace` to copy these to the right location.

### Step 4: Add Usage Monitor (Optional)

If your LLM has usage limits, create `providers/my-llm/usage-monitor.sh`:

```bash
#!/bin/bash
# Monitor usage for my-llm

while true; do
    # Fetch and display usage
    echo "Usage: XX%"
    sleep 3
done
```

### Step 5: Add Status Hooks (Optional)

Create `providers/my-llm/pane-status.sh` to update tmux pane status:

```bash
#!/bin/bash
# Update tmux pane status based on LLM activity

if [ -n "$TMUX" ]; then
    tmux set-option -p @llm_status "WORKING"
fi
```

### Step 6: Document

Add documentation to this file and update the README.

## Provider Interface Contract

### Required

1. **CLI command**: The provider must have a CLI command that can be run in a terminal

### Optional

2. **Usage monitoring**: Track and display usage limits
3. **Status hooks**: Update tmux pane status based on activity
4. **Settings file**: Provider-specific configuration
5. **Status line**: Custom status line content

## Testing a Provider

1. Create the provider files
2. Run `workspace --provider my-llm`
3. Verify:
   - LLM starts in each pane
   - Monitor displays (or shows placeholder if no monitoring)
   - Status indicators work (if implemented)

## Provider Configuration

Users can set their preferred provider:

```bash
# One-time
workspace --provider my-llm

# Permanent (in shell config)
export LLM_WORKSPACE_PROVIDER=my-llm
```

The selection is saved in `~/.config/llm-workspace/provider`.

## Contributing Providers

We welcome contributions of new providers! Please:

1. Follow the architecture above
2. Test on both macOS and Linux
3. Include documentation
4. Submit a PR with a clear description

---

*Have a suggestion for a new provider? Open an issue!*
