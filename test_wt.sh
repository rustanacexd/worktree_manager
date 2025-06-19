#!/bin/bash

# Test suite for wt.sh
# Run with: bash test_wt.sh

set -e

# Add debug mode
DEBUG=${DEBUG:-0}
if [ "$DEBUG" = "1" ]; then
    set -x
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected to contain: $needle"
        echo "  Actual: $haystack"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$expected" -eq "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected exit code: $expected"
        echo "  Actual exit code: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Setup test environment
setup_test_repo() {
    # Create temporary test directory
    TEST_DIR=$(mktemp -d -t wt_test_XXXXXX)
    cd "$TEST_DIR"
    
    # Initialize git repo
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial commit
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial commit" --quiet
    
    # Copy wt.sh to test directory
    cp "$SCRIPT_PATH" ./wt.sh
    chmod +x ./wt.sh
}

cleanup_test_repo() {
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        # Make sure we're not in the test directory before removing it
        cd "$ORIGINAL_DIR" 2>/dev/null || cd ~
        rm -rf "$TEST_DIR"
    fi
}

# Test functions
test_show_usage() {
    echo -e "\n${YELLOW}Testing show_usage...${NC}"
    
    local output=$(./wt.sh 2>&1)
    assert_contains "$output" "Git Worktree Manager" "Usage shows title"
    assert_contains "$output" "Usage: wt" "Usage shows command format"
    assert_contains "$output" "Commands:" "Usage shows commands section"
}

test_create_worktree() {
    echo -e "\n${YELLOW}Testing create_worktree...${NC}"
    
    # Test creating worktree with auto-generated path
    local output=$(./wt.sh new test-feature 2>&1)
    local exit_code=$?
    
    assert_exit_code 0 "$exit_code" "Create worktree exits successfully"
    assert_contains "$output" "Worktree created at:" "Shows success message"
    
    # Check if worktree was actually created
    local worktree_exists=$(git worktree list | grep -c "test-feature")
    assert_equals "1" "$worktree_exists" "Worktree is listed in git worktree list"
    
    # Test creating worktree with custom path
    local custom_path="../custom-path-$$"  # Use PID to make it unique
    output=$(./wt.sh new another-feature "$custom_path" 2>&1)
    exit_code=$?
    
    assert_exit_code 0 "$exit_code" "Create worktree with custom path"
    assert_contains "$output" "$custom_path" "Uses custom path"
    
    # Clean up custom path
    if [ -d "$custom_path" ]; then
        git worktree remove "$custom_path" 2>/dev/null || true
    fi
}

test_list_worktrees() {
    echo -e "\n${YELLOW}Testing list_worktrees...${NC}"
    
    # Create a worktree first
    ./wt.sh new list-test >/dev/null 2>&1
    
    local output=$(./wt.sh list 2>&1)
    local exit_code=$?
    
    assert_exit_code 0 "$exit_code" "List worktrees exits successfully"
    assert_contains "$output" "Git Worktrees:" "Shows header"
    assert_contains "$output" "list-test" "Shows created worktree"
}

test_remove_worktree() {
    echo -e "\n${YELLOW}Testing remove_worktree...${NC}"
    
    # Create a worktree to remove
    ./wt.sh new remove-test >/dev/null 2>&1
    
    # Test removal by branch name
    local output=$(./wt.sh rm remove-test 2>&1)
    local exit_code=$?
    
    assert_exit_code 0 "$exit_code" "Remove worktree exits successfully"
    assert_contains "$output" "Removed worktree:" "Shows removal message"
    
    # Check if worktree was actually removed
    local worktree_exists=$(git worktree list | grep -c "remove-test")
    assert_equals "0" "$worktree_exists" "Worktree is removed from list"
}

