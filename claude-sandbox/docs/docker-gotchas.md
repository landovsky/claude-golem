# Docker Sandbox Gotchas & Solutions

Lessons learned while building the Claude Code sandbox environment.

---

## 1. Architecture-Specific Packages (Chrome)

**Problem:** Google Chrome only provides amd64 binaries. Build failed on ARM Mac with:
```
E: Unable to correct problems, you have held broken packages.
```

**Root Cause:** `google-chrome-stable` package is x86_64 only.

**Solution:** Use `chromium-browser` instead, which supports both amd64 and arm64:
```dockerfile
RUN apt-get update \
    && apt-get install -y chromium-browser chromium-chromedriver \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/chromium-browser /usr/bin/google-chrome
```

**Lesson:** Always consider multi-arch support when choosing base packages.

---

## 2. Ruby Build Dependencies

**Problem:** `ruby-install` failed with:
```
E: Package 'bison' has no installation candidate
E: Unable to locate package libgdbm-dev
```

**Root Cause:** `ruby-install` tries to install its own dependencies but apt lists were already purged. The tool expects dependencies available.

**Solution:** Pre-install all Ruby build dependencies before running `ruby-install`:
```dockerfile
RUN apt-get update && apt-get install -y \
    build-essential \
    bison \
    libgdbm-dev \
    libncurses-dev \
    autoconf \
    rustc \
    libreadline-dev \
    && rm -rf /var/lib/apt/lists/*

RUN ruby-install --system --no-install-deps ruby 3.4.1
```

**Lesson:** Install all build dependencies before cleaning apt lists. Use `--no-install-deps` to skip tool's internal dependency installation.

---

## 3. NPM Package Naming

**Problem:** Build failed with:
```
npm error 404  '@anthropic-ai/claude-code-mcp@*' is not in this registry.
```

**Root Cause:** I invented a package name that doesn't exist.

**Solution:** Only install packages that actually exist:
```dockerfile
RUN npm install -g @anthropic-ai/claude-code @beads/bd
```

Verify package exists before adding: `npm view @package/name version`

**Lesson:** Don't guess package names. Verify they exist in npm registry.

---

## 4. Packaging Claude Agents into Image

**Problem:** How to get `~/.claude/agents/` workflow system into the container?

**Options Considered:**
1. Mount at runtime - not portable to k8s
2. Copy at build time - requires build-time access
3. Clone from git - extra repo to maintain

**Solution:** Build script copies to staging area, then Docker COPY:
```bash
# bin/claude-sandbox build
mkdir -p docker/claude-sandbox/claude-config
cp -r ~/.claude/agents docker/claude-sandbox/claude-config/
docker build -t claude-sandbox:latest .
# Clean up but keep .gitkeep
find claude-config -type f ! -name '.gitkeep' -delete
```

```dockerfile
COPY --chown=claude:claude claude-config/ /home/claude/.claude/
```

**Gotcha:** Directory must always exist for Docker COPY. Keep `.gitkeep` file to ensure it.

**Lesson:** For build-time file injection, use a staging directory in build context that gets cleaned after build.

---

## 5. Authentication Without API Key

**Problem:** User has Claude Max subscription but no Anthropic API key.

**Solution:** Use OAuth token from `claude setup-token`:
```bash
claude setup-token
# Returns: sk-ant-oat01-... (valid 1 year)

export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..."
```

Set in container:
```yaml
environment:
  CLAUDE_CODE_OAUTH_TOKEN: ${CLAUDE_CODE_OAUTH_TOKEN}
```

**Lesson:** Claude Code supports both API keys and OAuth tokens. OAuth tokens let users leverage their existing subscriptions instead of pay-per-use API.

---

## 6. Docker COPY with Missing Directory

**Problem:** `docker compose build` auto-triggered but `claude-config/` didn't exist:
```
failed to compute cache key: "/claude-config": not found
```

**Root Cause:** Build script creates and then deletes `claude-config/`. If user runs `docker compose` directly instead of `bin/claude-sandbox build`, directory doesn't exist.

**Solution:** Always keep minimal directory structure:
```gitignore
# .gitignore
claude-config/*
!claude-config/.gitkeep
```

```bash
# Cleanup but preserve structure
find "$claude_config" -type f ! -name '.gitkeep' -delete
find "$claude_config" -mindepth 1 -type d -delete 2>/dev/null || true
```

