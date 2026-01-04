<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg" alt="Platform">
  <img src="https://img.shields.io/badge/tmux-required-green.svg" alt="tmux">
</p>

<h1 align="center">LLM Workspace</h1>

<p align="center">
  <strong>Multi-pane tmux workflow for parallel AI-assisted development</strong>
</p>

<p align="center">
  Run multiple Claude Code (or other LLM CLI) sessions side-by-side,<br>
  each with its own git worktree and dedicated terminal.
</p>

---

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   ┌───────────────────┬───────────────────┬───────────────────┐            │
│   │                   │                   │                   │            │
│   │   CLAUDE          │   CLAUDE          │   CLAUDE          │            │
│   │   feature/auth    │   fix/api-bug     │   main            │            │
│   │                   │                   │                   │            │
│   │   "Add OAuth..."  │   "Fix the 500"   │   "Review PR..."  │            │
│   │                   │                   │                   │            │
│   ├───────────────────┼───────────────────┼───────────────────┤            │
│   │ $ npm test        │ $ git status      │ $ npm run build   │            │
│   │ ✓ 42 passed       │ M  src/api.ts     │ ✓ Build complete  │            │
│   └───────────────────┴───────────────────┴───────────────────┘            │
│   ┌─────────────────────────────────────────────────────────────┐          │
│   │  [OK] Week: 34% | Session: 12% | Time left: 4h 23m          │          │
│   └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Why?

| Problem | Solution |
|---------|----------|
| Context-switching between tasks kills productivity | **Parallel panes** - work on 3 things at once |
| AI assistants lose context when you switch branches | **Git worktrees** - each branch stays checked out |
| No visibility into token usage | **Live monitor** - see weekly/session limits in real-time |
| Rebuilding AI context wastes tokens | **Isolated sessions** - each pane keeps its own context |

---

## Features

| Feature | Description |
|---------|-------------|
| **3-Column Layout** | LLM + CLI pane pairs for each worktree |
| **Git Worktree Integration** | Auto-discovers and lists your worktrees |
| **Usage Monitoring** | Real-time token/cost tracking (Claude) |
| **Status Indicators** | See "WORKING" when AI is processing |
| **Clickable Links** | PR numbers and URLs are clickable |
| **Cross-Platform** | macOS and Linux support |
| **Provider Architecture** | Extensible for Claude, Gemini, etc. |

---

## Requirements

### Required

| Dependency | Why |
|------------|-----|
| **tmux** | Terminal multiplexer for pane management |
| **git** | Version control and worktree support |
| **Node.js** | For usage monitoring (`npx ccusage`) |
| **Claude Code** | AI coding assistant (`npm i -g @anthropic-ai/claude-code`) |

### Recommended

| Dependency | Why |
|------------|-----|
| **jq** | Better JSON parsing in scripts |
| **gh** | GitHub CLI for PR integration |

### Terminal (for full features)

Clickable links and rich formatting work best in modern terminals:

| Terminal | Support |
|----------|---------|
| **iTerm2** (macOS) | Full support - recommended |
| **Kitty** | Full support |
| **Windows Terminal** | Full support |
| **VS Code Terminal** | Full support |
| **Alacritty** | Partial (recent versions) |
| **GNOME Terminal** | Partial (recent versions) |
| **macOS Terminal.app** | Basic (no clickable links) |

> **Note**: The workspace works in any terminal, but clickable PR links and some formatting require OSC 8 support.

---

## Installation

### Quick Install

```bash
git clone https://github.com/threefold/threefold-workspace.git ~/.llm-workspace
cd ~/.llm-workspace
./install.sh
```

### Then

```bash
source ~/.zshrc    # or ~/.bashrc

ws                 # Start workspace
```

---

## Usage

### Commands

