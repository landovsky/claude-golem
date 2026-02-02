# Environment Configuration Guide

This guide explains how to manage environment variables in claude-sandbox using `.env.claude-sandbox` (plaintext) and `.env.sops` (encrypted).

## Two Approaches

### .env.claude-sandbox - Plaintext Config
**For non-sensitive configuration:**
- ✅ Database names, app hosts, feature flags
- ✅ Easy to edit (plaintext)
- ✅ Safe to commit to git
- ✅ No encryption setup needed

**Example:**
```bash
# .env.claude-sandbox
DATABASE_NAME=myapp_development
RAILS_ENV=development
ENABLE_FEATURE_X=true
```

### .env.sops - Encrypted Secrets
**For sensitive values:**
- ✅ API keys, passwords, tokens
- ✅ Encrypted at rest
- ✅ Safe to commit to git
- ✅ Requires SOPS setup

**Example:**
```bash
# .env.sops (shown decrypted)
STRIPE_SECRET_KEY=sk_test_xxx
AWS_ACCESS_KEY_ID=AKIA...
DATABASE_PASSWORD=secret123
```

### Loading Order

Variables are loaded in this order (later overrides earlier):
1. **K8s secrets** - GITHUB_TOKEN, CLAUDE_CODE_OAUTH_TOKEN, etc.
2. **`.env.claude-sandbox`** - Public project configuration
3. **`.env.sops`** - Encrypted secrets (can override .env.claude-sandbox)
4. **Job env vars** - Explicit overrides in k8s template

**You can use both files together!** Put public config in `.env.claude-sandbox` and secrets in `.env.sops`.

## Why SOPS?

**Benefits:**
- ✅ Secrets live in your repo (encrypted, safe to commit)
- ✅ Version-controlled with your code
- ✅ Zero per-project k8s setup (no manual kubectl commands)
- ✅ One shared age key for all projects
- ✅ Works locally and in k8s with the same files
- ✅ Industry-standard, GitOps-friendly

## Quick Start

### 1. Generate Age Key (One-time)

```bash
# Install age locally
brew install age  # macOS
# or
sudo apt install age  # Ubuntu

# Generate key pair
age-keygen -o age-key.txt

# Output shows public key:
# Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

**Save the public key** - you'll use it to encrypt files.

### 2. Store Private Key in Kubernetes

```bash
# Create k8s secret with private key
kubectl create secret generic age-key \
  --from-file=age-key.txt

# Verify
kubectl get secret age-key

# Store the private key securely (1Password, etc.)
# Delete local copy after storing
rm age-key.txt
```

### 3. Install SOPS Locally

```bash
# macOS
brew install sops

# Ubuntu
wget https://github.com/getsops/sops/releases/download/v3.9.2/sops-v3.9.2.linux.amd64
sudo mv sops-v3.9.2.linux.amd64 /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops
```

## Per-Project Setup

### 1. Create .sops.yaml Config

In your project root:

```yaml
# .sops.yaml
creation_rules:
  - age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p  # Your public key
```

**Commit this file** - it tells SOPS which key to use.

### 2. Create Encrypted Secrets File

```bash
# Create .env.sops with your secrets
sops .env.sops
```

This opens your editor. Add environment variables:

```bash
# .env.sops (will be encrypted when you save)
DATABASE_NAME=myapp_development
APP_HOST=myapp.example.com
REDIS_URL=redis://localhost:6379
SOME_API_KEY=secret-key-here
```

Save and exit. SOPS automatically encrypts the file.

### 3. Verify Encryption

```bash
# View encrypted content
cat .env.sops
# Shows encrypted blob

# View decrypted content (requires private key)
sops -d .env.sops
```

### 4. Commit to Git

```bash
git add .sops.yaml .env.sops
git commit -m "Add encrypted environment variables"
git push
```

**Safe to commit!** The file is encrypted.

## How It Works in claude-sandbox

When the job runs:

1. **Clone repo** → Includes .env.sops
2. **Detect .env.sops** → Found in project root
3. **Decrypt with age key** → Uses `/secrets/age-key.txt` from k8s secret
4. **Export variables** → Available to Claude and all commands
5. **Run task** → Claude sees all decrypted env vars

## Local Development

To use the same .env.sops locally:

```bash
# Export age key
export SOPS_AGE_KEY_FILE=~/.age-key.txt