**Lesson:** For COPY commands, ensure directory always exists even if empty. Use `.gitkeep` pattern.

---

## 7. Git Clone in Non-Empty Directory

**Problem:** `git clone` failed with:
```
fatal: destination path '.' already exists and is not an empty directory.
```

**Root Cause Chain:**
1. docker-compose.yml has `node_modules` volume mount: `- claude_node_modules:/workspace/node_modules`
2. Docker creates parent directory `/workspace/node_modules/` before container starts
3. This makes `/workspace` non-empty
4. Git refuses to clone into non-empty directory

**Failed Attempts:**
1. ✗ Clear workspace in entrypoint - didn't account for volume mounts
2. ✗ Remove persistent workspace volume - but node_modules volume still created directory
3. ✗ Clear all files except node_modules - volume mount happens AFTER entrypoint logic

**Working Solution:** Clone to temp directory, then move:
```bash
# Clone to temp dir
CLONE_DIR=$(mktemp -d)
git clone --branch "${REPO_BRANCH:-main}" "$AUTH_URL" "$CLONE_DIR"

# Clear workspace (preserving volume mounts)
find . -maxdepth 1 ! -name '.' ! -name '..' ! -name 'node_modules' -exec rm -rf {} + 2>/dev/null || true

# Move repo contents
shopt -s dotglob
mv "$CLONE_DIR"/* . 2>/dev/null || true
rmdir "$CLONE_DIR"
```

**Alternative Considered:** Remove node_modules volume entirely, but this slows down repeated runs since npm install runs every time.

**Lesson:** Git clone won't work with volume mounts in target directory. Clone to temp location and move, or clone to subdirectory and switch to it.

---

## 8. Docker Layer Caching Confusion

**Problem:** Modified `entrypoint.sh` but build showed `CACHED` for that layer.

**Root Cause:** Docker caches based on file checksums in build context. If checksum matches, layer is reused.

**When This Happens:**
- File timestamp changed but content didn't
- Build context includes files you didn't mean to include
- Previous build had identical file

**Solution:** Force rebuild without cache when debugging:
```bash
docker build --no-cache -t image:latest .
```

**Lesson:** During debugging, use `--no-cache` to ensure fresh builds. For production, leverage caching for speed.

---

## 9. GitHub Token Permissions

**Problem:** Repository cloning failed with:
```
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/landovsky/hriste.git/'
```

**Root Cause:** GitHub token lacked the necessary permissions to clone repository code.

**Solution:** GitHub token must have **Contents** repository permission:

**For Fine-Grained Tokens:**
1. Go to https://github.com/settings/tokens
2. Edit token → Repository permissions → **Contents** → Set to **Read and Write** (or Read-only)

**For Classic Tokens:**
1. Generate new token (classic)
2. Select the **`repo`** scope (full control of private repositories)

**Lesson:** Fine-grained tokens need explicit **Contents** permission for git operations. Classic tokens with `repo` scope include everything.

---

## 10. Docker Volume Permissions

**Problem:** Both bundle and node_modules installation failed with:
```
There was an error while trying to create `/home/claude/.bundle/ruby/3.4.0`.
npm error code EACCES
npm error path /workspace/node_modules/@alloc
npm error Error: EACCES: permission denied
```

**Root Cause:** Docker named volumes are created by the Docker daemon (as root). When mounted to a container running as a non-root user (`claude`), the mount point and its contents inherit root ownership.

**Why chmod/chown Didn't Work:**
- Can't `chmod` the mount point itself from inside the container
- Can't `chown` without root privileges (and `sudo` not available)
- Volume mount happens before user code runs

**Solution:** Removed separate persistent volumes for bundle and node_modules. Used single workspace volume instead:

```yaml
# BEFORE (doesn't work):
volumes:
  - claude_bundle:/home/claude/.bundle
  - claude_node_modules:/workspace/node_modules

# AFTER (works):
volumes:
  - claude_workspace:/workspace  # Single workspace volume
```

By letting gems/packages install to the workspace, they're created with correct ownership from the start.

**Lesson:** Volume mount points are owned by whoever creates the volume (usually root). Either run as root (bad for security), use bind mounts instead of volumes, or structure your app to write inside the volume, not to the mount point itself.

---

## 11. Node.js Version Mismatch

