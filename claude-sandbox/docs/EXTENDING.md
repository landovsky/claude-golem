# Extending Claude Sandbox

This guide shows how to add new capabilities to claude-sandbox. Each section follows the pattern: **What to add → Where to modify → Example**.

---

## Adding a New Language (e.g., Python, Node.js, Go)

### What You Need

1. **Language runtime** in container image
2. **Project detection** logic
3. **Dependency installation** in entrypoint
4. **(Optional) Version management** like Ruby versions

### Files to Modify

| File | Change |
|------|--------|
| `Dockerfile` | Install language runtime and package managers |
| `entrypoint.sh` | Add project detection (check for `requirements.txt`, `package.json`, etc.) |
| `entrypoint.sh` | Add dependency installation (`pip install`, `npm install`) |
| `ruby-versions.yaml` | (Optional) Create equivalent for new language |
| `bin/claude-sandbox` | (Optional) Add version auto-detection |

### Example: Adding Python Support

**1. Dockerfile** - Install Python
```dockerfile
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv
```

**2. entrypoint.sh** - Detect Python projects
```bash
# Detect Python project
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    PROJECT_TYPE="python"
    log "Detected Python project"
fi
```

**3. entrypoint.sh** - Install dependencies
```bash
if [ "$PROJECT_TYPE" = "python" ] && [ -f "requirements.txt" ]; then
    log "Installing Python dependencies..."
    pip install -r requirements.txt
fi
```

**4. (Optional) Python version management**
- Create `python-versions.yaml` similar to `ruby-versions.yaml`
- Add `auto_detect_python_version()` in `bin/claude-sandbox`
- Build multiple images with different Python versions

---

## Adding a New Database (e.g., MongoDB, MySQL)

### What You Need

1. **Database sidecar** container
2. **Service detection** pattern
3. **Client tools** in main container
4. **Connection string** environment variable

### Files to Modify

| File | Change |
|------|--------|
| `docker-compose.yml` | Add database service with profile |
| `detect-services.sh` | Add detection pattern for dependencies |
| `bin/claude-sandbox` | Add to K8s YAML generation |
| `Dockerfile` | Install database client tools |
| `entrypoint.sh` | Add readiness check, set connection string |

### Example: Adding MongoDB

**1. docker-compose.yml** - Add MongoDB service
```yaml
mongodb:
  profiles: ["with-mongodb"]
  image: mongo:7
  environment:
    MONGO_INITDB_ROOT_USERNAME: claude
    MONGO_INITDB_ROOT_PASSWORD: claude
  ports:
    - "27017:27017"
  healthcheck:
    test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
    interval: 5s
    retries: 5
```

**2. detect-services.sh** - Detect MongoDB usage
```bash
# Check for MongoDB in Gemfile
if echo "$gemfile_content" | grep -q "gem ['\"]mongoid['\"]"; then
    services="$services with-mongodb"
fi

# Check for MongoDB in package.json
if echo "$package_content" | grep -q '"mongodb"'; then
    services="$services with-mongodb"
fi
```

**3. Dockerfile** - Install MongoDB client
```dockerfile
RUN apt-get install -y mongodb-clients
```

**4. entrypoint.sh** - Readiness check
```bash
if [ "$NEEDS_MONGODB" = "true" ]; then
    log "Waiting for MongoDB..."
    for i in $(seq 1 30); do
        if mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
            log "MongoDB ready"
            break
        fi
        sleep 1
    done
fi
```

**5. entrypoint.sh** - Set connection string
```bash
export MONGODB_URL="mongodb://claude:claude@localhost:27017/sandbox_development"
```

**6. bin/claude-sandbox** - Add to K8s generation
```bash
# In generate_k8s_job_yaml() function
if [ "$needs_mongodb" = "true" ]; then
    # Add MongoDB sidecar to YAML
fi
```

---

## Adding a New Service (e.g., Elasticsearch, RabbitMQ)

### Pattern

Same as database above, but:
- Adjust health check command for the service
- Set appropriate connection string format
- May need additional configuration files

### Example: Elasticsearch

```bash
# detect-services.sh
if echo "$gemfile_content" | grep -q "gem ['\"]elasticsearch['\"]"; then
    services="$services with-elasticsearch"
fi

# docker-compose.yml
elasticsearch:
  profiles: ["with-elasticsearch"]
  image: elasticsearch:8.11.0
  environment:
    - discovery.type=single-node
    - xpack.security.enabled=false

# entrypoint.sh
export ELASTICSEARCH_URL="http://localhost:9200"
```

---

## Adding a New Orchestration Platform (e.g., AWS ECS, Cloud Run)

### What You Need

