#!/bin/bash

# Git Worktree Manager
# Usage: ./wt.sh [command] [args]
#
# QUICK SETUP:
# ------------
# 1. Make executable: chmod +x wt.sh
# 
# 2. Add to your .bashrc or .zshrc for easier access:
#    alias wt="~/path/to/wt.sh"
#    
#    # Function to actually change directories
#    wtcd() {
#        local path=$(~/path/to/wt.sh switch "$1" | tail -1 | cut -d' ' -f2)
#        if [ -n "$path" ]; then
#            cd "$path"
#        fi
#    }
#
# USAGE EXAMPLES:
# ---------------
# Create worktree:
#   ./wt.sh new ai-feature               # Creates ../my-app-ai-feature
#   ./wt.sh new hotfix ../hotfix-urgent  # Custom path
#
# List worktrees:
#   ./wt.sh list
#
# Remove worktree:
#   ./wt.sh rm ../my-app-ai-feature     # By path
#   ./wt.sh rm ai-feature                # By branch name
#
# Merge branch from worktree:
#   ./wt.sh merge ai-feature    # Merges ai-feature into current branch
#
# Switch to worktree (shows cd command):
#   ./wt.sh switch ai-feature   # Shows: cd ../my-app-ai-feature
#
# Clean all worktrees:
#   ./wt.sh clean              # Removes all except main (with confirmation)
#
# AI CODING WORKFLOW:
# -------------------
# # Create AI workspace
# ./wt.sh new claude-refactor
#
# # Let AI work there
# echo "Work in ../my-app-claude-refactor"
#
# # When done, merge back
# ./wt.sh merge claude-refactor
#
# # Clean up
# ./wt.sh rm claude-refactor

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to show usage
show_usage() {
    local cmd_name=$(basename "$0")
    # If called as 'wt.sh', just use 'wt'
    [[ "$cmd_name" == "wt.sh" ]] && cmd_name="wt"
    
    echo "Git Worktree Manager"
    echo ""
    echo "Usage: $cmd_name [command] [args]"
    echo ""
    echo "Commands:"
    echo "  new <branch-name> [path]     Create new worktree"
    echo "  rm <path-or-branch>          Remove worktree"
    echo "  list                         List all worktrees"
    echo "  merge <branch>               Merge branch from worktree"
    echo "  switch <path-or-branch>      Switch to worktree directory"
    echo "  clean                        Remove all worktrees except main"
    echo ""
    echo "Examples:"
    echo "  $cmd_name new feature-ai ../app-ai"
    echo "  $cmd_name new hotfix-123"
    echo "  $cmd_name rm ../app-ai"
    echo "  $cmd_name merge feature-ai"
    echo "  $cmd_name switch app-ai"
}

# Function to create new worktree
create_worktree() {
    local branch=$1
    local path=$2
    
    if [ -z "$branch" ]; then
        print_error "Branch name required"
        echo "Usage: wt new <branch-name> [path]"
        exit 1
    fi
    
    # If no path provided, use branch name
    if [ -z "$path" ]; then
        path="../$(basename "$(pwd)")-${branch}"
    fi
    
    # Check if branch exists
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        print_info "Using existing branch: $branch"
        git worktree add "$path" "$branch"
    else
        print_info "Creating new branch: $branch"
        git worktree add -b "$branch" "$path"
    fi
    
    print_success "Worktree created at: $path"
    print_info "To switch to it: cd $path"
}

# Function to remove worktree
remove_worktree() {
    local target=$1
    
    if [ -z "$target" ]; then
        print_error "Path or branch name required"
        echo "Usage: wt rm <path-or-branch>"
        exit 1
    fi
    
    # First, try as a direct path
    if git worktree remove "$target" 2>/dev/null; then
        print_success "Removed worktree: $target"
        return
    fi
    
    # If that fails, try to find by branch name or partial match
    local found_path=""
    
    # Try exact branch match
    found_path=$(git worktree list --porcelain | grep -B1 "branch refs/heads/$target$" | grep "^worktree" | cut -d' ' -f2 | head -1)
    
    # If not found, try partial match on path
    if [ -z "$found_path" ]; then
        found_path=$(git worktree list | grep -i "$target" | awk '{print $1}' | head -1)
    fi
    
    if [ -n "$found_path" ]; then
        git worktree remove "$found_path"
        print_success "Removed worktree: $found_path"
    else
        print_error "No worktree found matching: $target"
        print_info "Available worktrees:"
        git worktree list | sed 's/^/  /'
        exit 1
    fi
}

