#!/bin/bash
# spawn-parallel.sh - Create parallel git worktrees for multi-agent Claude development
#
# Usage: spawn-parallel.sh <feature-name> [num-agents] [base-branch]
#   feature-name: Name for the feature/task (used in branch names)
#   num-agents:   Number of parallel worktrees to create (default: 3)
#   base-branch:  Branch to base worktrees on (default: main)
#
# Example: spawn-parallel.sh auth-refactor 4 develop

set -e

FEATURE="${1:?Error: Feature name required. Usage: spawn-parallel.sh <feature-name> [num-agents] [base-branch]}"
NUM="${2:-3}"
BASE_BRANCH="${3:-main}"
WORKTREE_DIR=".worktrees"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Creating ${NUM} parallel worktrees for: ${FEATURE}${NC}"
echo "Base branch: ${BASE_BRANCH}"
echo ""

# Create worktrees directory if needed
if [ ! -d "$WORKTREE_DIR" ]; then
    mkdir -p "$WORKTREE_DIR"
    echo ".worktrees/" >> .gitignore 2>/dev/null || true
    echo -e "${GREEN}✓ Created ${WORKTREE_DIR} directory${NC}"
fi

# Ensure base branch is up to date
git fetch origin "$BASE_BRANCH" 2>/dev/null || true

# Create worktrees
for i in $(seq 1 "$NUM"); do
    BRANCH_NAME="${FEATURE}-${i}"
    WORKTREE_PATH="${WORKTREE_DIR}/${FEATURE}-${i}"
    
    if [ -d "$WORKTREE_PATH" ]; then
        echo "⚠ Worktree already exists: ${WORKTREE_PATH}"
        continue
    fi
    
    git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" "$BASE_BRANCH"
    
    # Copy environment files if they exist
    [ -f ".env" ] && cp .env "$WORKTREE_PATH/" 2>/dev/null || true
    [ -f ".env.local" ] && cp .env.local "$WORKTREE_PATH/" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Created worktree: ${WORKTREE_PATH} (branch: ${BRANCH_NAME})${NC}"
done

echo ""
echo -e "${BLUE}Start Claude in each worktree:${NC}"
echo ""
for i in $(seq 1 "$NUM"); do
    echo "  cd ${WORKTREE_DIR}/${FEATURE}-${i} && claude"
done

echo ""
echo -e "${BLUE}Or use tmux/screen to run all in parallel:${NC}"
echo ""
echo "  for i in \$(seq 1 ${NUM}); do"
echo "    tmux new-window -n \"${FEATURE}-\$i\" \"cd ${WORKTREE_DIR}/${FEATURE}-\$i && claude\""
echo "  done"

echo ""
echo -e "${BLUE}When done, clean up with:${NC}"
echo ""
echo "  ./scripts/cleanup-worktrees.sh ${FEATURE}"
