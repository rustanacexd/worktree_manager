# Worktree Manager

Git worktrees without the pain.

## Why

Git worktrees are powerful but clunky. This script makes them simple:

- Create isolated workspaces instantly
- Switch between them effortlessly  
- Clean up when done
- Perfect for parallel development, AI experiments, and hotfixes

## Install

```bash
git clone https://github.com/yourusername/worktree-manager.git
chmod +x worktree-manager/wt.sh
```

Add to your shell:

```bash
# ~/.bashrc or ~/.zshrc
alias wt="~/code/worktree_manager/wt.sh"

# Optional: cd helper
wtcd() {
    local path=$(wt switch "$1" | tail -1 | cut -d' ' -f2)
    if [ -n "$path" ]; then
        cd "$path"
    fi
}
```

## Usage

```bash
wt new feature-name              # Create worktree
wt rm feature-name               # Remove worktree
wt list                          # List all worktrees
wt merge feature-name            # Merge branch
wt switch feature-name           # Show cd command
wt clean                         # Remove all worktrees
```

## Example Workflow

```bash
# Parallel development
wt new experiment
cd ../repo-experiment
# hack away in isolation

# When ready
cd ../repo
wt merge experiment
wt rm experiment
```

## Testing

```bash
./test_wt.sh  # Run test suite
```

## License

MIT