1. **New CLI command** (e.g., `bin/claude-sandbox ecs "task"`)
2. **Platform-specific deployment logic**
3. **Service definitions** for the platform
4. **Secrets management** integration

### Files to Modify

| File | Change |
|------|--------|
| `bin/claude-sandbox` | Add new `cmd_ecs()` function |
| `bin/claude-sandbox` | Add ECS deployment logic |
| `docs/` | Add setup guide for new platform |

### Example: AWS ECS (Conceptual)

```bash
# bin/claude-sandbox

cmd_ecs() {
    local task="$1"

    # Detect services
    local services=$(detect_services)

    # Generate ECS task definition JSON
    generate_ecs_task_definition "$services" > /tmp/task-def.json

    # Create/update ECS task
    aws ecs register-task-definition --cli-input-json file:///tmp/task-def.json

    # Run task
    aws ecs run-task \
        --cluster claude-sandbox \
        --task-definition claude-sandbox-task \
        --overrides "$(generate_ecs_overrides "$task")"
}
```

---

## Modifying Build Process

### Adding Build Arguments

**Use case:** Parameterize Dockerfile builds

**Files:** `Dockerfile`, `bin/claude-sandbox` (`cmd_build()`)

**Example:** Add Node.js version argument
```dockerfile
ARG NODE_VERSION=22
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
```

```bash
# bin/claude-sandbox cmd_build()
docker build --build-arg NODE_VERSION=20 -t claude-sandbox:node20
```

---

## Testing Your Changes

### Local Testing

```bash
# Build new image
bin/claude-sandbox build

# Test with a sample repo
bin/claude-sandbox local "list all Ruby files"

# Check logs
docker compose logs claude
```

### Remote Testing

```bash
# Push new image
bin/claude-sandbox push

# Test on cluster
bin/claude-sandbox remote "list all Ruby files"

# Check logs
bin/claude-sandbox logs
```

### Validation Checklist

- [ ] Service detection works (check `detect-services.sh` output)
- [ ] Dependencies install successfully (check entrypoint logs)
- [ ] Service is reachable (check connection strings)
- [ ] Claude can use the service (run a task that requires it)
- [ ] Cleanup works (no zombie containers/jobs)

---

## Common Patterns

### Pattern: Optional Service

If service might not always be needed:
1. Add to both `docker-compose.yml` (with profile) and K8s YAML
2. Use conditional detection in `detect-services.sh`
3. Provide graceful fallback if service unavailable

### Pattern: Required Tool

If tool must always be present:
1. Install in `Dockerfile` (not in entrypoint)
2. No conditional logic needed
3. Increases image size but simplifies runtime

### Pattern: Configuration File

If service needs config file:
1. Check for config file in repo first
2. Generate default if missing
3. Document expected location

---

## Adding S3 Caching for New Package Managers

### Overview

The sandbox includes a reusable S3 caching system (`lib/cache-manager.sh`) that works with any package manager. Ruby gems and Node packages are already supported. Adding support for other package managers (pip, cargo, composer, etc.) follows a simple pattern.

### What You Need

1. **Lockfile** that changes when dependencies change (e.g., `requirements.txt`, `Cargo.lock`)
2. **Dependency directory** to cache (e.g., `venv/`, `target/`)
3. **Integration** in entrypoint.sh

### How the Cache Manager Works

The cache manager provides four main functions:

```bash
# Check if caching is enabled (has AWS credentials + S3 bucket)
cache_is_enabled

# Restore dependencies from S3 (returns 0 on success, 1 on miss)
cache_restore "cache_type" "lockfile_path" "target_dir"

# Save dependencies to S3
cache_save "cache_type" "lockfile_path" "source_dir"

# Optional: Prune old caches
cache_prune "cache_type" 30  # Keep last 30 days
```

**Cache key format:** `s3://bucket/prefix/{cache_type}-{lockfile_hash}.tar.gz`

- `cache_type`: Identifies the package manager (e.g., "bundle", "npm", "pip")
- `lockfile_hash`: First 16 chars of sha256 hash of lockfile
- `.tar.gz` extension if compression enabled, `.tar` otherwise

### Example: Adding pip (Python) Caching

**Step 1:** Source the cache manager in entrypoint.sh (already done)

```bash
# Load cache manager
if [ -f /usr/local/lib/cache-manager.sh ]; then
  source /usr/local/lib/cache-manager.sh
fi
```

**Step 2:** Integrate with dependency installation

