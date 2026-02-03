# Debug Analysis: Gem Caching Not Working in Docker Sandbox

**Date:** 2026-01-30
**Issue:** Despite installing gems successfully, subsequent runs still execute `bundle install` instead of skipping

---

## Problem Summary

**Symptom:** After a successful run where gems are installed, the next run still shows "Installing Ruby dependencies..." instead of "Ruby dependencies already installed (skipping)"

**Expected:** After a successful run, the marker file `.bundle/.installed` should persist in the workspace volume and subsequent runs should skip gem installation

**Context:**
- Docker sandbox environment using workspace volume for persistence
- Script made it to line 110 (db:prepare) before failing on migration issue
- Gems should have been cached but weren't on next run

---

## Missing Information

1. What does the current run output show? Does it say "Installing Ruby dependencies..." or "Ruby dependencies already installed (skipping)"?
2. Does the workspace volume exist between runs?
3. What's in the volume after a run? Does `.bundle/.installed` exist?
4. Is `git reset --hard` (line 72) removing the `.bundle` directory?

---

## Hypotheses

### Hypothesis 1: `git reset --hard` Removes .bundle Directory

**Likelihood:** High

**Theory:** When the workspace already exists (line 68-72), `git reset --hard origin/main` resets tracked files but also removes untracked files if they're in a clean state. If `.bundle` somehow gets tracked or reset, the marker file disappears.

**Supporting evidence:**
- The caching works on first clone (line 51-67) but fails on subsequent runs
- `git reset --hard` is aggressive and can affect working directory

**Contradicting evidence:**
- `.bundle` is in `.gitignore` (line 8 of root .gitignore: `/.bundle`)
- Untracked files should survive `git reset --hard`

**How to test:**
1. After a run, manually check if `.bundle/.installed` exists:
   ```bash
   docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 cat /workspace/.bundle/.installed
   ```
2. Run sandbox again and check if the file still exists before line 85 executes

---

### Hypothesis 2: Marker File Written to Wrong Location

**Likelihood:** High

**Theory:** The marker is written to `/workspace/.bundle/.installed` (line 112), but gems are installed to `/home/claude/.bundle` (line 87). When checking if gems are available (line 85), `bundle exec ruby` looks in `/home/claude/.bundle`, which is NOT in the persisted workspace volume.

**Supporting evidence:**
- Line 87: `bundle config set --local path '/home/claude/.bundle'` - gems go to HOME directory
- Line 112: `echo "$GEMFILE_CHECKSUM" > .bundle/.installed` - marker goes to workspace
- `/home/claude/.bundle` is NOT in the workspace volume, so gems are lost between runs

**Contradicting evidence:**
- The bundle config is set with `--local` which creates `.bundle/config` in the project

**How to test:**
1. Check where gems are actually installed:
   ```bash
   docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 ls -la /workspace/.bundle/
   ```
2. Check bundle config:
   ```bash
   docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 cat /workspace/.bundle/config
   ```

**Fix if confirmed:** Change bundle path from `/home/claude/.bundle` to `/workspace/.bundle` so gems persist in the volume

---

### Hypothesis 3: The `bundle exec ruby` Check Fails

**Likelihood:** Medium

**Theory:** Even if the marker file exists and checksum matches, the third condition `! bundle exec ruby -e "exit 0" 2>/dev/null` fails because gems are installed to a path that doesn't persist, causing the entire `if` condition to be true.

**Supporting evidence:**
- This is a consequence of Hypothesis 2
- The check would fail because gems don't exist in the expected location

**How to test:**
Add debug output before line 85:
```bash
log "DEBUG: Marker exists: $(test -f .bundle/.installed && echo yes || echo no)"
log "DEBUG: Checksum match: $(cat .bundle/.installed 2>/dev/null) vs $GEMFILE_CHECKSUM"
log "DEBUG: Bundle exec works: $(bundle exec ruby -e 'exit 0' 2>&1 && echo yes || echo no)"
```

---

### Hypothesis 4: Workspace Volume Not Actually Persisting

**Likelihood:** Low

**Theory:** The `claude_workspace` volume is being deleted between runs, or `docker compose down -v` is being run automatically.

**Supporting evidence:**
- User previously ran `docker compose down -v` multiple times during debugging

**How to test:**
```bash
docker volume ls | grep claude-sandbox
```

---

### Hypothesis 5: Line 110-118 Runs BEFORE db:prepare

**Likelihood:** Medium

