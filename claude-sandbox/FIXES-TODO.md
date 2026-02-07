# S3 Cache Implementation - Issues to Fix

## 1. Missing Legible Logs for Cache Operations

**Problem:** Cache operations are silenced with `2>/dev/null`, so users can't see what's happening.

**Current code (entrypoint.sh line 400, 435):**
```bash
if cache_restore "bundle" "Gemfile.lock" "vendor/bundle" 2>/dev/null; then
  success "Ruby gems restored from S3 cache"
```

**Issue:** If cache_restore fails (credentials missing, network error, etc.), there's no error message.

**Fix:**
- Remove `2>/dev/null` from cache function calls
- Let cache_log messages show when CACHE_VERBOSE=true
- Add clear messages when caching is disabled

**Affected lines:**
- entrypoint.sh:400, 417, 435, 449 (all cache_restore and cache_save calls)

---

## 2. No Warning When Lockfile is Missing

**Problem:** When package-lock.json doesn't exist, npm install fails with no clear error.

**What happened:**
```
▶ Dependency Installation
────────────────────────────────────────
[sandbox] Session ended with exit code: 1
```

No indication that package-lock.json was missing or what failed.

**Fix:** Add lockfile existence check before attempting cache operations:

```bash
# Before cache_restore
if [ ! -f "package-lock.json" ]; then
  warn "package-lock.json not found - first run will be slower"
  info "Run 'npm install' locally to generate package-lock.json for caching"
fi
```

**Affected lines:**
- entrypoint.sh:441 (before npm operations)
- entrypoint.sh:406 (before bundle operations)

---

## 3. Cache Status Not Visible

**Problem:** CACHE_VERBOSE=true is set, but users don't see if caching is enabled/disabled.

**Fix:** Add cache status message at the beginning of Dependency Installation:

```bash
section "Dependency Installation"

# Show cache status
if cache_is_enabled; then
  info "S3 cache enabled: s3://${CACHE_S3_BUCKET}/ (endpoint: ${AWS_ENDPOINT_URL:-aws})"
else
  info "S3 cache disabled (credentials not configured)"
fi
```

**Affected lines:**
- entrypoint.sh:393 (after section "Dependency Installation")

---

## 4. Silent Failures During npm/bundle Install

**Problem:** If npm install or bundle install fails, script exits with no error context.

**Fix:** Add error handling with clear messages:

```bash
if ! npm install; then
  error "npm install failed"
  error "Check package.json and package-lock.json for issues"
  exit 1
fi
```

**Affected lines:**
- entrypoint.sh:412 (bundle install)
- entrypoint.sh:444 (npm install)

---

## 5. No Indication of Cache Hit/Miss

**Problem:** When cache_restore returns 1 (cache miss), it's silent. User doesn't know if it tried.

**Fix:** Add explicit cache miss message:

```bash
CACHE_RESTORED=false
if cache_restore "bundle" "Gemfile.lock" "vendor/bundle"; then
  success "Ruby gems restored from S3 cache"
  CACHE_RESTORED=true
else
  if cache_is_enabled; then
    info "Cache miss - will install and cache gems"
  fi
fi
```

**Affected lines:**
- entrypoint.sh:400 (Ruby cache restore)
- entrypoint.sh:435 (Node cache restore)

---

## 6. CACHE_VERBOSE Not Effective

**Problem:** CACHE_VERBOSE=true but logs are silenced with 2>/dev/null

**Fix:** Remove 2>/dev/null redirections and rely on CACHE_VERBOSE flag in cache_log

**Affected lines:**
- entrypoint.sh:400, 417, 435, 449

---

## Implementation Plan

1. Add cache status message at beginning of Dependency Installation
2. Remove all `2>/dev/null` from cache function calls
3. Add lockfile existence checks with helpful warnings
4. Add explicit cache miss messages
5. Add error handling for npm/bundle install failures
6. Test with:
   - Cache disabled (no AWS creds)
   - Cache enabled, cache miss
   - Cache enabled, cache hit
   - Missing lockfile

---

---

## 7. Incorrect bd sync Command

**Problem:** Using invalid flag `--import-only` that doesn't exist

**Current code (entrypoint.sh line 523):**
```bash
bd --import-only --rename-on-import sync
```

**Error:**
```
Error: unknown flag: --import-only
```

**Fix:** Use correct bd sync command:
```bash
bd sync --import
```

**Affected lines:**
- entrypoint.sh:523

---

## Priority

**CRITICAL (Blocking):**
- #7 (Fix bd sync command) - **BLOCKS EVERYTHING** - sandbox exits immediately

**High Priority:**
- #1 (Remove 2>/dev/null) - Critical for debugging
- #2 (Lockfile warnings) - Prevents confusing failures
- #4 (Error handling) - Prevents silent failures

**Medium Priority:**
- #3 (Cache status) - Nice to have visibility
- #5 (Cache miss messages) - Helpful but not critical

**Low Priority:**
- #6 (CACHE_VERBOSE) - Already works, just needs 2>/dev/null removed