test_error_handling() {
    echo -e "\n${YELLOW}Testing error handling...${NC}"
    
    # Test missing branch name - wt.sh new without args should fail with exit code 1
    local output
    local exit_code
    output=$(./wt.sh new 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    
    assert_exit_code 1 "$exit_code" "Fails when branch name missing"
    assert_contains "$output" "Branch name required" "Shows error message"
    
    # Test removing non-existent worktree
    output=$(./wt.sh rm non-existent 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    
    assert_exit_code 1 "$exit_code" "Fails when worktree doesn't exist"
    assert_contains "$output" "No worktree found" "Shows not found message"
}

test_merge_worktree() {
    echo -e "\n${YELLOW}Testing merge_worktree...${NC}"
    
    # Create a worktree with changes
    ./wt.sh new merge-test >/dev/null 2>&1
    
    # Find the actual worktree path
    local worktree_path=$(git worktree list | grep "merge-test" | awk '{print $1}')
    
    if [ -z "$worktree_path" ] || [ ! -d "$worktree_path" ]; then
        echo -e "${RED}✗${NC} Failed to create worktree for merge test"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return
    fi
    
    # Make changes in the worktree
    cd "$worktree_path"
    echo "new content" > new-file.txt
    git add new-file.txt
    git commit -m "Add new file" --quiet
    cd "$TEST_DIR"
    
    # Test successful merge
    local output=$(./wt.sh merge merge-test 2>&1)
    local exit_code=$?
    
    assert_exit_code 0 "$exit_code" "Merge exits successfully"
    assert_contains "$output" "Successfully merged" "Shows success message"
    
    # Test merging non-existent branch
    output=$(./wt.sh merge non-existent-branch 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    
    assert_exit_code 1 "$exit_code" "Fails when branch doesn't exist"
    assert_contains "$output" "Branch not found" "Shows branch not found message"
}

test_switch_worktree() {
    echo -e "\n${YELLOW}Testing switch_worktree...${NC}"
    
    # Create a worktree first
    ./wt.sh new switch-test >/dev/null 2>&1
    
    # Test switching by branch name
    local output=$(./wt.sh switch switch-test 2>&1)
    local exit_code=$?
    
    assert_exit_code 0 "$exit_code" "Switch exits successfully"
    assert_contains "$output" "cd " "Shows cd command"
    assert_contains "$output" "switch-test" "Contains worktree path"
    
    # Test switching to non-existent worktree
    output=$(./wt.sh switch non-existent 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    
    assert_exit_code 1 "$exit_code" "Fails when worktree doesn't exist"
    assert_contains "$output" "Worktree not found" "Shows not found message"
}

test_clean_worktrees() {
    echo -e "\n${YELLOW}Testing clean_worktrees...${NC}"
    
    # Create multiple worktrees
    ./wt.sh new clean-test-1 >/dev/null 2>&1
    ./wt.sh new clean-test-2 >/dev/null 2>&1
    
    # Verify worktrees were created
    local initial_count=$(git worktree list | wc -l)
    if [ "$initial_count" -lt 3 ]; then
        echo -e "${RED}✗${NC} Failed to create test worktrees"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return
    fi
    
    # Test clean with 'n' (cancel)
    # Use printf to ensure newline is sent after 'n'
    local output=$(printf "n\n" | ./wt.sh clean 2>&1)
    local exit_code=$?
    
    assert_exit_code 0 "$exit_code" "Clean with cancel exits successfully"
    assert_contains "$output" "Cancelled" "Shows cancelled message"
    
    # Verify worktrees still exist
    local worktree_count=$(git worktree list | wc -l | tr -d ' ')
    assert_equals "3" "$worktree_count" "Worktrees not removed when cancelled"
    
    # Test clean with 'y' (confirm)
    # Use printf to ensure newline is sent after 'y'
    output=$(printf "y\n" | ./wt.sh clean 2>&1)
    exit_code=$?
    
    assert_exit_code 0 "$exit_code" "Clean with confirm exits successfully"
    assert_contains "$output" "Cleanup complete" "Shows completion message"
    
    # Verify only main worktree remains
    worktree_count=$(git worktree list | wc -l | tr -d ' ')
    assert_equals "1" "$worktree_count" "Only main worktree remains after clean"
}

# Main test runner
main() {
    # Store the path to the original script
    SCRIPT_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
    
    # Store original directory for cleanup
    ORIGINAL_DIR=$(pwd)
    
    # Set up trap to clean up on exit
    trap 'cleanup_test_repo' EXIT
    
    echo -e "${YELLOW}Running tests for wt.sh...${NC}"
    
    # Run each test in its own repo
    setup_test_repo
    test_show_usage
    cleanup_test_repo
    
    setup_test_repo
    test_create_worktree
    cleanup_test_repo
    
    setup_test_repo
    test_list_worktrees
    cleanup_test_repo
    
    setup_test_repo
    test_remove_worktree
    cleanup_test_repo
    
    setup_test_repo
    test_error_handling
    cleanup_test_repo
    
    setup_test_repo
    test_merge_worktree
    cleanup_test_repo
    
    setup_test_repo
    test_switch_worktree
    cleanup_test_repo
    
    setup_test_repo
    test_clean_worktrees
    cleanup_test_repo
    
    # Summary
    echo -e "\n${YELLOW}Test Summary:${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Check if wt.sh path was provided
if [ $# -eq 0 ]; then
    # Try to find wt.sh in current directory
    if [ -f "./wt.sh" ]; then
        main "./wt.sh"
    else
        echo "Usage: $0 [path-to-wt.sh]"
        echo "Or run from the same directory as wt.sh"
        exit 1
    fi
else
    main "$1"
fi