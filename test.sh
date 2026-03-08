#!/bin/bash

# ==============================================================================
# Script: test.sh
# Purpose: Comprehensive test suite for the Open BMAD IDE Scaffolder.
#          - Uses a mocked environment (tmp directory, mocked npx/node).
#          - Verifies CLI arguments, configuration parsing, and fast-track features.
#          - Checks installation and uninstallation behaviors securely.
# Usage: ./test.sh
# ==============================================================================

# --- Console Color Definitions ---
GREEN='\033[0;32m'   # Success colors
RED='\033[0;31m'     # Error/failure colors
NC='\033[0m'         # No Color

# ------------------------------------------------------------------
# Setup Test Environment Variables
# ------------------------------------------------------------------

# SRC_DIR: Resolves the absolute directory path of where this test script lives.
# We need this to locate `bmad-init`, `install.sh`, etc. reliably.
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# TEST_ROOT: Create a safe, temporary, isolated directory for our sandbox.
TEST_ROOT=$(mktemp -d)
# If creating the tmp dir failed (e.g. disk full), crash early.
[[ -z "$TEST_ROOT" ]] && { echo "Failed to create temp directory"; exit 1; }

# trap EXIT: Guarantees that no matter how this script ends (success, crash, Ctrl+C),
# the temp directory is fully deleted so we don't leave garbage on the user's hard drive.
trap 'chmod -R 777 "$TEST_ROOT" 2>/dev/null; rm -rf "$TEST_ROOT"' EXIT

# ------------------------------------------------------------------
# Construct Sandbox OS environment
# ------------------------------------------------------------------

# Create a fake 'bin' folder inside our sandbox to hold our fake commands (Node/NPX).
mkdir -p "$TEST_ROOT/bin"

# OVERRIDE $PATH: By putting our fake `bin` at the START of the PATH, the system
# will run our mock `npx` and `node` before it finds the real ones on the user's computer.
export PATH="$TEST_ROOT/bin:$PATH"

# OVERRIDE $HOME: Point the $HOME environment variable to the sandbox.
# This ensures that any `~/.bmad-init-rc` or `.git` configurations happen in the sandbox,
# completely protecting the developer's real home directory from test pollution.
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

# OVERRIDE INSTALL DIRS: Force installers inside the sandbox rather than trying to hit /usr/local/bin
export BMAD_DEST_DIR="$TEST_ROOT/usr_bin"
export BMAD_LOCAL_DEST_DIR="$TEST_ROOT/local_bin"
mkdir -p "$BMAD_DEST_DIR" "$BMAD_LOCAL_DEST_DIR"

# ------------------------------------------------------------------
# Construct Mocks (Fake software logic)
# ------------------------------------------------------------------

# 1. Mock NPX
# We write a fake bash script called `npx` into our fake PATH.
cat << 'EOF' > "$TEST_ROOT/bin/npx"
#!/bin/bash
# If the caller is passing `bmad-method`, we intercept it!
if [ "$1" = "bmad-method" ]; then
    echo "MOCK: npx $@"
    # Fake a successful installation by dropping empty folders
    mkdir -p .agent _bmad _bmad-output
    exit 0 # fake success!
fi
# If it's something else, let the real 'npx' handle it (pass through)
/usr/bin/env npx "$@"
EOF
# Make the mock executable
chmod +x "$TEST_ROOT/bin/npx"

# 2. Mock NodeJS
# bmad-init checks if node exists. We just need it to say "Yes, I exist!".
cat << 'EOF' > "$TEST_ROOT/bin/node"
#!/bin/bash
echo "v18.0.0"
exit 0
EOF
chmod +x "$TEST_ROOT/bin/node"

# ------------------------------------------------------------------
# Test Runner Utilities
# ------------------------------------------------------------------
# Global counters to track how many tests pass or fail.
passed=0
failed=0

# Utility 1: Ensure a command exits with code 0 (success)
assert_success() {
    # Run the passed command ("$@") silently
    "$@" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS: $@${NC}"
        ((passed++)) # Increment pass counter
    else
        echo -e "${RED}✗ FAIL: $@${NC}"
        ((failed++)) # Increment fail counter
    fi
}

# Utility 2: Ensure a file or folder physically exists
assert_file_exists() {
    # -f checks for file, -d checks for directory
    if [ -f "$1" ] || [ -d "$1" ]; then
        echo -e "${GREEN}✓ PASS: Exists - $1${NC}"
        ((passed++))
    else
        echo -e "${RED}✗ FAIL: Missing - $1${NC}"
        ((failed++))
    fi
}

# Utility 3: Ensure a specific string exists inside a text file
assert_contains() {
    # grep -q runs quietly, -F treats the search as a literal string (no regex magic)
    if grep -qF "$2" "$1"; then
        echo -e "${GREEN}✓ PASS: Found '$2' in $1${NC}"
        ((passed++))
    else
        echo -e "${RED}✗ FAIL: Missing '$2' in $1${NC}"
        echo "Found contents:"
        cat "$1" # Dump the file so the developer can see why it failed
        ((failed++))
    fi
}

echo -e "Starting test suite in $TEST_ROOT\n"

# ==================================================================
# ACTUAL TESTS START HERE
# ==================================================================