# Function to list worktrees
list_worktrees() {
    print_info "Git Worktrees:"
    echo ""
    
    # Parse git worktree list for prettier output
    git worktree list --porcelain | awk '
        /^worktree/ {wt=$2}
        /^HEAD/ {head=$2}
        /^branch/ {branch=$2; sub(/refs\/heads\//, "", branch)}
        /^$/ {
            if (wt && head) {
                printf "  %-40s %-20s %s\n", wt, branch ? branch : "detached", substr(head, 1, 7)
            }
            wt=""; head=""; branch=""
        }
    '
}

# Function to merge branch from worktree
merge_worktree() {
    local branch=$1
    
    if [ -z "$branch" ]; then
        print_error "Branch name required"
        echo "Usage: wt merge <branch>"
        exit 1
    fi
    
    # Get current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    
    print_info "Merging $branch into $current_branch"
    
    # Check if branch exists
    if ! git show-ref --verify --quiet "refs/heads/$branch"; then
        print_error "Branch not found: $branch"
        exit 1
    fi
    
    # Perform merge
    if git merge "$branch"; then
        print_success "Successfully merged $branch into $current_branch"
    else
        print_warning "Merge conflict! Resolve conflicts and commit"
    fi
}

# Function to switch to worktree directory
switch_worktree() {
    local target=$1
    
    if [ -z "$target" ]; then
        print_error "Path or branch name required"
        echo "Usage: wt switch <path-or-branch>"
        exit 1
    fi
    
    # Find worktree path
    local path=""
    
    # First try exact branch match
    path=$(git worktree list --porcelain | grep -B1 "branch refs/heads/$target$" | grep "^worktree" | cut -d' ' -f2 | head -1)
    
    # If not found, try partial match on path
    if [ -z "$path" ]; then
        path=$(git worktree list | grep -i "$target" | awk '{print $1}' | head -1)
    fi
    
    if [ -z "$path" ] || [ ! -d "$path" ]; then
        print_error "Worktree not found: $target"
        print_info "Available worktrees:"
        git worktree list | sed 's/^/  /'
        exit 1
    fi
    
    print_info "Switching to: $path"
    echo "cd $path"
}

# Function to clean all worktrees except main
clean_worktrees() {
    print_warning "This will remove all worktrees except the main one"
    # Check if stdin is a terminal (interactive) or pipe/redirect
    if [ -t 0 ]; then
        # Interactive mode - use -n 1 for single character
        read -p "Are you sure? (y/N) " -n 1 -r
        echo
    else
        # Non-interactive mode (piped input) - read full line
        read -p "Are you sure? (y/N) " -r
    fi
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local main_wt=$(git worktree list | head -1 | awk '{print $1}')
        git worktree list --porcelain | grep "^worktree" | cut -d' ' -f2 | while read -r wt; do
            if [ "$wt" != "$main_wt" ]; then
                print_info "Removing: $wt"
                git worktree remove "$wt" || print_warning "Failed to remove $wt"
            fi
        done
        print_success "Cleanup complete"
    else
        print_info "Cancelled"
    fi
}

# Main script logic
case "$1" in
    new|add|create)
        create_worktree "$2" "$3"
        ;;
    rm|remove|delete)
        remove_worktree "$2"
        ;;
    list|ls)
        list_worktrees
        ;;
    merge)
        merge_worktree "$2"
        ;;
    switch|cd)
        switch_worktree "$2"
        ;;
    clean)
        clean_worktrees
        ;;
    "")
        show_usage
        exit 0
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
