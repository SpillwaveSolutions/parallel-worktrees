#!/bin/bash
# sync-worktrees.sh - Review and merge completed worktree work
#
# Usage: sync-worktrees.sh [--status|--merge|--interactive]
#   --status:      Show status of all worktrees and agents
#   --merge:       Merge all completed work to current branch
#   --interactive: Review each worktree before merging
#
# Example: sync-worktrees.sh --interactive

set -e

MODE="${1:---status}"
WORKTREE_DIR=".worktrees"
STATUS_DIR=".agent-status"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

show_status() {
    echo -e "${BLUE}=== Worktree Status ===${NC}"
    echo ""

    # Show git worktrees
    echo -e "${BLUE}Git Worktrees:${NC}"
    git worktree list
    echo ""

    # Show agent status files if they exist
    if [ -d "$STATUS_DIR" ] && [ "$(ls -A $STATUS_DIR 2>/dev/null)" ]; then
        echo -e "${BLUE}Agent Status:${NC}"
        for status_file in "$STATUS_DIR"/*.json; do
            if [ -f "$status_file" ]; then
                task_name=$(basename "$status_file" .json)
                if command -v jq &> /dev/null; then
                    status=$(jq -r '.status // "UNKNOWN"' "$status_file" 2>/dev/null || echo "PARSE_ERROR")
                    summary=$(jq -r '.summary // ""' "$status_file" 2>/dev/null || echo "")
                else
                    status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$status_file" | cut -d'"' -f4)
                fi

                case "$status" in
                    COMPLETE) color=$GREEN ;;
                    RUNNING)  color=$YELLOW ;;
                    FAILED)   color=$RED ;;
                    BLOCKED)  color=$YELLOW ;;
                    *)        color=$NC ;;
                esac

                echo -e "  ${task_name}: ${color}${status}${NC}"
                [ -n "$summary" ] && echo "    $summary"
            fi
        done
        echo ""
    fi

    # Show changes in each worktree
    echo -e "${BLUE}Worktree Changes:${NC}"
    for worktree in "$WORKTREE_DIR"/*/; do
        if [ -d "$worktree" ]; then
            worktree_name=$(basename "$worktree")
            branch_name=$(cd "$worktree" && git branch --show-current 2>/dev/null || echo "detached")

            # Count commits ahead of main
            commits_ahead=$(cd "$worktree" && git rev-list --count "$CURRENT_BRANCH"..HEAD 2>/dev/null || echo "0")

            # Check for uncommitted changes
            has_changes=$(cd "$worktree" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

            echo -e "  ${worktree_name} (${branch_name}):"
            echo "    Commits ahead: $commits_ahead"
            [ "$has_changes" -gt 0 ] && echo -e "    ${YELLOW}Uncommitted changes: $has_changes files${NC}"

            # Show RESULTS.md summary if exists
            if [ -f "${worktree}RESULTS.md" ]; then
                echo "    Has RESULTS.md"
            fi
        fi
    done
}

merge_worktree() {
    local worktree_path="$1"
    local worktree_name=$(basename "$worktree_path")
    local branch_name=$(cd "$worktree_path" && git branch --show-current 2>/dev/null)

    if [ -z "$branch_name" ]; then
        echo -e "${RED}Cannot merge: worktree is in detached HEAD state${NC}"
        return 1
    fi

    # Check for uncommitted changes
    if [ -n "$(cd "$worktree_path" && git status --porcelain)" ]; then
        echo -e "${YELLOW}Warning: Uncommitted changes in $worktree_name${NC}"
        read -p "Commit them first? (y/N): " confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            (cd "$worktree_path" && git add -A && git commit -m "WIP: Auto-commit before merge")
        else
            echo "Skipping merge for $worktree_name"
            return 1
        fi
    fi

    # Perform merge
    echo -e "${BLUE}Merging $branch_name into $CURRENT_BRANCH...${NC}"
    if git merge "$branch_name" -m "Merge $branch_name from parallel worktree"; then
        echo -e "${GREEN}Successfully merged $branch_name${NC}"

        # Ask about cleanup
        read -p "Remove worktree and branch? (y/N): " cleanup
        if [ "$cleanup" = "y" ] || [ "$cleanup" = "Y" ]; then
            git worktree remove "$worktree_path"
            git branch -d "$branch_name" 2>/dev/null || true

            # Clean up status file
            [ -f "$STATUS_DIR/${worktree_name}.json" ] && rm "$STATUS_DIR/${worktree_name}.json"

            echo -e "${GREEN}Cleaned up $worktree_name${NC}"
        fi
        return 0
    else
        echo -e "${RED}Merge conflict! Resolve manually.${NC}"
        return 1
    fi
}

merge_all() {
    echo -e "${BLUE}Merging all completed worktrees...${NC}"
    echo ""

    for worktree in "$WORKTREE_DIR"/*/; do
        if [ -d "$worktree" ]; then
            worktree_name=$(basename "$worktree")

            # Check agent status if available
            if [ -f "$STATUS_DIR/${worktree_name}.json" ]; then
                status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATUS_DIR/${worktree_name}.json" 2>/dev/null | cut -d'"' -f4)
                if [ "$status" != "COMPLETE" ]; then
                    echo -e "${YELLOW}Skipping $worktree_name (status: $status)${NC}"
                    continue
                fi
            fi

            merge_worktree "$worktree"
        fi
    done
}

interactive_merge() {
    echo -e "${BLUE}Interactive merge mode${NC}"
    echo ""

    for worktree in "$WORKTREE_DIR"/*/; do
        if [ -d "$worktree" ]; then
            worktree_name=$(basename "$worktree")
            branch_name=$(cd "$worktree" && git branch --show-current 2>/dev/null || echo "detached")

            echo ""
            echo -e "${BLUE}=== $worktree_name ($branch_name) ===${NC}"

            # Show diff summary
            echo "Changes:"
            (cd "$worktree" && git diff --stat "$CURRENT_BRANCH"..HEAD 2>/dev/null) || echo "  (no commits)"

            # Show RESULTS.md if exists
            if [ -f "${worktree}RESULTS.md" ]; then
                echo ""
                echo "RESULTS.md:"
                head -20 "${worktree}RESULTS.md"
                echo "..."
            fi

            echo ""
            read -p "Merge this worktree? (y/n/s=skip/q=quit): " choice
            case "$choice" in
                y|Y) merge_worktree "$worktree" ;;
                q|Q) echo "Quitting."; exit 0 ;;
                *)   echo "Skipped." ;;
            esac
        fi
    done
}

# Main
case "$MODE" in
    --status|-s)
        show_status
        ;;
    --merge|-m)
        merge_all
        ;;
    --interactive|-i)
        interactive_merge
        ;;
    *)
        echo "Usage: sync-worktrees.sh [--status|--merge|--interactive]"
        echo ""
        echo "Options:"
        echo "  --status, -s       Show status of all worktrees"
        echo "  --merge, -m        Merge all completed work"
        echo "  --interactive, -i  Review each before merging"
        exit 1
        ;;
esac