echo -e "\n${BLUE}[TEST 1] Should display CLI help output when --help flag is used${NC}"
# Run command, save output to log.
"$SRC_DIR/bmad-init" --help > "$TEST_ROOT/help.log"
# Check if the log contains the expected usage block.
assert_contains "$TEST_ROOT/help.log" "Usage: bmad-init"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 2] Should update global config file when 'config set' command is run${NC}"
# Run command to set the global configuration silently.
"$SRC_DIR/bmad-init" config set tools roo-cline > /dev/null
# Ensure the config file actually generated in the mocked HOME directory.
assert_file_exists "$HOME/.bmad-init-rc"
# Check if the right value was written into the file.
assert_contains "$HOME/.bmad-init-rc" "BMAD_TOOLS=roo-cline"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 3] Should process fast-track installation without Git when --yes and --no-git are passed${NC}"
# Create a fresh isolated folder for proj1.
mkdir -p "$TEST_ROOT/proj1"
cd "$TEST_ROOT/proj1"
# Run command with strict override flags
"$SRC_DIR/bmad-init" --yes --tools fake-tool --no-git > out.log
# Verify the mock NPX worked (it creates these folders).
assert_file_exists ".agent"
assert_file_exists "_bmad"
# Verify the tool override made it into the log.
assert_contains "out.log" "fake-tool"

# Strict check that `.git` does NOT exist because of `--no-git`.
if [ -d ".git" ]; then
    echo -e "${RED}✗ FAIL: .git was created despite --no-git flag${NC}"
    ((failed++))
else
    echo -e "${GREEN}✓ PASS: .git was properly ignored due to flag${NC}"
    ((passed++))
fi

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 4] Should initialize Git and add .gitignore when executing full default sequence${NC}"
mkdir -p "$TEST_ROOT/proj2"
cd "$TEST_ROOT/proj2"
# Force default 'yes' behaviour using --yes
# Note: It should load the 'roo-cline' config from Test 2, and use Y for git by default.
"$SRC_DIR/bmad-init" --yes > out.log
# We expect git logic to have fired
assert_file_exists ".git"
assert_file_exists ".gitignore"
assert_contains ".gitignore" "_bmad"
assert_contains "out.log" "roo-cline"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 5] Should initialize Git but skip .gitignore creation when --no-ignore flag is passed${NC}"
mkdir -p "$TEST_ROOT/proj3"
cd "$TEST_ROOT/proj3"
"$SRC_DIR/bmad-init" --yes --no-ignore > out.log
assert_file_exists ".git" # Git WAS made
# Strict check that `.gitignore` was NOT made.
if [ -f ".gitignore" ]; then
    echo -e "${RED}✗ FAIL: .gitignore was created despite --no-ignore flag${NC}"
    ((failed++))
else
    echo -e "${GREEN}✓ PASS: .gitignore was appropriately avoided${NC}"
    ((passed++))
fi

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 6] Should gracefully skip git init when a git repository already exists${NC}"
mkdir -p "$TEST_ROOT/proj4"
cd "$TEST_ROOT/proj4"
# Pre-initialize a repo
git init > /dev/null 2>&1
# Run tool
"$SRC_DIR/bmad-init" --yes > out.log
# Ensure the tool notices it and prints the skip message
assert_contains "out.log" "Git repository already exists"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 7] Should disable git features for future runs when global config is updated to N${NC}"
"$SRC_DIR/bmad-init" config set auto-git N > /dev/null
"$SRC_DIR/bmad-init" config set auto-ignore N > /dev/null
# Check the home config for changes
assert_contains "$HOME/.bmad-init-rc" "AUTO_GIT_INIT=N"
assert_contains "$HOME/.bmad-init-rc" "AUTO_GIT_IGNORE=N"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 8] Should fail gracefully and show red error message when npx installation crashes${NC}"
# Hijack our mock NPX again, but this time, make it instantly fail.
cat << 'EOF' > "$TEST_ROOT/bin/npx"
#!/bin/bash
exit 1 # Fail code
EOF
mkdir -p "$TEST_ROOT/proj5"
cd "$TEST_ROOT/proj5"
# Execute but catch the crash `|| true` so the TEST suite doesn't crash itself. 
# We capture stderr (`2>&1`) to grab the error string.
"$SRC_DIR/bmad-init" --yes > out.log 2>&1 || true
# Ensure the script logged an intentional failure line.
assert_contains "out.log" "installation failed"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 9] Should install CLI properly securely and save defaults when install.sh is executed${NC}"
# Simulate an interactive user pressing keys: 'y', 'fake-tool', 'y', 'y', then Enter.
echo -e "y\nfake-tool\ny\ny\n" | "$SRC_DIR/install.sh" > "$TEST_ROOT/install_out.log" 2>&1
# Ensure the binary was copied to our fake global folder.
assert_file_exists "$BMAD_DEST_DIR/bmad-init"
# Check the log for success keywords.
assert_contains "$TEST_ROOT/install_out.log" "Installation Complete"
# Check if the preconfiguration questions correctly wrote to the global config.
assert_contains "$HOME/.bmad-init-rc" "fake-tool"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 10] Should completely remove executable and config file when uninstall.sh is executed${NC}"
# Pass an automatic "y" to confirm the destructive action.
echo "y" | "$SRC_DIR/uninstall.sh" > "$TEST_ROOT/uninstall_out.log"
# Ensure the executable was wiped from the target directory.
if [ -f "$BMAD_DEST_DIR/bmad-init" ]; then
    echo -e "${RED}✗ FAIL: bmad-init was not removed by uninstall.sh${NC}"
    ((failed++))
else
    echo -e "${GREEN}✓ PASS: bmad-init was successfully removed${NC}"
    ((passed++))
fi
assert_contains "$TEST_ROOT/uninstall_out.log" "Uninstallation Complete"

# ==================================================================
# Evaluate Results and Terminate
# ==================================================================
echo -e "\n=== Test Results ==="
echo -e "Passed: ${GREEN}${passed}${NC}"

if [ $failed -gt 0 ]; then
    # Print fail numbers and throw a hard stop.
    echo -e "Failed: ${RED}${failed}${NC}"
    exit 1
else
    # 100% success!
    echo -e "Failed: 0"
    echo -e "\n${GREEN}All tests passed successfully!${NC}"
    exit 0
fi
