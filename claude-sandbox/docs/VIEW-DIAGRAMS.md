# Quick Guide: View Architecture Diagrams

## Fastest Way to View (No Installation)

### Method 1: PlantUML Web Server (Recommended)

1. Visit: **http://www.plantuml.com/plantuml/uml/**
2. Copy content from any diagram file below
3. Paste into the text area
4. View rendered diagram instantly

### Method 2: PlantText Online Editor

1. Visit: **https://www.planttext.com/**
2. Paste diagram code
3. Click "Refresh" to render

## Diagram Files (Copy & Paste)

### 🏗️ architecture.puml - Full System Overview
**File:** `docs/architecture.puml`

**Shows:** All components, layers, local & remote execution, services, configuration

**Quick view:** Copy this file content and paste at http://www.plantuml.com/plantuml/uml/

---

### ⏱️ execution-flow.puml - Sequence Diagram
**File:** `docs/execution-flow.puml`

**Shows:** Step-by-step execution from CLI command to completion

**Quick view:** Copy this file content and paste at http://www.plantuml.com/plantuml/uml/

---

### 📚 layer-architecture.puml - Layer Diagram
**File:** `docs/layer-architecture.puml`

**Shows:** 7 layers with clear responsibilities and communication

**Quick view:** Copy this file content and paste at http://www.plantuml.com/plantuml/uml/

---

### 🔄 local-vs-remote.puml - Deployment Comparison
**File:** `docs/local-vs-remote.puml`

**Shows:** Side-by-side comparison of Docker Compose vs Kubernetes

**Quick view:** Copy this file content and paste at http://www.plantuml.com/plantuml/uml/

---

## Local Rendering (Optional)

### Install PlantUML

```bash
# macOS
brew install plantuml

# Ubuntu/Debian
sudo apt-get install plantuml

# Docker (no installation)
docker pull plantuml/plantuml-server
```

### Render to PNG

```bash
cd /Users/tomas/.claude/claude-sandbox
plantuml docs/*.puml
# Generates: docs/*.png
```

### Render to SVG (Scalable)

```bash
plantuml -tsvg docs/*.puml
# Generates: docs/*.svg
```

### Auto-regenerate on Changes

```bash
plantuml -tsvg -gui docs/*.puml
# Opens GUI that watches for file changes
```

## Editor Integration

### VS Code
1. Install extension: **PlantUML** by jebbs
2. Open any `.puml` file
3. Press `Alt+D` (Windows/Linux) or `Cmd+D` (Mac)
4. Preview pane appears

### IntelliJ IDEA / WebStorm
1. Install plugin: **PlantUML Integration**
2. Open any `.puml` file
3. Click "PlantUML" tab at bottom

### Vim/Neovim
1. Install plugin: `aklt/plantuml-syntax`
2. Use `:make` to generate PNG/SVG

## Using Docker (No Installation)

```bash
# Render all diagrams using Docker
cd /Users/tomas/.claude/claude-sandbox

docker run --rm \
  -v $(pwd)/docs:/data \
  plantuml/plantuml:latest \
  -tsvg /data/*.puml

# Opens web UI
docker run -d -p 8080:8080 plantuml/plantuml-server
# Visit: http://localhost:8080
```

## Tips for Architecture Planning

### For New Features
1. **Start with:** `architecture.puml` (identify affected components)
2. **Then review:** `execution-flow.puml` (understand where it fits in flow)
3. **Check:** `layer-architecture.puml` (which layer owns this?)
4. **Consider:** `local-vs-remote.puml` (deployment implications)

### For Bug Investigation
1. **Start with:** `execution-flow.puml` (trace the sequence)
2. **Then check:** `architecture.puml` (component interactions)
3. **Verify:** `layer-architecture.puml` (layer boundaries)

### For Performance Optimization
1. **Start with:** `execution-flow.puml` (identify bottlenecks)
2. **Then review:** `local-vs-remote.puml` (resource differences)
3. **Check:** `architecture.puml` (communication overhead)

## Need Help?

- **Full documentation:** `docs/ARCHITECTURE-DIAGRAMS.md`
- **PlantUML docs:** https://plantuml.com/
- **Syntax reference:** https://plantuml.com/guide
