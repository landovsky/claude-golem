# Claude Sandbox - Architecture Diagrams

This directory contains PlantUML diagrams documenting the claude-sandbox architecture. These diagrams are designed to support solution architecture for new features.

## Diagram Files

### 1. **architecture.puml** - Component Architecture
**Purpose:** Comprehensive overview showing all components and their relationships

**What it shows:**
- 7 layers: Client, Local Orchestration, Remote Orchestration, Container Image, Container Runtime, Configuration, External Services
- Component responsibilities and interactions
- Both local (Docker Compose) and remote (Kubernetes) execution paths
- Service sidecars (PostgreSQL, Redis, MySQL, SQLite)
- Configuration and secrets management
- Communication protocols

**Best for:**
- Understanding overall system architecture
- Identifying component dependencies
- Planning new integrations
- Onboarding new developers

### 2. **execution-flow.puml** - Sequence Diagram
**Purpose:** Shows the temporal flow of execution from user command to completion

**What it shows:**
- Step-by-step execution sequence
- Initialization and auto-detection
- Local vs remote execution paths (swim lanes)
- Container bootstrap process
- Service readiness checks
- Dependency installation
- Claude multi-agent workflow
- Git operations through safe-git wrapper
- Cleanup and notifications

**Best for:**
- Understanding execution timeline
- Debugging issues
- Understanding control flow
- Identifying bottlenecks

### 3. **layer-architecture.puml** - Layer Architecture
**Purpose:** Shows the system as distinct layers with clear responsibilities

**What it shows:**
- 7 layers with detailed responsibilities
- Layer-to-layer communication
- External service integration
- Configuration and secrets flow
- Safety mechanisms

**Best for:**
- Understanding separation of concerns
- Planning architectural changes
- Identifying where to add new functionality
- Security analysis

### 4. **local-vs-remote.puml** - Deployment Comparison
**Purpose:** Side-by-side comparison of local and remote execution

**What it shows:**
- Docker Compose configuration (local)
- Kubernetes Job configuration (remote)
- Networking differences (bridge vs Pod network)
- Service discovery mechanisms
- Volume and persistence strategies
- Resource management
- Comparison table of key differences

**Best for:**
- Choosing between local/remote for a use case
- Understanding deployment differences
- Planning migration strategies
- Resource planning

## Viewing the Diagrams

### Option 1: PlantUML Web Server (Quick Preview)
Visit: http://www.plantuml.com/plantuml/uml/

Copy the content of any `.puml` file and paste it to see the rendered diagram.

### Option 2: PlantUML CLI (Local Rendering)
```bash
# Install PlantUML
brew install plantuml

# Render all diagrams to PNG
plantuml docs/*.puml

# Render to SVG (scalable)
plantuml -tsvg docs/*.puml

# Auto-watch and regenerate on changes
plantuml -tsvg -gui docs/*.puml
```

### Option 3: VS Code Extension
1. Install the "PlantUML" extension by jebbs
2. Open any `.puml` file
3. Press `Alt+D` (or `Cmd+D` on Mac) to preview

### Option 4: IntelliJ/WebStorm Plugin
1. Install the "PlantUML Integration" plugin
2. Open any `.puml` file
3. Click the PlantUML tab to view rendered diagram

### Option 5: Online Editor with GitHub
Visit: https://planttext.com/
Paste the `.puml` content to view and edit interactively.

## Using Diagrams for Solution Architecture

### When Planning a New Feature

1. **Start with architecture.puml**
   - Identify which components need to change
   - Understand current communication protocols
   - Map out new component requirements

2. **Review execution-flow.puml**
   - Identify where in the execution flow your feature fits
   - Understand timing and sequencing constraints
   - Identify potential race conditions

3. **Check layer-architecture.puml**
   - Determine which layer owns your feature
   - Ensure proper separation of concerns
   - Identify cross-layer dependencies

4. **Consult local-vs-remote.puml**
   - Understand if your feature affects local/remote differently
   - Plan for environment-specific behavior
   - Consider resource implications

### Example: Adding MySQL Support

Using the diagrams:

1. **architecture.puml** → See existing PostgreSQL patterns, plan similar MySQL sidecar
2. **execution-flow.puml** → Add MySQL readiness check after service detection
3. **layer-architecture.puml** → Update Layer 4 (Container Runtime) for MySQL setup
4. **local-vs-remote.puml** → Add MySQL to comparison table, plan both deployments

### Example: Adding Python/Django Support

Using the diagrams:

1. **architecture.puml** → Identify Ruby-specific components (Layer 3, Dockerfile)
2. **execution-flow.puml** → Plan Python dependency installation (pip install)
3. **layer-architecture.puml** → Update Layer 4 for Django detection and setup
4. **local-vs-remote.puml** → Consider Python version management (like Ruby versions)

### Example: Adding Cloud Storage Integration

Using the diagrams:

1. **architecture.puml** → Add as external service, plan Layer 5 integration
2. **execution-flow.puml** → Add credential setup in container bootstrap
3. **layer-architecture.puml** → Add to Configuration layer (secrets)
4. **local-vs-remote.puml** → Consider different access patterns (local vs K8s service account)

## Diagram Maintenance

### When to Update Diagrams

- ✅ Adding new components or services
- ✅ Changing execution flow or sequencing
- ✅ Modifying layer responsibilities
- ✅ Changing deployment strategies
- ✅ Adding new configuration options
- ✅ Integrating new external services

### Updating Guidelines

1. **Keep diagrams synchronized** - When you change code, update diagrams
2. **Use consistent naming** - Match component names to actual file/service names
3. **Add notes for complexity** - Explain non-obvious design decisions
4. **Update legend** - Keep color codes and symbols documented
5. **Test rendering** - Verify diagrams render correctly after changes

### Diagram Review Checklist

Before committing diagram changes:

- [ ] Diagram renders without errors
- [ ] All components are labeled
- [ ] Relationships are clearly shown
- [ ] Legend is up to date
- [ ] Notes explain key design decisions
- [ ] Colors follow established scheme
- [ ] Related diagrams are updated consistently

## Architecture Decision Records (ADRs)

Key architectural decisions reflected in these diagrams:

| Decision | Diagram | Location |
|----------|---------|----------|
| Fresh clone per run | execution-flow.puml | Container Bootstrap |
| Service auto-detection | architecture.puml | Layer 1, detect-services.sh |
| Conditional sidecars | local-vs-remote.puml | Both deployments |
| safe-git wrapper | layer-architecture.puml | Layer 6 |
| SOPS encryption | architecture.puml | Configuration layer |
| Multi-Ruby versions | architecture.puml | Layer 3 (Dockerfile) |
| Profile-based composition | local-vs-remote.puml | Docker Compose |
| Dynamic K8s YAML | local-vs-remote.puml | Kubernetes |
| Telegram notifications | execution-flow.puml | Cleanup phase |
| Baked agents | architecture.puml | Layer 3 |

## Questions and Feedback

If you have questions about the architecture or suggestions for diagram improvements:

1. Create an issue in the repository
2. Tag diagrams in your PRs that change architecture
3. Update diagrams as part of feature implementation
4. Use diagrams in design reviews

## References

- [PlantUML Documentation](https://plantuml.com/)
- [PlantUML Component Diagrams](https://plantuml.com/component-diagram)
- [PlantUML Sequence Diagrams](https://plantuml.com/sequence-diagram)
- [PlantUML Deployment Diagrams](https://plantuml.com/deployment-diagram)
- [C4 Model](https://c4model.com/) - Inspiration for layered architecture diagrams