# Run commands with decrypted env
sops exec-env .env.sops 'rails console'
sops exec-env .env.sops 'npm start'

# Or export to current shell
eval "$(sops -d --output-type dotenv .env.sops | sed 's/^/export /')"
```

## Example Workflow

### Developer A creates secrets:

```bash
cd ~/myproject
cat > .sops.yaml << EOF
creation_rules:
  - age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
EOF

sops .env.sops
# Add: DATABASE_NAME=myapp_dev
# Save

git add .sops.yaml .env.sops
git commit -m "Add encrypted config"
git push
```

### Developer B uses secrets:

```bash
git pull
sops -d .env.sops  # View decrypted values
# Can decrypt because age private key is in k8s
```

### Claude uses secrets:

```bash
cd ~/myproject
claude-sandbox remote "run database migrations"
# Automatically decrypts .env.sops
# DATABASE_NAME available to Rails
```

## Editing Secrets

```bash
# Edit encrypted file
sops .env.sops
# Opens in editor, shows decrypted content
# Make changes, save
# SOPS re-encrypts automatically

git add .env.sops
git commit -m "Update API key"
git push
```

## Key Rotation

If you need to rotate the age key:

```bash
# Generate new key
age-keygen -o new-age-key.txt

# Update .sops.yaml with new public key
# Re-encrypt all .env.sops files
sops updatekeys .env.sops

# Update k8s secret
kubectl delete secret age-key
kubectl create secret generic age-key --from-file=age-key.txt=new-age-key.txt

# Commit updated .env.sops
git add .env.sops
git commit -m "Rotate age key"
```

## Multiple Environments

You can have different encrypted files per environment:

```yaml
# .sops.yaml
creation_rules:
  - path_regex: \.env\.production\.sops$
    age: age1prod...  # Production key
  - path_regex: \.env\.staging\.sops$
    age: age1staging...  # Staging key
  - path_regex: \.env\.sops$
    age: age1dev...  # Development key
```

Then:
```bash
.env.sops                 # Development secrets
.env.staging.sops         # Staging secrets
.env.production.sops      # Production secrets
```

The entrypoint.sh currently only loads `.env.sops`. To support multiple files, you could:
1. Use environment variable to specify which file: `ENV_FILE=.env.production.sops`
2. Or modify entrypoint.sh to detect based on branch/context

## Troubleshooting

### "failed to get the data key required to decrypt"

- Age private key not available or wrong key
- Check: `kubectl get secret age-key`
- Verify key matches public key in .sops.yaml

### ".env.sops found but age key not available"

- Secret not created: `kubectl create secret generic age-key --from-file=age-key.txt`
- Or secret name mismatch (should be exactly `age-key`)

### "sops: command not found" in container

- Image not rebuilt after adding SOPS
- Run: `bin/claude-sandbox build && docker push ...`

### Changes not taking effect

- Did you save when editing with `sops .env.sops`?
- Did you commit and push?
- Is the job pulling latest repo version?

## Security Best Practices

✅ **DO:**
- Store private key in k8s secrets and password manager
- Delete private key from local machine after setup
- Use different keys for different environments
- Rotate keys periodically
- Commit .env.sops files to git

❌ **DON'T:**
- Commit private key to git
- Share private key in Slack/email
- Use same key for all environments
- Leave decrypted .env files around
- Commit .env.sops.dec_* files (SOPS temporary files)

## References

- [SOPS Documentation](https://github.com/getsops/sops)
- [Age Encryption](https://github.com/FiloSottile/age)
- [GitOps Secrets Management](https://www.weave.works/blog/managing-secrets-in-flux-v2-with-sops)
