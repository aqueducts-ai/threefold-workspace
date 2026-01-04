# Philosophy

This document explains the thinking behind LLM Workspace and how to get the most out of it.

## The Problem

Traditional development workflows are serial: write code, test, debug, repeat. When you're blocked on one thing, you context-switch to another task, losing mental state. With AI assistants, this problem is amplified because:

1. **Context windows are expensive**: Rebuilding context in a new session wastes tokens
2. **AI works best with focus**: Narrow context = better suggestions
3. **Parallelism is underutilized**: While AI processes, you wait

## The Solution

Git worktrees + tmux + AI assistants = parallel development without context loss.

```
Traditional:
  Task A → Block → Task B → Back to A (rebuild context) → ...

Parallel:
  Task A ──────────────────────────────────>
       Task B ──────────────────────────────>
            Task C ──────────────────────────>
```

## Core Principles

### 1. Context is King

Each AI session maintains its own context. By running multiple sessions in parallel:
- Each session stays focused on one task
- No need to re-explain background
- AI suggestions are more relevant

**Practical tip**: Start each Claude session with a brief context summary, then keep it focused on that one feature/bug.

### 2. Git Worktrees are Underrated

Worktrees let you have multiple branches checked out simultaneously:

```bash
~/project/           # main branch
~/project-feature/   # feature branch (same repo, different directory)
~/project-bugfix/    # bugfix branch
```

Benefits:
- No stashing required
- Each has its own node_modules state
- Switch tasks by switching panes, not branches

### 3. Visibility Reduces Anxiety

The usage monitor exists because:
- Token limits create artificial scarcity
- Not knowing where you stand creates decision paralysis
- Seeing the numbers helps you pace yourself

When you see "Week: 45% | Session: 20%", you know exactly how much runway you have.

### 4. Keyboard-First, Mouse-Welcome

Every action should be possible via keyboard:
- `prefix + h/j/k/l` for navigation
- `prefix + g` for GitHub PRs
- `Ctrl+Space` for copy mode

But we also enable mouse support because sometimes clicking is faster.

### 5. Extensible by Design

The provider architecture exists because:
- The AI CLI landscape is evolving rapidly
- Different projects may prefer different tools
- One workflow, multiple AI backends

## Workflow Patterns

### Pattern 1: Feature + Bugfix + Review

```
Pane 1: New feature development
Pane 2: Fixing bugs reported by QA
Pane 3: Reviewing teammate's PR
```

### Pattern 2: Frontend + Backend + Infrastructure

```
Pane 1: React component work
Pane 2: API endpoint development
Pane 3: Terraform/deployment changes
```

### Pattern 3: Experiment + Implement + Document

```
Pane 1: Exploring new approach
Pane 2: Implementing proven solution
Pane 3: Writing documentation
```

## Anti-Patterns to Avoid

### Don't: Use AI for everything in one session

If you ask Claude to help with 5 different features in one session, context gets muddled. Split it up.

### Don't: Ignore the monitor

If you're at 80% weekly usage on Monday, adjust your approach. Use cheaper operations, be more specific in prompts.

### Don't: Fight the workflow

If you find yourself constantly switching worktrees within a single pane, you're working against the system. Commit to the parallel model.

## Getting the Most Out of It

1. **Start each day with `ws-fresh`**: Pick your 3 highest-priority tasks
2. **Keep sessions focused**: One feature/bug per pane
3. **Use the CLI panes**: Run tests, builds, git commands there
4. **Watch the monitor**: Adjust behavior based on usage
5. **Commit often**: Each worktree can have its own commit history

## The Bigger Picture

This workflow is about optimizing the human-AI development loop:

```
Human Intent → AI Assistance → Human Review → Commit
     ↑                                          │
     └──────────────────────────────────────────┘
```

By running this loop in parallel across multiple tasks, you multiply your throughput without multiplying your cognitive load.

---

*This workflow emerged from building Threefold, where we process thousands of citizen requests daily. The same principles that help us manage complex workflows apply to managing complex codebases.*
