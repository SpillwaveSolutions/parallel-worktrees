# Parallel Worktrees Skill

Run multiple Claude Code agents simultaneously across git worktrees—transform a single developer into a team of AI engineers.

## Overview

This skill enables parallel AI-assisted development by combining **git worktrees** (isolated working directories sharing a single `.git` database) with **Claude Code agents** (independent Claude sessions or background Task agents). It exploits LLM non-determinism as a feature: running N parallel agents gives you N valid solutions to choose from.

**Two modes of operation:**
1. **Interactive Parallel**: Multiple terminal sessions with Claude in separate worktrees
2. **Background Orchestration**: Main agent delegates to background agents in worktrees, continues working, syncs results when complete

## Installation

This skill is installed at `~/.claude/skills/parallel-worktrees/`. Claude Code automatically loads it when triggered by keywords like:
- "parallel agents" / "background agents"
- "worktrees" / "agent coordination"
- "subagents" / "parallel tasks"
- "async Claude" / "spawn agents"
- "parallel development" / "multi-agent workflow"

## Quick Start

### 1. Create Parallel Worktrees

```bash
# Create 3 worktrees for a feature
./scripts/spawn-parallel.sh user-dashboard 3

# Output:
#   cd .worktrees/user-dashboard-1 && claude
#   cd .worktrees/user-dashboard-2 && claude
#   cd .worktrees/user-dashboard-3 && claude
```

### 2. Start Claude in Each

Open separate terminals and run Claude in each worktree:

```bash
# Terminal 1
cd .worktrees/user-dashboard-1 && claude

# Terminal 2
cd .worktrees/user-dashboard-2 && claude

# Terminal 3
cd .worktrees/user-dashboard-3 && claude
```

### 3. Give Identical Instructions

In each session, provide the same prompt. Each Claude instance works independently with its own context window.

### 4. Compare and Merge

```bash
# Compare implementations
cd .worktrees/user-dashboard-1 && git diff main
cd .worktrees/user-dashboard-2 && git diff main

# Merge the winner
git checkout main
git merge user-dashboard-2
```

### 5. Clean Up

```bash
./scripts/cleanup-worktrees.sh user-dashboard --delete-branches
```

## Scripts

### `spawn-parallel.sh`

Creates parallel git worktrees for multi-agent development.

```bash
./scripts/spawn-parallel.sh <feature-name> [num-agents] [base-branch]
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `feature-name` | Name for the feature (used in branch names) | Required |
| `num-agents` | Number of parallel worktrees | 3 |
| `base-branch` | Branch to base worktrees on | main |

**Example:**
```bash
./scripts/spawn-parallel.sh auth-refactor 4 develop
```

### `cleanup-worktrees.sh`

Removes parallel worktrees and optionally their branches.

```bash
./scripts/cleanup-worktrees.sh <feature-name> [--delete-branches]
```

- Detects uncommitted changes and prompts before force-removing
- Prunes stale worktree metadata
- Shows remaining worktrees when done

### `sync-worktrees.sh`

Reviews and merges completed worktree work back to main.

```bash
./scripts/sync-worktrees.sh [--status|--merge|--interactive]
```

| Option | Description |
|--------|-------------|
| `--status`, `-s` | Show status of all worktrees and agents |
| `--merge`, `-m` | Merge all completed work to current branch |
| `--interactive`, `-i` | Review each worktree before merging |

**Example workflow:**
```bash
# Check what's ready
./scripts/sync-worktrees.sh --status

