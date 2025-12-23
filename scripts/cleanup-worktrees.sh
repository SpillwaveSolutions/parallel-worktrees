#!/bin/bash
# cleanup-worktrees.sh - Remove parallel worktrees and optionally their branches
#
# Usage: cleanup-worktrees.sh <feature-name> [--delete-branches]
#   feature-name:     Name of the feature to clean up
#   --delete-branches: Also delete the associated git branches
#
# Example: cleanup-worktrees.sh auth-refactor --delete-branches

set -e

FEATURE="${1:?Error: Feature name required. Usage: cleanup-worktrees.sh <feature-name> [--delete-branches]}"
DELETE_BRANCHES="${2:-}"
WORKTREE_DIR=".worktrees"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Cleaning up worktrees for: ${FEATURE}"
echo ""

# Find and remove matching worktrees
for worktree in "${WORKTREE_DIR}/${FEATURE}"-*; do
    if [ -d "$worktree" ]; then
        BRANCH_NAME=$(basename "$worktree")
        
        # Check for uncommitted changes
        if [ -n "$(cd "$worktree" && git status --porcelain)" ]; then
            echo -e "${YELLOW}⚠ Uncommitted changes in ${worktree}${NC}"
            read -p "Force remove? (y/N): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                git worktree remove --force "$worktree"
                echo -e "${GREEN}✓ Removed worktree: ${worktree}${NC}"
            else
                echo "Skipped: ${worktree}"
                continue
            fi
        else
            git worktree remove "$worktree"
            echo -e "${GREEN}✓ Removed worktree: ${worktree}${NC}"
        fi
        
        # Optionally delete the branch
        if [ "$DELETE_BRANCHES" = "--delete-branches" ]; then
            if git branch --list "$BRANCH_NAME" | grep -q .; then
                git branch -D "$BRANCH_NAME" 2>/dev/null || true
                echo -e "${GREEN}✓ Deleted branch: ${BRANCH_NAME}${NC}"
            fi
        fi
    fi
done

# Prune stale worktree metadata
git worktree prune
echo ""
echo -e "${GREEN}✓ Cleanup complete${NC}"

# Show remaining worktrees
echo ""
echo "Remaining worktrees:"
git worktree list
