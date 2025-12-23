# Workflow Patterns Reference

Detailed patterns for multi-agent parallel development with git worktrees and Claude Code.

## Pattern 1: Competitive Implementation

Run N agents on the same task, pick the best result.

### Setup
```bash
./scripts/spawn-parallel.sh user-dashboard 3
```

### Execution
In each worktree, give Claude identical instructions:
```
Implement a user dashboard component with:
- User profile summary
- Recent activity feed  
- Quick actions sidebar
Follow our React/TypeScript conventions.
Save results summary to RESULTS.md when complete.
```

### Selection Criteria
Compare implementations across:
- Code quality and readability
- Test coverage
- Performance characteristics
- Edge case handling

### Merge Strategy
```bash
# Review each implementation
cd .worktrees/user-dashboard-1 && git diff main
cd .worktrees/user-dashboard-2 && git diff main
cd .worktrees/user-dashboard-3 && git diff main

# Cherry-pick best parts or merge winner
git checkout main
git merge user-dashboard-2  # Assuming #2 was best
```

## Pattern 2: Divide and Conquer

Split large features into independent parallel tracks.

### Task Decomposition Example
Feature: "Add multi-tenant support"

| Worktree | Task | Dependencies |
|----------|------|--------------|
| tenant-1 | Database schema + migrations | None |
| tenant-2 | Authentication middleware | Schema |
| tenant-3 | API route updates | Schema |
| tenant-4 | Frontend context provider | API |

### Execution Order
1. Start tenant-1 first (no dependencies)
2. Once schema is committed and pushed, start tenant-2, tenant-3
3. Once API is ready, start tenant-4

### Coordination
```bash
# In tenant-2 worktree, after tenant-1 completes
git fetch origin
git rebase origin/tenant-1  # Get schema changes
```

## Pattern 3: Redundant Safety Net

For critical/risky changes, run multiple agents as backup.

### Use Cases
- Database migrations
- Authentication system changes
- Payment processing updates
- Core infrastructure refactors

### Execution
```bash
./scripts/spawn-parallel.sh payment-refactor 3
```

Each Claude instance works independently. If one fails or produces bugs, you have backups.

### Validation
```bash
# Run tests in each worktree
for i in 1 2 3; do
  (cd .worktrees/payment-refactor-$i && npm test) 
done

# Compare test results
```

## Pattern 4: Exploration Sprint

When unsure of the best approach, explore multiple architectures.

### Scenario
"We need to add real-time notifications. Options: WebSockets, SSE, or polling."

### Setup
```bash
./scripts/spawn-parallel.sh notifications 3
```

### Instructions Per Worktree
**Worktree 1:**
```
Implement real-time notifications using WebSockets.
Document tradeoffs in APPROACH.md
```

**Worktree 2:**
```
Implement real-time notifications using Server-Sent Events.
Document tradeoffs in APPROACH.md
```

**Worktree 3:**
```
Implement real-time notifications using long-polling.
Document tradeoffs in APPROACH.md
```

### Decision Framework
Compare APPROACH.md files for:
- Implementation complexity
- Server resource usage
- Browser compatibility
- Scaling characteristics

## Pattern 5: Test-First Parallel

One agent writes tests, others implement.

### Phase 1: Test Creation
```bash
git worktree add .worktrees/tests -b feature-tests main
cd .worktrees/tests
claude
```

Prompt:
```
Write comprehensive tests for a user search feature:
- Full-text search across name and email
- Filtering by role, status, created date
- Pagination support
- Permission-based result filtering

Tests should fail initially. Commit when complete.
```

### Phase 2: Parallel Implementation
```bash
git push origin feature-tests

./scripts/spawn-parallel.sh search-impl 2 feature-tests
```

Both implementations start from the test branch, race to make tests pass.

## Pattern 6: Review Pipeline

Separate implementation and review phases.

### Implementation Phase
```bash
cd .worktrees/feature-1
claude
# Claude implements feature
git add -A && git commit -m "Implement feature"
```

### Review Phase
```bash
# Clear context or use fresh session
/clear

# Now Claude reviews with fresh eyes
Prompt: Review the most recent commit. Focus on:
- Security vulnerabilities
- Performance issues
- Missing edge cases
- Code style violations
```

### Alternative: Dual Session Review
```bash
# Terminal 1: Implementation
cd .worktrees/feature-1 && claude

# Terminal 2: Review (different session)
cd .worktrees/feature-1 && claude --resume different-session
```

## Coordination Patterns

### Shared State via Files
Each agent writes status to a shared location:
```
.worktrees/
├── feature-1/STATUS.md  # "IN_PROGRESS: Implementing API"
├── feature-2/STATUS.md  # "BLOCKED: Waiting for schema"
├── feature-3/STATUS.md  # "COMPLETE: Ready for review"
```

### Git-Based Coordination
```bash
# Agent signals completion via branch
git push origin feature-1  # Other agents can now rebase

# Main orchestrator monitors
watch -n 5 'git fetch --all && git branch -r'
```

### Results Aggregation
Each agent writes to RESULTS.md:
```markdown
# Results: feature-1

## Summary
Implemented user search with Elasticsearch.

## Files Changed
- src/services/search.ts
- src/api/users/search.ts
- tests/search.test.ts

## Metrics
- Tests: 24 passing
- Coverage: 87%
- Build time: 12s
```

Aggregation script:
```bash
for dir in .worktrees/feature-*; do
  echo "=== $(basename $dir) ==="
  cat "$dir/RESULTS.md"
  echo ""
done > COMPARISON.md
```

