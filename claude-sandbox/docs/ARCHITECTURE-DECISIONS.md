# Architecture Decision Records (ADRs)

This document records major architectural decisions made in claude-sandbox. Each ADR captures the context, decision, and consequences at the time the decision was made.

**Format:**
- **Title:** Brief decision summary
- **Status:** Accepted | Deprecated | Superseded
- **Date:** When decided
- **Context:** Problem/situation requiring a decision
- **Decision:** What was decided and why
- **Consequences:** Positive and negative outcomes

---

## ADR-001: Use Fresh Clone Per Run

**Status:** Accepted
**Date:** 2024-11-15

**Context:**
Claude Code needs a consistent starting state for reproducibility. Options considered:
1. Reuse existing checkout and `git pull`
2. Clone fresh repository each run
3. Use git worktrees

**Decision:**
Clone fresh repository from `REPO_URL` at the start of each run. Never reuse local checkouts.

**Consequences:**
- ✅ Reproducible: Same commit = same starting state
- ✅ Clean: No leftover files from previous runs
- ✅ Safe: Local changes don't interfere
- ❌ Slower: Clone adds ~5-10s per run
- ❌ Bandwidth: Downloads repo each time

---

## ADR-002: Profile-Based Service Composition (Local)

**Status:** Accepted
**Date:** 2024-11-20

**Context:**
Not all projects need all services (PostgreSQL, Redis, MySQL, etc.). Starting unnecessary services:
- Wastes resources
- Slows startup time
- Increases complexity

**Decision:**
Use Docker Compose profiles to conditionally start services based on auto-detection:
- `--profile claude` (always)
- `--profile with-postgres` (if pg gem detected)
- `--profile with-redis` (if redis/sidekiq detected)

**Consequences:**
- ✅ Fast startup: Only needed services start
- ✅ Resource efficient: Reduced memory/CPU usage
- ✅ Clear: Explicit service dependencies
- ⚠️ Fallback: If detection fails, start all services (safe default)

---

## ADR-003: Conditional Sidecars (Remote/Kubernetes)

**Status:** Accepted
**Date:** 2024-11-22

**Context:**
Kubernetes Jobs with static YAML templates include all sidecars unconditionally. This wastes cluster resources and increases pod startup time.

**Decision:**
Generate Kubernetes YAML dynamically with `generate_k8s_job_yaml()` function. Include postgres/redis sidecars only if detected as needed.

**Consequences:**
- ✅ Resource efficient: Only pay for what's used
- ✅ Faster startup: Fewer containers to schedule
- ❌ More complex: Dynamic YAML generation vs static template
- ⚠️ Fallback: If detection fails, include all sidecars

---

## ADR-004: SOPS for Secrets Encryption

**Status:** Accepted
**Date:** 2024-11-25

**Context:**
Secrets (API keys, tokens) needed in automation but can't be committed plaintext. Options:
1. `.env` files (plaintext, not safe)
2. Kubernetes secrets (remote only, not portable)
3. SOPS with age encryption (encrypted at rest, committed)

**Decision:**
Support three-tier secrets management:
1. `.env.claude-sandbox` - Plaintext (non-sensitive config)
2. `.env.sops` - SOPS encrypted with age key (sensitive values)
3. K8s secrets - Kubernetes native (remote only)

**Consequences:**
- ✅ Flexibility: Choose security level per secret
- ✅ Portable: `.env.sops` works locally and remotely
- ✅ Secure: Encrypted at rest, committed to git
- ❌ Complexity: Requires age key management
- ⚠️ Key rotation: Must update all `.env.sops` files

---

## ADR-005: safe-git Wrapper

**Status:** Accepted
**Date:** 2024-12-01

**Context:**
Claude Code with `--dangerously-skip-permissions` can run any git command, including destructive ones:
- Force push to main/master
- Hard reset
- Delete branches

GitHub branch protection is the primary defense, but an additional layer prevents accidents.

**Decision:**
Wrap git binary with `safe-git` script that:
- Blocks force push to: main, master, production
- Warns on direct push to protected branches
- Warns on hard reset to protected branches

**Consequences:**
- ✅ Defense in depth: Additional safety layer
- ✅ Fast feedback: Prevents mistakes early
- ✅ Auditable: Clear git operations in logs
- ❌ Workaround possible: Can use `/usr/bin/git` directly if known
- ⚠️ Not a security boundary: GitHub protection is primary

---

## ADR-006: Multi-Ruby Version Images

**Status:** Accepted
**Date:** 2024-12-05

**Context:**
Rails projects use different Ruby versions (3.2, 3.3, 3.4). Options:
1. Single image with multiple Ruby versions installed
2. Separate images per Ruby version
3. Runtime Ruby installation (rvm/rbenv)

**Decision:**
Build separate Docker images per Ruby major.minor version:
- `claude-sandbox:ruby-3.2` → Ruby 3.2.6
- `claude-sandbox:ruby-3.3` → Ruby 3.3.6
- `claude-sandbox:ruby-3.4` → Ruby 3.4.7
- `claude-sandbox:latest` → Points to newest

Auto-detect from `.ruby-version` file.

**Consequences:**
- ✅ Clean: One Ruby per image
- ✅ Fast: No runtime installation
- ✅ Explicit: Version in tag
- ❌ Storage: Multiple images (~2GB each)
- ❌ Build time: Must build all versions

---

## ADR-007: Rails-First, Extensible to Others

**Status:** Accepted
**Date:** 2024-12-10

**Context:**
Need to validate concept before generalizing. Options:
1. Build language-agnostic system from start
2. Optimize for one ecosystem, then generalize

**Decision:**
Optimize for Rails/Ruby first:
- Rails-specific commands (`db:prepare`)
- Ruby version management
- Gemfile dependency detection

Design for extensibility:
- Pluggable project detection
- Extensible service detection
- Documented extension points

**Consequences:**
- ✅ Fast iteration: Solve real problems first
- ✅ Battle-tested: Production usage validates design
- ✅ Extensible: Clear patterns for adding languages
- ⚠️ Technical debt: Rails assumptions must be factored out

---

## Template for New ADRs

```markdown
## ADR-XXX: [Decision Title]

**Status:** Proposed | Accepted | Deprecated | Superseded by ADR-YYY
**Date:** YYYY-MM-DD

**Context:**
[Describe the problem/situation requiring a decision. What constraints exist? What alternatives were considered?]

**Decision:**
[What was decided? Be specific and concrete.]

**Consequences:**
- ✅ Positive outcome 1
- ✅ Positive outcome 2
- ❌ Negative outcome 1
- ⚠️ Risks or trade-offs
```

---

**Note:** ADRs are immutable once accepted. If a decision changes, create a new ADR and mark the old one as "Superseded by ADR-XXX".
