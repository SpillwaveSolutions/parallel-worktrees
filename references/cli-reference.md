# CLI Reference

Complete command reference for Claude Code CLI operations in parallel worktree workflows.

## Shell Commands

| Command | Purpose |
|---------|---------|
| `claude` | Start interactive session |
| `claude -p "prompt"` | Headless mode for automation |
| `claude --continue` | Resume most recent conversation |
| `claude --dangerously-skip-permissions` | Skip prompts (containers only) |

## Keyboard Shortcuts

| Shortcut | Purpose |
|----------|---------|
| `Shift+Tab` | Toggle Plan Mode (read-only) |
| `Ctrl+C` | Cancel current operation |

## REPL Commands

| Command | Purpose |
|---------|---------|
| `/clear` | Reset context window |
| `/agents` | Manage subagents |
| `/compact` | Compress context preserving summary |
| `/init` | Orient Claude with codebase |
| `/help` | Display available commands |

## Git Worktree Commands

| Command | Purpose |
|---------|---------|
| `git worktree add PATH -b BRANCH BASE` | Create worktree with new branch |
| `git worktree add PATH BRANCH` | Create worktree for existing branch |
| `git worktree list` | List all worktrees |
| `git worktree remove PATH` | Remove a worktree |
| `git worktree prune` | Clean stale metadata |

## Subagent Invocation

Invoke subagents using the Task tool:

```
Task tool parameters:
- prompt: Instructions for the subagent
- subagent_type: "general-purpose", "plan", or "explore"
- run_in_background: true (for async execution)
```

## Status Monitoring

```bash
# Check background agent status
cat .agent-status/*.json | jq -r '.status'

# Detailed status view
for f in .agent-status/*.json; do
  echo "=== $(basename $f .json) ==="
  cat "$f" | jq .
done
```