# Interactively review and merge
./scripts/sync-worktrees.sh --interactive
```

## Workflow Patterns

| Pattern | Description | Use Case |
|---------|-------------|----------|
| **Competitive Implementation** | N agents on same task, pick best | UI components, algorithms |
| **Divide and Conquer** | Split feature into parallel tracks | Large features with independent parts |
| **Redundant Safety Net** | Multiple agents as backup | Critical/risky changes |
| **Exploration Sprint** | Each agent tries different approach | Architecture decisions (WebSocket vs SSE vs polling) |
| **Test-First Parallel** | One writes tests, others implement | TDD workflows |
| **Review Pipeline** | Separate implementation and review | Fresh-eyes code review |

See [references/workflow-patterns.md](references/workflow-patterns.md) for detailed examples.

## Background Agent Orchestration

Use Claude Code's native background agents (Task tool with `run_in_background: true`) combined with worktrees to delegate work while you continue on your main task.

### Architecture

```
Main Worktree (Orchestrator)
├── .agent-status/           # Status tracking (JSON files)
│   ├── task-api.json        # {"status": "COMPLETE", "summary": "..."}
│   └── task-ui.json
└── .worktrees/
    ├── task-api/            # Background agent 1's workspace
    │   └── RESULTS.md       # Agent writes summary here
    └── task-ui/             # Background agent 2's workspace
        └── RESULTS.md
```

### Orchestration Workflow

1. **Prepare worktrees** for each parallel task:
   ```bash
   git worktree add .worktrees/task-api -b task-api main
   git worktree add .worktrees/task-ui -b task-ui main
   ```

2. **Launch background agents** via Task tool:
   - Each agent works in its assigned worktree
   - Agent writes `RESULTS.md` when complete
   - Agent updates `.agent-status/<task>.json` with status

3. **Continue main work** while agents run in background

4. **Monitor progress**: Check `.agent-status/*.json` or use `TaskOutput`

5. **Sync results** when complete:
   ```bash
   ./scripts/sync-worktrees.sh --interactive
   ```

### Status File Convention

Background agents should write status to `.agent-status/<task-name>.json`:

```json
{
  "status": "COMPLETE",
  "started": "2024-01-15T10:30:00Z",
  "completed": "2024-01-15T10:45:00Z",
  "summary": "Implemented 5 endpoints, 12 tests passing",
  "files_changed": ["src/api/users.ts", "tests/api.test.ts"]
}
```

Status values: `RUNNING`, `COMPLETE`, `FAILED`, `BLOCKED`

### Task Instructions Template

When spawning background agents, include:

```markdown
## Task: [Task Name]
Work in `.worktrees/[task-name]/`

### Requirements
[Specific requirements]

### On Completion
1. Write summary to `RESULTS.md`
2. Commit: `git add -A && git commit -m "[task]: [summary]"`
3. Update: `../.agent-status/[task].json` with status: "COMPLETE"
```

## When to Use

**Use parallel worktrees when:**
- Multiple valid solutions exist (UI, algorithms)
- Complex tasks have failure risk (run 3, pick winner)
- Clear detailed plan exists for independent execution
- Features don't overlap in file modifications

**Use sequential when:**
- Critical refactors requiring consistency
- Tightly coupled changes to same files
- Merge conflicts would cost more than parallelism saves

## Resource Considerations

- **Token usage**: ~15x higher with multi-agent workflows
- **Subagent nesting**: Subagents cannot spawn other subagents
- **Context isolation**: Each subagent starts fresh, needs codebase orientation
- **Subscription limits**: Factor token consumption into your plan

## Directory Structure

```
parallel-worktrees/
├── README.md                # This file
├── SKILL.md                 # Skill definition and documentation
├── scripts/
│   ├── spawn-parallel.sh    # Create parallel worktrees
│   ├── cleanup-worktrees.sh # Remove worktrees
│   └── sync-worktrees.sh    # Merge completed work
└── references/
    └── workflow-patterns.md # Detailed pattern documentation
```

## Git Worktrees Quick Reference

```bash
# Create worktree with new branch
git worktree add .worktrees/feature-auth -b feature/auth main

# List all worktrees
git worktree list

# Remove worktree
git worktree remove .worktrees/feature-auth

# Force remove (uncommitted changes)
git worktree remove --force .worktrees/feature-auth

# Clean stale metadata
git worktree prune
```

## Claude Code Quick Reference

| Command | Purpose |
|---------|---------|
| `claude` | Start interactive session |
| `claude -p "prompt"` | Headless mode |
| `claude --continue` | Resume conversation |
| `/clear` | Reset context window |
| `/agents` | Manage subagents |
| `/compact` | Compress context |
| `Shift+Tab` | Toggle Plan Mode |

## License

This skill is provided as-is for use with Claude Code.
