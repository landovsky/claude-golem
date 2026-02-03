# Environment Files Guide

Quick reference for managing environment variables in claude-sandbox projects.

## File Types

| File | Purpose | Encrypted | Commit to Git | Setup Required |
|------|---------|-----------|---------------|----------------|
| `.env.claude-sandbox` | Public config | No | ✅ Yes | None |
| `.env.sops` | Secrets | Yes | ✅ Yes | SOPS + age key |
| `.env.local` | Local overrides | No | ❌ No | None |

## .env.claude-sandbox

**Purpose:** Non-sensitive project configuration

**Contents:**
- Database names
- Application settings
- Feature flags
- Service URLs (non-auth)
- Build configuration

**Example:**
```bash
# .env.claude-sandbox
DATABASE_NAME=myapp_development
RAILS_ENV=development
APP_HOST=localhost:3000
ENABLE_FEATURE_X=true
```

**Commit:** ✅ Yes - safe to commit, no secrets here

## .env.sops

**Purpose:** Sensitive secrets (encrypted)

**Contents:**
- API keys
- Passwords
- Access tokens
- Database passwords
- OAuth secrets

**Example (decrypted view):**
```bash
# .env.sops (shown decrypted, actually stored encrypted)
STRIPE_SECRET_KEY=sk_test_xxx
AWS_ACCESS_KEY_ID=AKIA...
DATABASE_PASSWORD=secret123
```

**Commit:** ✅ Yes - encrypted, safe to commit

**Setup:** Requires SOPS + age key (see [SOPS-setup.md](SOPS-setup.md))

## .env.local (Optional)

**Purpose:** Local development overrides

**Contents:**
- Developer-specific settings
- Local service URLs
- Debug flags

**Example:**
```bash
# .env.local
DATABASE_URL=postgres://localhost:5432/myapp_dev_localuser
DEBUG=true
```

**Commit:** ❌ No - add to `.gitignore`

**Note:** Not automatically loaded by claude-sandbox. Use for local development only.

## Loading Order

Variables are loaded in this order (later overrides earlier):

```
1. K8s secrets (shared credentials)
   ↓
2. .env.claude-sandbox (public project config)
   ↓
3. .env.sops (encrypted secrets)
   ↓
4. Job template env vars (explicit overrides)
```

## Quick Start

### Simple Project (No Secrets)

```bash
# Just use .env.claude-sandbox
cat > .env.claude-sandbox << 'EOF'
DATABASE_NAME=myapp_development
RAILS_ENV=development
EOF

git add .env.claude-sandbox
git commit -m "Add project config"
```

### Project with Secrets

```bash
# 1. Public config in .env.claude-sandbox
cat > .env.claude-sandbox << 'EOF'
DATABASE_NAME=myapp_production
RAILS_ENV=production
EOF

# 2. Secrets in .env.sops (requires SOPS setup)
sops .env.sops
# Add: DATABASE_PASSWORD=secret123

# 3. Commit both
git add .env.claude-sandbox .env.sops .sops.yaml
git commit -m "Add config and secrets"
```

## .gitignore Recommendations

```gitignore
# Local overrides (don't commit)
.env.local
.env*.local

# Unencrypted secrets (never commit these!)
.env.sops.dec*  # SOPS temporary decrypted files

# But DO commit these:
# .env.claude-sandbox     (public config)
# .env.sops       (encrypted secrets)
# .sops.yaml      (SOPS config)
```

## Best Practices

### ✅ DO:
- Use `.env.claude-sandbox` for all non-sensitive config
- Use `.env.sops` for secrets, API keys, passwords
- Commit both `.env.claude-sandbox` and `.env.sops` to git
- Document what variables are needed in README
- Use meaningful variable names

### ❌ DON'T:
- Put secrets in `.env.claude-sandbox` (use `.env.sops`)
- Commit `.env.local` files
- Commit `.env.sops.dec_*` temporary files
- Use production secrets in development `.env.sops`
- Hardcode secrets in code

## Examples

### Rails App

```bash
# .env.claude-sandbox
DATABASE_NAME=myapp_production
RAILS_ENV=production
RAILS_LOG_LEVEL=info
REDIS_URL=redis://redis:6379/0

# .env.sops (encrypted)
SECRET_KEY_BASE=...
DATABASE_PASSWORD=...
RAILS_MASTER_KEY=...
```

### Node.js App

```bash
# .env.claude-sandbox
NODE_ENV=production
APP_PORT=3000
LOG_LEVEL=info

# .env.sops (encrypted)
JWT_SECRET=...
STRIPE_SECRET_KEY=...
DATABASE_URL=postgres://user:password@localhost/db
```

### Multi-Environment

You can use multiple SOPS files:

```bash
.env.claude-sandbox              # Shared public config
.env.development.sops    # Dev secrets
.env.staging.sops        # Staging secrets
.env.production.sops     # Production secrets
```

Currently, entrypoint.sh only loads `.env.sops`. To support multiple files, you could:
1. Modify entrypoint.sh to detect based on RAILS_ENV or similar
2. Or use symlinks: `ln -s .env.production.sops .env.sops`

## Troubleshooting

### Variables not loading

Check the logs:
```bash
kubectl logs <pod-name> | grep "Environment Configuration"
```

You should see:
```
▶ Environment Configuration
[sandbox] Loading .env.claude-sandbox...
[sandbox] ✓ Environment variables loaded from .env.claude-sandbox
[sandbox] Decrypting .env.sops with age key...
[sandbox] ✓ Encrypted secrets loaded from .env.sops
```

### Variable precedence issues

Remember the order: k8s secrets → .env.claude-sandbox → .env.sops → job env vars

To debug:
```bash
# In the job, print env vars
kubectl exec <pod-name> -- env | grep DATABASE_NAME
```

### SOPS decryption fails

See [SOPS-setup.md#troubleshooting](SOPS-setup.md#troubleshooting)

## Migration Guide

### From hardcoded values

```bash
# Before: Hardcoded in code
DATABASE_NAME = "myapp_production"

# After: In .env.claude-sandbox
DATABASE_NAME=myapp_production

# In code:
DATABASE_NAME = ENV["DATABASE_NAME"]
```

### From k8s ConfigMaps

```bash
# Before: kubectl create configmap
kubectl create configmap myapp-config \
  --from-literal=DATABASE_NAME=myapp_prod

# After: .env.claude-sandbox in repo
echo "DATABASE_NAME=myapp_prod" > .env.claude-sandbox
git add .env.claude-sandbox
git commit -m "Migrate from ConfigMap"

# Delete ConfigMap
kubectl delete configmap myapp-config
```

### From k8s Secrets (for non-sensitive data)

```bash
# Before: kubectl create secret (overkill for public data)
kubectl create secret generic myapp-config \
  --from-literal=DATABASE_NAME=myapp_prod

# After: .env.claude-sandbox in repo
echo "DATABASE_NAME=myapp_prod" > .env.claude-sandbox
git commit -m "Move public config to .env.claude-sandbox"

# Keep real secrets in .env.sops
```

## See Also

- [SOPS-setup.md](SOPS-setup.md) - Complete SOPS guide
- [.env.claude-sandbox.example](/.env.claude-sandbox.example) - Example file
- [.env.sops.example](/.env.sops.example) - Example file
