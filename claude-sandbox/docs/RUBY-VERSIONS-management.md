# Ruby Version Management

The claude-sandbox supports multiple Ruby versions through Docker image tagging and automatic version detection from `.ruby-version` files.

## How It Works

### Automatic Detection

When you run `bin/claude-sandbox local` or `bin/claude-sandbox remote`, the launcher:

1. **Looks for `.ruby-version`** in your repository
   - For local repositories: reads directly from the filesystem
   - For remote repositories: uses `git archive` to fetch the file

2. **Extracts major.minor version**
   - `3.3.1` → `3.3`
   - `3.4` → `3.4`
   - Ignores patch versions (all 3.3.x use the same `ruby-3.3` image)

3. **Validates against supported versions** in `ruby-versions.yaml`
   - If supported: uses `claude-sandbox:ruby-X.Y` image
   - If not supported: shows error with list of available versions
   - If no `.ruby-version`: uses default (currently 3.4)

4. **Selects Docker image**
   - Local: passes `IMAGE_TAG` to docker-compose
   - Remote: appends tag to `CLAUDE_IMAGE` for Kubernetes

### Supported Versions

Current versions (see `ruby-versions.yaml` for the source of truth):

| Major.Minor | Patch Version | Image Tag |
|-------------|---------------|-----------|
| 3.2 | 3.2.6 | `claude-sandbox:ruby-3.2` |
| 3.3 | 3.3.6 | `claude-sandbox:ruby-3.3` |
| 3.4 | 3.4.7 | `claude-sandbox:ruby-3.4` |

The `claude-sandbox:latest` tag always points to the highest version (currently Ruby 3.4).

## Configuration File

The `ruby-versions.yaml` file defines all supported versions:

```yaml
# Ruby versions supported by claude-sandbox
versions:
  "3.2": "3.2.6"  # Major.minor: full patch version
  "3.3": "3.3.6"
  "3.4": "3.4.7"

default: "3.4"    # Used when no .ruby-version exists
```

### Format

- **Keys** (`"3.2"`, `"3.3"`, etc.): Major.minor versions used in image tags
- **Values** (`"3.2.6"`, etc.): Full patch versions passed to `ruby-install`
- **Default**: The version to use when no `.ruby-version` is found

## Building Images

### Build All Versions

```bash
bin/claude-sandbox build
```

This builds one image for each version in `ruby-versions.yaml`:
- `claude-sandbox:ruby-3.2`
- `claude-sandbox:ruby-3.3`
- `claude-sandbox:ruby-3.4`
- `claude-sandbox:latest` (tagged to highest version)

**Note:** Building takes 5-10 minutes per Ruby version.

### Build Only Specific Versions

If you only need certain Ruby versions, temporarily edit `ruby-versions.yaml` to include only those versions before building:

```yaml
versions:
  "3.4": "3.4.7"  # Only build Ruby 3.4
default: "3.4"
```

Then run `bin/claude-sandbox build`.

## Manual Override

### Local Runs

Force a specific Ruby version by setting `IMAGE_TAG`:

```bash
export IMAGE_TAG=ruby-3.2
bin/claude-sandbox local "implement feature X"
```

### Remote Runs (Kubernetes)

Include the tag in `CLAUDE_IMAGE`:

```bash
export CLAUDE_IMAGE=landovsky/claude-sandbox:ruby-3.2
bin/claude-sandbox remote "implement feature X"
```

Or set `IMAGE_TAG` and let the launcher append it:

```bash
export IMAGE_TAG=ruby-3.2
bin/claude-sandbox remote "implement feature X"
```

### Docker Compose Directly

```bash
IMAGE_TAG=ruby-3.2 docker compose run --rm claude
```

## Adding New Ruby Versions

1. **Update `ruby-versions.yaml`**

   ```yaml
   versions:
     "3.2": "3.2.6"
     "3.3": "3.3.6"
     "3.4": "3.4.7"
     "3.5": "3.5.0"  # Add new version
   default: "3.5"    # Update default if desired
   ```