## Background Agent Patterns

These patterns use Claude Code's native background agents (Task tool with `run_in_background: true`) for asynchronous parallel work.

### Pattern 7: Delegate and Continue

Main agent spawns background agents for independent tasks, continues its own work, then integrates results.

#### Setup
```bash
# Prepare worktrees
git worktree add .worktrees/docs -b docs-update main
git worktree add .worktrees/tests -b test-coverage main
mkdir -p .agent-status
```

#### Main Agent Orchestration
```markdown
1. Launch background agent for docs:
   Task tool (run_in_background: true):
   "Work in .worktrees/docs/. Update API documentation for new endpoints.
    Write RESULTS.md when done. Update ../.agent-status/docs.json with status."

2. Launch background agent for tests:
   Task tool (run_in_background: true):
   "Work in .worktrees/tests/. Add integration tests for auth module.
    Write RESULTS.md when done. Update ../.agent-status/tests.json with status."

3. Continue main implementation work...

4. Periodically check: cat .agent-status/*.json

5. When complete: ./scripts/sync-worktrees.sh --interactive
```

### Pattern 8: Fan-Out/Fan-In

Decompose a large task into parallel subtasks, wait for all to complete, then integrate.

#### Fan-Out Phase
```bash
# Create worktrees for each subtask
for task in api frontend database migrations; do
  git worktree add ".worktrees/feature-$task" -b "feature-$task" main
done

# Spawn background agent for each
# Each agent gets identical instructions adapted to their component
```

#### Agent Task Template
```markdown
## Task: Implement [component] for user authentication feature

Work in `.worktrees/feature-[component]/`

### Scope
- [Component-specific requirements]
- Do NOT modify files outside your component

### Dependencies
- Database schema will be in feature-database branch
- Wait for schema before implementing queries

### On Completion
1. Ensure all tests pass
2. Write RESULTS.md with summary
3. Commit all changes
4. Update ../.agent-status/feature-[component].json
```

#### Fan-In Phase
```bash
# Wait for all agents
while grep -q '"status": "RUNNING"' .agent-status/*.json 2>/dev/null; do
  echo "Waiting for agents..."
  sleep 30
done

# Review and merge in dependency order
./scripts/sync-worktrees.sh --interactive
```

### Pattern 9: Pipeline with Dependencies

Sequential stages where later stages depend on earlier ones.

#### Stage Definition
| Stage | Task | Depends On |
|-------|------|------------|
| 1 | Database migrations | None |
| 2a | API implementation | Stage 1 |
| 2b | Frontend types | Stage 1 |
| 3 | Integration tests | Stage 2a, 2b |

#### Execution
```markdown
Stage 1: Launch background agent for migrations
  - Works in .worktrees/migrations/
  - No dependencies, starts immediately

Wait for Stage 1 to complete (check status file)

Stage 2: Launch agents for API and Frontend in parallel
  - Each rebases on migrations branch first
  - git fetch && git rebase migrations

Wait for Stage 2 to complete

Stage 3: Launch integration test agent
  - Rebases on both API and Frontend branches
```

### Pattern 10: Supervisor with Auto-Retry

Monitor background agents and automatically retry failures.

#### Supervisor Script
```bash
#!/bin/bash
# supervisor.sh - Monitor and retry failed agents

MAX_RETRIES=3

while true; do
  for status_file in .agent-status/*.json; do
    [ -f "$status_file" ] || continue

    task=$(basename "$status_file" .json)
    status=$(jq -r '.status' "$status_file")
    retries=$(jq -r '.retries // 0' "$status_file")

    case "$status" in
      FAILED)
        if [ "$retries" -lt "$MAX_RETRIES" ]; then
          echo "Retrying $task (attempt $((retries + 1)))"
          # Update retry count
          jq ".retries = $((retries + 1)) | .status = \"RUNNING\"" "$status_file" > tmp && mv tmp "$status_file"
          # Re-launch agent (implementation depends on your setup)
        else
          echo "Max retries reached for $task"
        fi
        ;;
      COMPLETE)
        echo "$task completed successfully"
        ;;
    esac
  done

  # Exit if all complete or max retried
  if ! grep -q '"status": "RUNNING"' .agent-status/*.json 2>/dev/null; then
    echo "All agents finished"
    break
  fi

  sleep 30
done
```

### Pattern 11: Review Gate

Background agents do implementation, then a review agent validates before merge.

#### Implementation Phase
```markdown
1. Spawn implementation agent in .worktrees/feature/
2. Agent implements feature, commits, marks COMPLETE
3. Main agent continues other work
```

#### Review Phase
```markdown
1. When implementation complete, spawn review agent
2. Review agent:
   - Checks .worktrees/feature/ for the implementation
   - Runs tests
   - Reviews code quality
   - Creates .agent-status/feature-review.json with verdict

3. If APPROVED:
   - ./scripts/sync-worktrees.sh --merge

4. If REJECTED:
   - Review agent documents issues in REVIEW.md
   - Either fix manually or re-spawn implementation agent
```

### Best Practices for Background Agents

1. **Clear boundaries**: Each agent should have non-overlapping file responsibilities
2. **Idempotent tasks**: Design so agents can be safely restarted
3. **Status discipline**: Always update status files on completion/failure
4. **Result documentation**: RESULTS.md should explain what was done
5. **Dependency awareness**: Later stages must rebase on earlier work
6. **Timeout handling**: Set reasonable limits to prevent runaway agents
7. **Commit frequently**: Background agents should commit often to preserve work
8. **Clean exit**: Agents should clean up temporary files before marking complete
