# LLM Workspace

Multi-pane tmux workflow for parallel AI-assisted development with Claude Code, Gemini CLI, and more.

```
  ╔═══════════════════════════════════════════════════════════════════════╗
  ║                                                                       ║
  ║   ┌─────────────────┬─────────────────┬─────────────────┐            ║
  ║   │   CLAUDE        │   CLAUDE        │   CLAUDE        │            ║
  ║   │   (main)        │   (feature)     │   (bugfix)      │            ║
  ║   │                 │                 │                 │            ║
  ║   ├─────────────────┼─────────────────┼─────────────────┤            ║
  ║   │   CLI           │   CLI           │   CLI           │            ║
  ║   │   (main)        │   (feature)     │   (bugfix)      │            ║
  ║   ├─────────────────┴─────────────────┴─────────────────┤            ║
  ║   │                    USAGE MONITOR                    │            ║
  ║   └─────────────────────────────────────────────────────┘            ║
  ║                                                                       ║
  ╚═══════════════════════════════════════════════════════════════════════╝
```

## Why?

Modern AI coding assistants like Claude Code work best when you can maintain context. Git worktrees let you work on multiple branches simultaneously without stashing. Combined with tmux, you get:

- **Parallel development**: Work on 3 features/bugs at once
- **Context isolation**: Each branch has its own Claude session
- **Real-time monitoring**: Track token usage across sessions
- **Seamless switching**: Click or keyboard to switch between tasks

## Features

- **Multi-pane layout**: 3 LLM + 3 CLI pane pairs with shared monitor
- **Git worktree integration**: Auto-discovers worktrees for easy selection
- **Usage monitoring**: Real-time token/cost tracking for Claude Code
- **Live status indicators**: See which panes are working
- **Cross-platform**: Works on macOS and Linux
- **Extensible**: Provider architecture for multiple LLM CLIs

## Quick Start

### Prerequisites

- tmux
- git
- Node.js (for usage monitoring)
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)

### Install

```bash
# Clone and install
git clone https://github.com/threefold/threefold-workspace.git
cd threefold-workspace
./install.sh

# Apply shell changes
source ~/.zshrc  # or ~/.bashrc

# Start workspace
ws
```

Or one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/threefold/threefold-workspace/main/install.sh | bash
```

### First Run

1. Run `ws-fresh` to select 3 worktrees/directories
2. The workspace opens with Claude Code running in each top pane
3. Bottom panes are CLI for running tests, builds, etc.
4. Monitor pane shows real-time usage stats

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `ws` | Attach to existing workspace or start new |
| `ws-fresh` | Re-select worktrees and start fresh |
| `workspace --help` | Show all options |
| `workspace --list` | List available worktrees |
| `workspace --add /path` | Add custom directory |
| `workspace --provider gemini` | Switch LLM provider |

### Keyboard Shortcuts (tmux)

| Key | Action |
|-----|--------|
| `Ctrl+a` | tmux prefix (instead of Ctrl+b) |
| `prefix + h/j/k/l` | Navigate panes (vim-style) |
| `prefix + |` | Split horizontal |
| `prefix + -` | Split vertical |
| `prefix + g` | Open GitHub PR in browser |
| `prefix + r` | Reload tmux config |
| `Ctrl+Space` | Enter copy mode |

### Git Worktrees

If you're not using git worktrees yet, here's how to get started:

```bash
# In your main repo
git worktree add ../feature-branch feature-branch
git worktree add ../bugfix-branch bugfix-branch

# List worktrees
git worktree list
```

Now `workspace --list` will show all your worktrees.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_WORKSPACE_PROVIDER` | `claude` | Default LLM provider |
| `CLAUDE_COST_LIMIT` | `418` | Weekly cost limit ($) |
| `CLAUDE_SESSION_COST_LIMIT` | `22` | Per-session cost limit ($) |

### Config Files

- `~/.config/llm-workspace/config` - Saved worktree selection
- `~/.config/llm-workspace/provider` - Selected provider
- `~/.config/claude-usage/config.json` - Usage limits (auto-calibrated)

## Claude Code Integration

The workspace includes deep integration with Claude Code:

### Status Line
Shows git branch, status, and PR info directly in Claude's status line.

### Pane Status
Pane borders show "WORKING" when Claude is processing.

### Usage Monitor
Real-time tracking of:
- Weekly usage percentage
- Session usage percentage
- Time remaining in current session
- Cost burn rate

### Setup in Your Project

Copy the Claude settings to enable integrations:

```bash
# From your project root
mkdir -p .claude
cp ~/.llm-workspace/providers/claude/settings.json .claude/
cp ~/.llm-workspace/providers/claude/pane-status.sh .claude/
cp ~/.llm-workspace/providers/claude/statusline-command.sh .claude/
```

## Providers

The workspace is designed to support multiple LLM CLI tools:

### Currently Supported

- **Claude Code** - Full support with usage monitoring

### Planned

- **Gemini CLI** - Coming when Google releases it
- **GitHub Copilot CLI** - Potential future support

### Adding a Provider

See [docs/PROVIDERS.md](docs/PROVIDERS.md) for how to add support for new LLM CLIs.

## Project Structure

```
threefold-workspace/
├── bin/
│   └── workspace           # Main entry point
├── config/
│   └── tmux.conf          # tmux configuration
├── providers/
│   └── claude/            # Claude Code provider
│       ├── settings.json  # Claude Code settings
│       ├── usage-monitor.sh
│       ├── usage-format.sh
│       ├── pane-status.sh
│       └── statusline-command.sh
├── docs/
│   ├── PHILOSOPHY.md
│   ├── CONFIGURATION.md
│   └── PROVIDERS.md
├── install.sh
├── LICENSE
└── README.md
```

## Philosophy

This workflow emerged from our team's experience building [Threefold](https://threefold.ai), an AI-powered workflow platform. Key principles:

1. **Context is king**: AI assistants work better with focused context
2. **Parallel > Serial**: Work on multiple things without context-switching overhead
3. **Visibility**: Always know your usage and status at a glance
4. **Keyboard-first**: Everything accessible without reaching for the mouse
5. **Extensible**: Support multiple AI tools as the ecosystem evolves

See [docs/PHILOSOPHY.md](docs/PHILOSOPHY.md) for more on our development approach.

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Ideas for contribution:
- Add support for new LLM providers
- Improve usage monitoring
- Add new tmux layouts
- Documentation improvements

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Created by the [Threefold](https://threefold.ai) team.

---

**Found this useful?** Star the repo and share with your team!