**Problem:**
```
npm warn EBADENGINE Unsupported engine {
npm warn EBADENGINE   required: { node: '^22.11.0' },
npm warn EBADENGINE   current: { node: 'v20.20.0' }
```

**Root Cause:** Dockerfile installed Node 20 LTS, but `package.json` requires Node 22.

**Solution:** Update Dockerfile to match application requirements:
```dockerfile
# BEFORE:
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

# AFTER:
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
```

**Lesson:** Always check `package.json` engines field, `.nvmrc`, or `.node-version` files when choosing Node version for Docker image.

---

## 12. Slow Dependency Installation

**Problem:** Every sandbox run took 2-3 minutes installing dependencies, even when nothing changed.

**Root Cause:** Entrypoint unconditionally ran `bundle install` and `npm install` on every start.

**Solution:** Implemented smart caching with checksum markers:
```bash
# Check if Gemfile.lock changed
GEMFILE_CHECKSUM=$(md5sum Gemfile.lock | cut -d' ' -f1)
if [ ! -f ".bundle/.installed" ] || \
   [ "$(cat .bundle/.installed 2>/dev/null)" != "$GEMFILE_CHECKSUM" ]; then
  bundle install
  echo "$GEMFILE_CHECKSUM" > .bundle/.installed
else
  log "Ruby dependencies already installed (skipping)"
fi
```

**Results:**
- First run: 2-3 minutes (installs everything)
- Subsequent runs: ~30 seconds (skips installation)
- After lockfile change: Reinstalls automatically

**Trade-off:** Marked with `QUICK FIX FOR LOCAL TESTING` comments. For production/k8s, remove workspace volume and caching to ensure fresh installs every run.

**Lesson:** Local dev benefits from caching, production benefits from reproducibility. Make the trade-off explicit and reversible.

---

## 13. Stale Cache Markers

**Problem:**
```
bundler: command not found: rails
Install missing gem executables with `bundle install`
```

Despite logs saying "Ruby dependencies already installed (skipping)".

**Root Cause:** Marker files (`.bundle/.installed`) persisted but actual gems were lost when workspace volume was recreated.

**Solution:** Enhanced validation to check both marker AND actual availability:
```bash
# BEFORE (only checked marker):
if [ ! -f ".bundle/.installed" ] || [ "$(cat .bundle/.installed)" != "$CHECKSUM" ]; then
  bundle install
fi

# AFTER (checks marker AND gems work):
if [ ! -f ".bundle/.installed" ] || \
   [ "$(cat .bundle/.installed)" != "$CHECKSUM" ] || \
   ! bundle exec ruby -e "exit 0" 2>/dev/null; then
  bundle install
fi
```

The `bundle exec ruby -e "exit 0"` test verifies bundler can actually execute commands.

**Prevention:**
- Add marker files to `.gitignore`
- Run `docker compose down -v` when cache seems stale
- Validate cached resources exist, not just their markers

**Lesson:** Never trust metadata alone. Verify the actual resource is available.

---

## 14. PostGIS Platform Mismatch

**Problem:**
```
! postgres The requested image's platform (linux/amd64) does not match
  the detected host platform (linux/arm64/v8)
```

**Root Cause:** Running on Apple Silicon (arm64) but Docker pulled amd64 version of PostGIS, which runs through emulation (slower).

**Solution:** Specify platform explicitly in docker-compose.yml:
```yaml
services:
  postgres:
    image: postgis/postgis:16-3.4-alpine
    platform: linux/arm64  # Use native architecture on Apple Silicon
```

For Intel Macs, use `platform: linux/amd64`.

**Lesson:** Multi-arch images don't always auto-detect correctly. Explicitly set platform for best performance, especially for databases.

---

## 15. Image Naming for Forked Repositories

**Problem:** Every fork had to manually search-and-replace `landovsky` with their Docker Hub username across multiple files (GitHub Actions, shell scripts, docs).

**Solution:** Parameterize based on repository owner:
- GitHub Actions: Use `${{ github.repository_owner }}`
- Shell scripts: Extract from `git remote get-url origin`
- Environment variable: `CLAUDE_IMAGE` overrides everything

**Lesson:** Use platform-provided context (GitHub variables, git remotes) rather than hardcoding usernames. Makes forks work out-of-the-box.

---

## Summary of Key Patterns

### Build-Time File Injection
```bash
# In build script
mkdir -p staging-dir
cp files staging-dir/
docker build .
# Clean but keep structure
find staging-dir -type f ! -name '.gitkeep' -delete
```