**Theory:** Looking at the current code, the marker files are written at lines 110-118, which is BEFORE `db:prepare` (line 122). This is the opposite of what was intended - we wanted markers written AFTER successful db:prepare.

**Supporting evidence:**
- Reading the code: lines 110-118 come before line 122
- The edit to "delay" marker writing didn't actually delay it past db:prepare

**How to test:**
Re-read the entrypoint.sh and verify line order

**Fix if confirmed:** Move lines 110-118 to after line 122

---

## Recommended Investigation Order

1. **Hypothesis 2 first** - Most likely root cause. Check if bundle path mismatch is the issue
2. **Hypothesis 3** - Verify the `bundle exec` check is what's triggering reinstall
3. **Hypothesis 1** - Check if git reset is affecting .bundle directory
4. **Hypothesis 5** - Verify marker file order in the script
5. **Hypothesis 4** - Verify volume persistence

---

## Quick Diagnostic Commands

```bash
# Check if workspace volume exists
docker volume ls | grep claude-sandbox

# Check what's in the workspace volume
docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 ls -la /workspace/.bundle/

# Check if marker file exists
docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 cat /workspace/.bundle/.installed 2>/dev/null || echo "Marker not found"

# Check bundle config
docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 cat /workspace/.bundle/config 2>/dev/null || echo "Config not found"

# Check if gems exist in home directory (they won't persist)
docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 ls -la /home/claude/.bundle/ 2>/dev/null || echo "Home .bundle not in volume"
```

---

## Testing Results

### Test 1: Check Workspace Volume Exists
```bash
docker volume ls | grep claude-sandbox
```
**Result:** ✅ Volume exists: `claude-sandbox_claude_workspace`

### Test 2: Check Bundle Config Location
```bash
docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 cat /workspace/.bundle/config
```
**Result:** ✅ Config exists:
```yaml
BUNDLE_PATH: "/home/claude/.bundle"  # ← PROBLEM!
BUNDLE_WITHOUT: "production"
```

### Test 3: Check If Gems Exist in Workspace
```bash
docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 ls -la /workspace/.bundle/ruby/
```
**Result:** ❌ No gems found - directory doesn't exist

### Test 4: Check Marker File
```bash
docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 cat /workspace/.bundle/.installed
```
**Result:** ✅ Marker exists with checksum: `28ab3adb8bcd813ae71d6fb859cd270c`

---

## Root Cause

**Hypothesis 2 CONFIRMED: Bundle Path Mismatch**

The bundle configuration was set to install gems to `/home/claude/.bundle`:
```bash
bundle config set --local path '/home/claude/.bundle'
```

**The Problem:**
- Gems installed to `/home/claude/.bundle` (NOT in workspace volume)
- `/home/claude/.bundle` is lost when container exits
- Workspace volume only persists `/workspace`
- Marker file in `/workspace/.bundle/.installed` persists
- On next run: marker exists, checksum matches, but `bundle exec ruby` fails because gems are gone
- Result: Reinstalls every time

**Why the Check Failed:**
```bash
! bundle exec ruby -e "exit 0" 2>/dev/null  # Always fails because gems are missing
```

---

## Solution

### Fix 1: Change Bundle Path to Workspace
Changed line 87 in `entrypoint.sh`:
```bash
# BEFORE:
bundle config set --local path '/home/claude/.bundle'

# AFTER:
bundle config set --local path 'vendor/bundle'
```

Now gems install to `/workspace/vendor/bundle` which IS in the persisted volume.

### Fix 2: Move Marker Writing After db:prepare
Moved lines 110-118 to after line 122 so markers are only written after successful database setup.

**Before:**
```bash
bundle install
# Write markers here ← Too early!
bundle exec rails db:prepare  # If this fails, markers already written
```

**After:**
```bash
bundle install
bundle exec rails db:prepare  # Must succeed first
# Write markers here ← Only after success!
```

### Changes Made
1. `docker/claude-sandbox/entrypoint.sh` line 87: Changed bundle path to `vendor/bundle`
2. `docker/claude-sandbox/entrypoint.sh` lines 110-122: Moved marker writing to after db:prepare

### Testing the Fix
```bash
# First run - installs everything
bin/claude-sandbox local "list files in app/ and exit"

# Second run - should skip with "already installed (skipping)"
bin/claude-sandbox local "list files in app/ and exit"

# Verify gems persist in volume
docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 ls -la /workspace/vendor/bundle/ruby/
```