```bash
# Install Python dependencies if needed
PACKAGES_NEED_INSTALL=false
if [ "$HAS_PYTHON" = true ]; then
  # Create venv if needed
  if [ ! -d "venv" ]; then
    python3 -m venv venv
  fi

  # Try to restore from S3 cache first
  CACHE_RESTORED=false
  if cache_restore "pip" "requirements.txt" "venv" 2>/dev/null; then
    success "Python packages restored from S3 cache"
    CACHE_RESTORED=true
  fi

  # Verify cache or install if needed
  REQUIREMENTS_CHECKSUM=$(sha256sum requirements.txt 2>/dev/null | cut -d' ' -f1)
  if [ ! -f "venv/.installed" ] || [ "$(cat venv/.installed 2>/dev/null)" != "$REQUIREMENTS_CHECKSUM" ]; then
    action "Installing Python packages..."
    source venv/bin/activate
    pip install -r requirements.txt
    PACKAGES_NEED_INSTALL=true
    success "Python packages installed"

    # Save to S3 cache if successful
    if cache_save "pip" "requirements.txt" "venv" 2>/dev/null; then
      info "Python packages saved to S3 cache"
    fi
  else
    if [ "$CACHE_RESTORED" = false ]; then
      info "Python packages up to date (using local cache)"
    fi
  fi
fi

# Mark dependencies as successfully installed
if [ "$PACKAGES_NEED_INSTALL" = true ]; then
  echo "$REQUIREMENTS_CHECKSUM" > venv/.installed
fi
```

### Pattern Breakdown

The pattern for any package manager follows these steps:

1. **Restore from cache:** Try `cache_restore` with lockfile hash
   - On cache hit: Skip to verification
   - On cache miss: Proceed to installation

2. **Verify or install:** Check if local cache is valid
   - Compare stored checksum with current lockfile hash
   - Verify dependencies actually work (e.g., `bundle exec ruby -e "exit 0"`)
   - If invalid/missing: Run package manager install

3. **Save to cache:** After successful install, call `cache_save`
   - Uploads dependency directory to S3
   - Only if not already cached (cache_save checks this)

4. **Mark as installed:** Write checksum to marker file
   - `.bundle/.installed` for Ruby gems
   - `node_modules/.installed` for Node packages
   - `venv/.installed` for Python packages
   - Pattern: `{dependency_dir}/.installed`

### Configuration

Cache manager respects these environment variables:

- `AWS_ACCESS_KEY_ID` - AWS access key (required)
- `AWS_SECRET_ACCESS_KEY` - AWS secret key (required)
- `AWS_REGION` - AWS region (default: us-east-1)
- `CACHE_S3_BUCKET` - S3 bucket name (required)
- `CACHE_S3_PREFIX` - Key prefix (default: claude-sandbox-cache)
- `CACHE_COMPRESSION` - Enable gzip (default: true)
- `CACHE_VERBOSE` - Verbose logging (default: false)

### Error Handling

The cache manager is designed to fail gracefully:

- If AWS credentials missing: Silently disabled, falls back to local-only caching
- If S3 bucket doesn't exist: Operations fail silently, doesn't block install
- If network timeout: Downloads/uploads timeout after 5 minutes
- All errors written to stderr (captured by `2>/dev/null` in entrypoint)

This ensures caching failures never block builds - they just run slower.

### Testing

Test your cache integration:

```bash
# Build image with cache manager
bin/claude-sandbox build

# Configure S3 caching (local)
cat >> .env.claude-sandbox <<EOF
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
AWS_REGION=us-east-1
CACHE_S3_BUCKET=your-bucket
EOF

# First run (cache miss, will install and save)
bin/claude-sandbox local "list files"

# Check S3 for cached artifact
aws s3 ls s3://your-bucket/claude-sandbox-cache/

# Second run (cache hit, should restore from S3)
bin/claude-sandbox local "list files"
# Look for "restored from S3 cache" in logs
```

### Cache Maintenance

Optional: Add periodic cache pruning to remove old entries:

```bash
# In entrypoint.sh or separate maintenance job
if [ "${CACHE_PRUNE_ENABLED:-false}" = "true" ]; then
  cache_prune "bundle" 30  # Keep last 30 days
  cache_prune "npm" 30
  cache_prune "pip" 30
fi
```

**Note:** Cache pruning is expensive (lists all S3 objects). Consider running as a separate scheduled job rather than in every entrypoint run.

---

## Getting Help

- **Architecture:** See `docs/ARCHITECTURE.md` for system overview
- **Decisions:** See `docs/ARCHITECTURE-DECISIONS.md` for context on design choices
- **Examples:** Study existing services (PostgreSQL, Redis) as templates
- **Issues:** Check existing issues or create new one

---

**Tip:** Start by copying an existing service implementation (e.g., PostgreSQL) and modifying it for your needs. The patterns are consistent across all services.