```bash
ws                      # Attach to existing or start new workspace
ws-fresh                # Re-select worktrees and start fresh
workspace --list        # Show available worktrees
workspace --add ~/path  # Add custom directory
workspace --help        # All options
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+a` | tmux prefix |
| `prefix` `h` `j` `k` `l` | Navigate panes (vim-style) |
| `prefix` `\|` | Split horizontal |
| `prefix` `-` | Split vertical |
| `prefix` `g` | Open GitHub PR in browser |
| `prefix` `r` | Reload tmux config |
| `Ctrl+Space` | Enter copy mode |
| `Mouse` | Click to select pane, scroll, select text |

---

## Git Worktrees 101

If you're new to git worktrees:

```bash
# In your main repo, create worktrees for branches
git worktree add ../my-project-feature feature-branch
git worktree add ../my-project-bugfix  bugfix-branch

# Now you have:
# ~/Dev/my-project/           ← main branch
# ~/Dev/my-project-feature/   ← feature-branch (separate directory!)
# ~/Dev/my-project-bugfix/    ← bugfix-branch

# List all worktrees
git worktree list
```

**Why worktrees?**
- No more `git stash` when switching tasks
- Each worktree has its own `node_modules`, build cache, etc.
- Work on multiple branches truly in parallel

---

## Configuration

### Environment Variables

```bash
# Add to ~/.zshrc or ~/.bashrc

export LLM_WORKSPACE_PROVIDER=claude    # Default provider
export CLAUDE_COST_LIMIT=500            # Weekly limit ($)
export CLAUDE_SESSION_COST_LIMIT=25     # Per-session limit ($)
```

### Config Files

| File | Purpose |
|------|---------|
| `~/.config/llm-workspace/config` | Saved worktree selection |
| `~/.config/llm-workspace/provider` | Active provider |
| `~/.config/claude-usage/config.json` | Calibrated usage limits |
| `~/.tmux.conf` | tmux configuration |

See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for all options.

---

## Claude Code Integration

### Enable in Your Project

```bash
# Copy integration files to your project
mkdir -p .claude
cp ~/.llm-workspace/providers/claude/settings.json .claude/
cp ~/.llm-workspace/providers/claude/pane-status.sh .claude/
cp ~/.llm-workspace/providers/claude/statusline-command.sh .claude/
```

### What You Get

| Feature | Description |
|---------|-------------|
| **Status Line** | Shows `directory git:(branch) [status] pr:#123 [CI]` |
| **Pane Status** | Border shows "WORKING" when Claude is processing |
| **Usage Monitor** | Bottom pane tracks weekly/session token usage |

---

## Providers

### Currently Supported

- **Claude Code** - Full support with usage monitoring

### Planned

- **Gemini CLI** - When available
- **GitHub Copilot CLI** - Community interest

### Adding a Provider

See [docs/PROVIDERS.md](docs/PROVIDERS.md) for the provider interface.

---

## Project Structure

```
~/.llm-workspace/
├── bin/workspace           # Main script
├── config/tmux.conf        # tmux configuration
├── providers/
│   └── claude/             # Claude Code integration
│       ├── settings.json
│       ├── usage-monitor.sh
│       ├── usage-format.sh
│       ├── pane-status.sh
│       └── statusline-command.sh
├── docs/
│   ├── PHILOSOPHY.md       # Why this workflow
│   ├── CONFIGURATION.md    # All config options
│   └── PROVIDERS.md        # Adding new providers
├── install.sh
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

---

## Philosophy

> **Context is king. Parallelism beats serialization. Visibility reduces anxiety.**

This workflow emerged from building [Threefold](https://threefold.ai), where we manage complex citizen request workflows. The same principles apply to managing complex codebases:

1. **Focused context** → Better AI suggestions
2. **Parallel execution** → Higher throughput
3. **Real-time visibility** → Better decisions

Read more: [docs/PHILOSOPHY.md](docs/PHILOSOPHY.md)

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md).

**Ideas:**
- New LLM providers
- Additional layouts (2-pane, 4-pane)
- Better Linux support
- Documentation improvements

---

## License

MIT License - see [LICENSE](LICENSE)

---

<p align="center">
  <strong>Built by the <a href="https://threefold.ai">Threefold</a> team</strong>
</p>

<p align="center">
  <sub>If this helps your workflow, give it a ⭐</sub>
</p>