### Handling Volume Mounts with Git
```bash
# Clone to temp, move to workspace
CLONE_DIR=$(mktemp -d)
git clone "$URL" "$CLONE_DIR"
find . -maxdepth 1 ! -name '.' ! -name '..' ! -name 'volume-dir' -exec rm -rf {} +
shopt -s dotglob
mv "$CLONE_DIR"/* .
```

### Multi-Arch Package Selection
```dockerfile
# Bad: x86 only
RUN apt-get install google-chrome-stable

# Good: multi-arch
RUN apt-get install chromium-browser
```

### Dependency Management
```dockerfile
# Install ALL dependencies before cleanup
RUN apt-get update && apt-get install -y \
    dep1 dep2 dep3 \
    && rm -rf /var/lib/apt/lists/*

# Then use tools with --no-install-deps
RUN tool-install --no-install-deps package
```

### Smart Caching with Validation
```bash
# Cache with checksum + existence validation
CHECKSUM=$(md5sum lockfile | cut -d' ' -f1)
if [ ! -f ".cache/.installed" ] || \
   [ "$(cat .cache/.installed)" != "$CHECKSUM" ] || \
   ! command-to-verify 2>/dev/null; then
  install-dependencies
  echo "$CHECKSUM" > .cache/.installed
fi
```

### Volume Permission Management
```yaml
# Avoid separate volumes for directories that need write access
# Use single parent volume instead:
volumes:
  - app_workspace:/app  # Good: user writes inside volume
  # Not: - app_gems:/app/.bundle  # Bad: mount point permission issues
```

---

## Debugging Checklist

When Docker build/run fails:

**Build Issues:**
1. **Check architecture compatibility** - amd64 vs arm64
2. **Verify package names** - `npm view`, `apt-cache show`
3. **Inspect build context** - what files are actually sent to Docker?
4. **Check layer caching** - use `--no-cache` when debugging
5. **Test in container** - `docker run --rm --entrypoint bash image -c "commands"`
6. **Check what's actually in the image** - `docker run --entrypoint cat image /path/to/file`

**Runtime Issues:**
1. **Volume permissions** - check ownership with `docker run --rm -v volume:/data alpine ls -la /data`
2. **Cache staleness** - remove volumes: `docker compose down -v`
3. **Token permissions** - verify GitHub token has Contents scope
4. **Platform mismatch** - check `docker inspect image | grep Architecture`
5. **Missing dependencies** - exec into running container: `docker exec -it container bash`
6. **Verify installation** - don't just check markers, test actual commands work

---

## Quick Reference Commands

### Clean Slate (Fix Most Issues)
```bash
# Remove all volumes and start fresh
cd docker/claude-sandbox && docker compose down -v

# Rebuild image
cd ../.. && bin/claude-sandbox build

# Run sandbox
bin/claude-sandbox local "your task here"
```

### Debugging Specific Issues

**Check volume contents:**
```bash
docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 ls -la /workspace
```

**Check volume ownership:**
```bash
docker run --rm -v claude-sandbox_claude_workspace:/workspace ubuntu:24.04 \
  sh -c "ls -la /workspace && stat -c '%U:%G' /workspace"
```

**List all volumes:**
```bash
docker volume ls | grep claude-sandbox
```

**Remove specific volume:**
```bash
docker volume rm claude-sandbox_claude_workspace
```

**Test bundle without cache:**
```bash
# Remove marker to force reinstall
docker exec -it claude-sandbox-claude-run rm -f .bundle/.installed
```

**Check image architecture:**
```bash
docker inspect claude-sandbox:latest | grep Architecture
docker inspect postgis/postgis:16-3.4-alpine | grep Architecture
```

**Verify GitHub token:**
```bash
# Test token has Contents permission
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/landovsky/hriste
```

---

## Resources

- [Multi-arch Docker builds](https://docs.docker.com/build/building/multi-platform/)
- [Docker layer caching](https://docs.docker.com/build/cache/)
- [Docker volume permissions](https://docs.docker.com/storage/volumes/#use-a-volume-with-docker-compose)
- [Claude Code authentication](https://code.claude.com/docs/en/settings)
- [GitHub token scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps)
- [Git clone into non-empty directory workarounds](https://stackoverflow.com/questions/2411031)
