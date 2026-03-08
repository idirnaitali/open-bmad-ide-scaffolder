#!/bin/bash

# Configuration and Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT=$(mktemp -d)

# ------------------------------------------------------------------
# Setup Test Environment
# ------------------------------------------------------------------
mkdir -p "$TEST_ROOT/bin"
export PATH="$TEST_ROOT/bin:$PATH"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

# Mock installation paths to protect the real system
export BMAD_DEST_DIR="$TEST_ROOT/usr_bin"
export BMAD_LOCAL_DEST_DIR="$TEST_ROOT/local_bin"
mkdir -p "$BMAD_DEST_DIR" "$BMAD_LOCAL_DEST_DIR"

# 1. Mock NPX so we don't actually download NPM packages during testing.
# This makes tests extremely fast and safe.
cat << 'EOF' > "$TEST_ROOT/bin/npx"
#!/bin/bash
if [ "$1" = "bmad-method" ]; then
    echo "MOCK: npx $@"
    mkdir -p .agent _bmad _bmad-output
    exit 0
fi
# Pass through other commands if necessary
/usr/bin/env npx "$@"
EOF
chmod +x "$TEST_ROOT/bin/npx"

# 2. Test Runner Utilities
passed=0
failed=0

assert_success() {
    "$@" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS: $@${NC}"
        ((passed++))
    else
        echo -e "${RED}✗ FAIL: $@${NC}"
        ((failed++))
    fi
}

assert_file_exists() {
    if [ -f "$1" ] || [ -d "$1" ]; then
        echo -e "${GREEN}✓ PASS: Exists - $1${NC}"
        ((passed++))
    else
        echo -e "${RED}✗ FAIL: Missing - $1${NC}"
        ((failed++))
    fi
}

assert_contains() {
    if grep -q "$2" "$1"; then
        echo -e "${GREEN}✓ PASS: Found '$2' in $1${NC}"
        ((passed++))
    else
        echo -e "${RED}✗ FAIL: Missing '$2' in $1${NC}"
        echo "Found contents:"
        cat "$1"
        ((failed++))
    fi
}

echo -e "Starting test suite in $TEST_ROOT\n"

# ------------------------------------------------------------------
# TESTS
# ------------------------------------------------------------------

echo -e "\n${BLUE}[TEST 1] Should display CLI help output when --help flag is used${NC}"
"$SRC_DIR/bmad-init" --help > "$TEST_ROOT/help.log"
assert_contains "$TEST_ROOT/help.log" "Usage: bmad-init"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 2] Should update global config file when 'config set' command is run${NC}"
"$SRC_DIR/bmad-init" config set tools roo-cline > /dev/null
assert_file_exists "$HOME/.bmad-init-rc"
assert_contains "$HOME/.bmad-init-rc" "BMAD_TOOLS=roo-cline"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 3] Should process fast-track installation without Git when --yes and --no-git are passed${NC}"
mkdir -p "$TEST_ROOT/proj1"
cd "$TEST_ROOT/proj1"
"$SRC_DIR/bmad-init" --yes --tools fake-tool --no-git > out.log
assert_file_exists ".agent"
assert_file_exists "_bmad"
assert_contains "out.log" "fake-tool"

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
assert_file_exists ".git"
assert_file_exists ".gitignore"
assert_contains ".gitignore" "_bmad"
assert_contains "out.log" "roo-cline"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 5] Should initialize Git but skip .gitignore creation when --no-ignore flag is passed${NC}"
mkdir -p "$TEST_ROOT/proj3"
cd "$TEST_ROOT/proj3"
"$SRC_DIR/bmad-init" --yes --no-ignore > out.log
assert_file_exists ".git"
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
git init > /dev/null 2>&1
"$SRC_DIR/bmad-init" --yes > out.log
assert_contains "out.log" "Git repository already exists"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 7] Should disable git features for future runs when global config is updated to N${NC}"
"$SRC_DIR/bmad-init" config set auto-git N > /dev/null
"$SRC_DIR/bmad-init" config set auto-ignore N > /dev/null
assert_contains "$HOME/.bmad-init-rc" "AUTO_GIT_INIT=N"
assert_contains "$HOME/.bmad-init-rc" "AUTO_GIT_IGNORE=N"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 8] Should fail gracefully and show red error message when npx installation crashes${NC}"
cat << 'EOF' > "$TEST_ROOT/bin/npx"
#!/bin/bash
exit 1
EOF
mkdir -p "$TEST_ROOT/proj5"
cd "$TEST_ROOT/proj5"
# Execute but prevent the test script itself from failing by catching the error code
"$SRC_DIR/bmad-init" --yes > out.log 2>&1 || true
assert_contains "out.log" "installation failed"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 9] Should install CLI properly securely and save defaults when install.sh is executed${NC}"
# Simulate an interactive 'yes' to preconfigure parameters and 'yes' to inputs
echo -e "y\nfake-tool\ny\ny\n" | "$SRC_DIR/install.sh" > "$TEST_ROOT/install_out.log" 2>&1
assert_file_exists "$BMAD_DEST_DIR/bmad-init"
assert_contains "$TEST_ROOT/install_out.log" "Installation Complete"
assert_contains "$HOME/.bmad-init-rc" "fake-tool"

# ------------------------------------------------------------------
echo -e "\n${BLUE}[TEST 10] Should completely remove executable and config file when uninstall.sh is executed${NC}"
# Simulate an automatic "y" to confirm uninstallation
echo "y" | "$SRC_DIR/uninstall.sh" > "$TEST_ROOT/uninstall_out.log"
if [ -f "$BMAD_DEST_DIR/bmad-init" ]; then
    echo -e "${RED}✗ FAIL: bmad-init was not removed by uninstall.sh${NC}"
    ((failed++))
else
    echo -e "${GREEN}✓ PASS: bmad-init was successfully removed${NC}"
    ((passed++))
fi
assert_contains "$TEST_ROOT/uninstall_out.log" "Uninstallation Complete"

# ------------------------------------------------------------------
# Evaluate Results
# ------------------------------------------------------------------
echo -e "\n=== Test Results ==="
echo -e "Passed: ${GREEN}${passed}${NC}"
if [ $failed -gt 0 ]; then
    echo -e "Failed: ${RED}${failed}${NC}"
    echo -e "\nCleaning up..."
    rm -rf "$TEST_ROOT"
    exit 1
else
    echo -e "Failed: 0"
    echo -e "\n${GREEN}All tests passed successfully!${NC}"
    echo "Cleaning up safe test environment..."
    rm -rf "$TEST_ROOT"
    exit 0
fi
