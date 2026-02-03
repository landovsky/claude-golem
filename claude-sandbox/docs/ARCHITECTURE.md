# Claude Sandbox - Architecture

## Table of Contents
1. [Overview & Objectives](#overview--objectives)
2. [System Context](#system-context)
3. [Architecture](#architecture)
4. [Deployment Models](#deployment-models)
5. [Key Mechanisms](#key-mechanisms)
6. [Security Model](#security-model)

---

## Overview & Objectives

### What is Claude Sandbox?

Claude Sandbox enables **autonomous Claude Code execution** in isolated, reproducible Docker/Kubernetes environments. It provides full automation capabilities while maintaining safety through containerization, fresh clones, and branch protection.

### Why it Exists

**Problems Solved:**
- Running Claude Code with full permissions (`--dangerously-skip-permissions`) safely
- Reproducible environments across local development and production
- Automatic service provisioning (PostgreSQL, Redis, etc.)
- Secure secrets management in automation contexts
- Autonomous PR creation and code changes without manual intervention

### Design Goals

- **Isolation:** Each run starts from a fresh repository clone in a container
- **Reproducibility:** Same task produces same results locally and remotely
- **Safety:** Multiple protection layers (container, safe-git, branch protection)
- **Efficiency:** Conditional service provisioning based on project needs
- **Simplicity:** Single CLI command for complex orchestration

### Non-Goals

- **Not a general-purpose CI/CD system** - Optimized for Claude Code workflows
- **Not for interactive development** - Designed for autonomous execution
- **Not language-agnostic (yet)** - Currently optimized for Rails; extensible to others

---

## System Context

### What's Inside the System Boundary

- CLI orchestration (`bin/claude-sandbox`)
- Container images (Ubuntu + Ruby + Node + tools)
- Runtime bootstrap (`entrypoint.sh`)
- Safety mechanisms (`safe-git`)
- Service auto-detection (`detect-services.sh`)

### External Dependencies

| Service | Purpose | Authentication |
|---------|---------|----------------|
| **GitHub** | Repository source & push target | GITHUB_TOKEN |
| **Claude API** | LLM execution | OAuth token or API key |
| **Docker** | Local containerization | N/A (local daemon) |
| **Kubernetes** | Remote orchestration | kubeconfig |
| **Docker Registry** | Image distribution | Registry credentials |
| **Telegram** (optional) | Completion notifications | Bot token |

### Data Flow

```
User Command
    ↓
CLI detects: repo, branch, Ruby version, services needed
    ↓
Orchestrator (Docker Compose or Kubernetes) creates container + sidecars
    ↓
Container: entrypoint.sh clones repo, installs deps, prepares DB
    ↓
Claude Code executes task with full permissions
    ↓
Changes pushed to GitHub (via safe-git wrapper)
    ↓
Notification sent (Telegram)
```

---

## Architecture

### Visual Overview

![Architecture Diagram](architecture.png)

> **Diagram:** Component architecture showing 7 layers, local/remote paths, and external services. Color-coded by layer type.
>
> **Generate diagram:** `plantuml -tpng docs/architecture.puml` (requires Graphviz installed)

### The 7 Layers

#### **Layer 1: Client / CLI**
**Responsibility:** Command orchestration and environment detection

**Key Components:**
- `bin/claude-sandbox` - Main CLI (commands: local, remote, build, push, logs, clean)
- `detect-services.sh` - Scans `Gemfile`/`package.json` for dependencies
- `ruby-versions.yaml` - Ruby version mapping configuration

**Functions:** `auto_detect_repo()`, `auto_detect_branch()`, `auto_detect_ruby_version()`, `check_env()`

---

#### **Layer 2: Orchestration**

**2A: Local (Docker Compose)**
- Profile-based service composition (claude, with-postgres, with-redis, with-mysql, with-sqlite)
- Configuration: `docker-compose.yml`
- Networking: Bridge network, DNS-based service discovery

**2B: Remote (Kubernetes)**
- Dynamic YAML generation with conditional sidecars
- Function: `generate_k8s_job_yaml()`
- Job lifecycle: TTL 3600s, no retry (BackoffLimit: 0)
- Secret injection via `kubectl` from K8s secrets

---

#### **Layer 3: Container Image**
**Responsibility:** Pre-built toolchain and dependencies

**Base:** Ubuntu 24.04

**Installed Tools:**
- Ruby (3.2.6, 3.3.6, 3.4.7 via ruby-install)
- Node.js 22 LTS
- PostgreSQL client, Redis client
- Chrome + Chromedriver (for Capybara tests)
- Claude Code CLI, Beads (bd)
- SOPS + age (secrets management)

**Baked-in:** `~/.claude/` directory (agents, artifacts, commands)

**Build:** `Dockerfile` with multiple Ruby version tags

---

#### **Layer 4: Container Runtime**
**Responsibility:** Repository setup and environment preparation

**Key Component:** `entrypoint.sh` (440 lines)

**Bootstrap Sequence:**
1. Clone repository from `REPO_URL` with token authentication
2. Load `.env.claude-sandbox` (plaintext) and `.env.sops` (encrypted)
3. Detect project type (Rails/Node)
4. Detect actual service needs by scanning dependencies
5. Wait for service readiness (pg_isready, redis-cli ping)
6. Install dependencies (`bundle install`, `npm install`)
7. Prepare database (`rails db:prepare`)
8. Initialize Beads tracking (`bd setup claude`)
9. Execute Claude CLI
10. Send notification on exit (trap)

---

#### **Layer 5: Execution**
**Responsibility:** Autonomous code changes

**Component:** Claude Code CLI

**Execution:**
```bash
claude --dangerously-skip-permissions \
  -p "$TASK" \
  --output-format stream-json \
  --verbose
```

**Multi-Agent Workflow:** Analyst → Planner → Implementer → Reviewer

**Operations:** Read/write files, run commands, git operations (via Layer 6)

---

#### **Layer 6: Safety & Control**
**Responsibility:** Prevent destructive operations

**Component:** `safe-git` wrapper (79 lines)

**Protections:**
- Blocks force push to: main, master, production
- Warns on direct push to protected branches
- Warns on hard reset to protected branches

**Note:** Additional layer before GitHub branch protection (defense in depth)

---

#### **Layer 7: Notification**
**Responsibility:** Async status reporting

**Component:** `notify-telegram.sh` (73 lines)

**Triggered:** EXIT trap in `entrypoint.sh`

**Message Content:** Status (✅❌💀⚠️), task, repo, branch, commit hash

---

## Deployment Models

### Local (Docker Compose)

**When to use:**
- Development and testing
- Faster iteration (no cluster overhead)
- Persistent volumes for caching

**Characteristics:**
- Service discovery: Container names via DNS
- Networking: Bridge network
- Persistence: Named volumes (claude_workspace, postgres_data)
- Resource limits: None (host machine limits)
- Cleanup: Manual (`docker compose down`)

**Command:**
```bash
bin/claude-sandbox local "implement feature X"
```

---

### Remote (Kubernetes)

**When to use:**
- Production automation
- Complete isolation from host
- Scalability (cluster resources)
- CI/CD pipelines

**Characteristics:**
- Service discovery: localhost (same Pod)
- Networking: Pod network
- Persistence: emptyDir (ephemeral)
- Resource limits: Explicit (requests/limits in YAML)
- Cleanup: Auto (TTL: 3600s)
- Sidecars: Conditionally generated based on detection

**Command:**
```bash
bin/claude-sandbox remote "implement feature X"
```

---

### Comparison

| Aspect | Local | Remote |
|--------|-------|--------|
| **Use Case** | Development | Production |
| **Isolation** | Container | Pod (higher) |
| **Persistence** | Volumes | Ephemeral |
| **Cost** | Free | Cluster costs |
| **Startup** | ~10s | ~30s |
| **Cleanup** | Manual | Automatic |

---

## Key Mechanisms

### 1. Fresh Clone Strategy

**Decision:** Each run clones repository from scratch (no local checkout used)

**Benefits:**
- Clean state (no leftover files)
- Reproducible (same commit = same state)
- Safe (local changes don't affect Claude)

**Implementation:** `entrypoint.sh` clones with token: `https://x-access-token:${GITHUB_TOKEN}@github.com/...`

---

### 2. Service Auto-Detection

**Two-Phase Detection:**

**Phase 1: CLI (Pre-flight)** - `detect-services.sh`
- Scans `Gemfile` and `package.json` (via git archive)
- Determines which services to start
- Fallback: Start all services if detection fails

**Phase 2: Runtime (Definitive)** - `entrypoint.sh`
- Re-scans dependencies in cloned repo
- Sets environment flags: `NEEDS_POSTGRES`, `NEEDS_REDIS`
- Waits for service readiness before proceeding

**Patterns Detected:**
- `gem 'pg'` or `"pg"` → PostgreSQL
- `gem 'redis'` or `gem 'sidekiq'` → Redis
- `gem 'mysql2'` → MySQL
- `gem 'sqlite3'` → SQLite

---

### 3. Secrets Management

**Three Options:**

1. **`.env.claude-sandbox`** - Plaintext, committed (non-sensitive config)
2. **`.env.sops`** - Encrypted with age key, committed (sensitive values)
3. **K8s Secrets** - Injected by Kubernetes (remote only)

**SOPS Decryption:** If `/secrets/age-key.txt` exists, `entrypoint.sh` decrypts `.env.sops`

**Reference:** See `docs/SOPS-setup.md` for encryption setup

---

### 4. Multi-Version Ruby Support

**Configuration:** `ruby-versions.yaml` maps version families

**Build Process:** `bin/claude-sandbox build`
- Builds separate images for each Ruby version
- Tags: `claude-sandbox:ruby-3.2`, `ruby-3.3`, `ruby-3.4`, `latest`

**Auto-Detection:** Reads `.ruby-version` from repo, maps to image tag

**Reference:** See `docs/RUBY-VERSIONS-management.md` for version management

---

### 5. Conditional Sidecars

**Local:** Profile-based (`--profile with-postgres`)
- Controlled by `docker-compose.yml` profiles
- Starts only services with matching profile

**Remote:** Dynamic YAML generation
- Function `generate_k8s_job_yaml()` includes sidecars conditionally
- Based on `needs_postgres` and `needs_redis` flags

**Benefit:** Reduces resource usage and startup time

---

## Security Model

### Isolation Boundaries

1. **Container isolation** - Process and filesystem isolation
2. **Network isolation** - Services only accessible within container/pod
3. **Fresh clone** - No persistence between runs (except volumes)
4. **Non-root user** - Container runs as `claude:claude` (not root)

### Secrets Handling

- **Never committed plaintext** - Use `.env.sops` or K8s secrets
- **Encrypted at rest** - SOPS with age encryption
- **Decrypted at runtime** - Only in container memory
- **Age key management** - Stored in K8s secret (remote) or local file (local)

### Git Safety

- **safe-git wrapper** - Prevents force push to protected branches
- **GitHub branch protection** - Final enforcement (requires PR for main/master)
- **Fresh clone** - Can't accidentally push from wrong branch

### Attack Surface

**Trusted:**
- GitHub repository (assumed trusted)
- Container image (built from known Dockerfile)
- K8s cluster (assumed trusted)

**Untrusted:**
- Claude Code output (constrained by safe-git and branch protection)

**Known Limitations:**
- Full permissions mode means Claude can run any command
- Safety relies on branch protection and code review

---

## Related Documentation

- **Setup Guides:** `docs/kubernetes-cluster-setup-guide.md`, `docs/SOPS-setup.md`
- **Technical Reference:** `docs/ENV-FILES-management.md`, `docs/RUBY-VERSIONS-management.md`
- **Extending:** `docs/EXTENDING.md` (for adding new languages/services)
- **Architecture Decisions:** `docs/ARCHITECTURE-DECISIONS.md` (historical record)

---

**Document Version:** 1.0
**Last Updated:** 2026-02-03
**Stability:** High (only changes with major refactoring)