2. **Rebuild images**

   ```bash
   bin/claude-sandbox build
   ```

   This builds all versions including the new one.

3. **Push to registry** (if using remote execution)

   ```bash
   export CLAUDE_REGISTRY=ghcr.io/username
   bin/claude-sandbox push
   ```

   This pushes all version tags to the registry.

## Troubleshooting

### "Ruby X.Y is not supported"

**Problem:** Your project's `.ruby-version` specifies a version not in `ruby-versions.yaml`.

**Solution:**
1. Check `ruby-versions.yaml` for supported versions
2. Either:
   - Update `.ruby-version` to use a supported version, or
   - Add the version to `ruby-versions.yaml` and rebuild images

**Example error:**
```
[claude-sandbox] Ruby 3.1 is not supported
[claude-sandbox] Supported versions:
  - Ruby 3.2 (3.2.6)
  - Ruby 3.3 (3.3.6)
  - Ruby 3.4 (3.4.7)

To add support for Ruby 3.1, edit ruby-versions.yaml and rebuild images with:
  bin/claude-sandbox build
```

### "Invalid .ruby-version format"

**Problem:** The `.ruby-version` file contains invalid content.

**Solution:** Ensure `.ruby-version` contains only a version number like:
- `3.3` (major.minor)
- `3.3.1` (major.minor.patch)

Not:
- `ruby-3.3` (no prefix)
- `3` (must include minor version)

### Image not found

**Problem:** `Image claude-sandbox:ruby-3.3 not found`

**Solution:** Build the images first:
```bash
bin/claude-sandbox build
```

### Version detection not working

**Problem:** Sandbox uses wrong Ruby version despite `.ruby-version` file.

**Debug steps:**
1. Check if `.ruby-version` is committed to git (not in `.gitignore`)
2. Verify `REPO_URL` points to the correct repository
3. For remote repos, ensure `git archive` works:
   ```bash
   git archive --remote=YOUR_REPO_URL HEAD .ruby-version | tar -xO
   ```
4. Check for manual `IMAGE_TAG` override in your environment

### Build time too long

**Problem:** Building all Ruby versions takes too long.

**Solution:** Build only the versions you need (see "Build Only Specific Versions" above).

### Registry push fails

**Problem:** Cannot push images to registry.

**Solution:**
1. Ensure you're logged in: `docker login ghcr.io`
2. Verify `CLAUDE_REGISTRY` is set correctly
3. Check you have push permissions to the registry

## Architecture Notes

### Why Major.Minor Tags?

Patch versions (e.g., 3.3.0 vs 3.3.1) rarely have breaking changes. Using major.minor tags:
- Reduces the number of images to build and maintain
- Makes it easier for projects to stay current with security patches
- Matches how most Ruby projects specify versions in `.ruby-version`

### Image Tagging Strategy

- **`ruby-X.Y`**: Specific major.minor version (e.g., `ruby-3.3`)
- **`latest`**: Points to the highest Ruby version (currently 3.4)

This allows:
- Explicit version selection when needed
- Backward compatibility with existing workflows using `:latest`
- Easy upgrades by updating `ruby-versions.yaml`

### Detection Timing

Version detection happens in the **launcher** (before container start), not in the entrypoint:
- The `.ruby-version` file is in the repository, which doesn't exist until the container clones it
- The launcher can access the file via `git archive` or local filesystem
- This allows selecting the correct image before `docker compose run`

### git archive Approach

For remote repositories, we use `git archive --remote=REPO_URL HEAD .ruby-version` because:
- Avoids a full clone just to read one file
- Works with both local paths and remote URLs
- Fails gracefully if the file doesn't exist
- Respects branch selection (uses current HEAD)

For local repositories, we read the file directly from the filesystem.
