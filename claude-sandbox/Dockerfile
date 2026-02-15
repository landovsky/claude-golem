# Claude Sandbox - Development environment for autonomous Claude Code execution
# Includes: Ruby, Node, Postgres client, Redis client, Chrome, beads, Claude Code

FROM ubuntu:24.04

# Build arguments for version control
ARG RUBY_VERSION=3.4.7
ARG SOPS_VERSION=3.9.2
ARG AGE_VERSION=1.2.0

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies (including all Ruby build deps)
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    unzip \
    # Ruby build dependencies (for ruby-install)
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libyaml-dev \
    libffi-dev \
    libpq-dev \
    bison \
    libgdbm-dev \
    libncurses-dev \
    autoconf \
    rustc \
    # Image processing (for Rails)
    libvips \
    exiftool \
    # Database clients
    postgresql-client \
    redis-tools \
    # Misc
    jq \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 for S3 cache operations
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# Install Node.js 22 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Chromium for Capybara/Selenium (works on both amd64 and arm64)
RUN apt-get update \
    && apt-get install -y chromium-browser chromium-chromedriver \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/chromium-browser /usr/bin/google-chrome

# Install Ruby via ruby-install (dependencies already installed above)
RUN wget -O ruby-install.tar.gz https://github.com/postmodern/ruby-install/releases/download/v0.9.3/ruby-install-0.9.3.tar.gz \
    && tar -xzf ruby-install.tar.gz \
    && cd ruby-install-0.9.3 \
    && make install \
    && cd .. \
    && rm -rf ruby-install* \
    && ruby-install --system --no-install-deps ruby $RUBY_VERSION -- --disable-install-doc \
    && gem update --system \
    && gem install bundler

# Install beads (bd) and Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code @beads/bd @twsxtd/hapi

# Install SOPS and age for encrypted secrets management
RUN wget https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64 \
    -O /usr/local/bin/sops && chmod +x /usr/local/bin/sops \
    && wget https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz \
    && tar -xzf age-v${AGE_VERSION}-linux-amd64.tar.gz -C /tmp \
    && mv /tmp/age/age /tmp/age/age-keygen /usr/local/bin/ \
    && rm -rf /tmp/age age-v${AGE_VERSION}-linux-amd64.tar.gz

# Create non-root user
RUN useradd -m -s /bin/bash claude \
    && mkdir -p /workspace \
    && chown -R claude:claude /workspace

# Copy scripts
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 safe-git /usr/local/bin/safe-git
COPY --chmod=755 notify-telegram.sh /usr/local/bin/notify-telegram.sh
COPY --chmod=755 lib/cache-manager.sh /usr/local/lib/cache-manager.sh

# Copy Claude config (agents, settings) - populated by build script
# Use `bin/claude-sandbox build` to bake in your ~/.claude/agents
COPY --chown=claude:claude claude-config/ /home/claude/.claude/

# Put safe-git wrapper in PATH before real git
ENV PATH="/usr/local/bin:$PATH"

# Configure git to use safe-git alias
RUN git config --system alias.push '!safe-git push'

# Switch to non-root user
USER claude
WORKDIR /workspace

# Configure git for Claude
RUN git config --global user.email "claude@sandbox.local" \
    && git config --global user.name "Claude (Sandbox)" \
    && git config --global init.defaultBranch main \
    && git config --global push.autoSetupRemote true

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
