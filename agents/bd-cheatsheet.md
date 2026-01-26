# bd Cheatsheet for Planner

## Read Tasks
```bash
bd show <id>              # Full task details
bd children <epic-id>     # Epic's subtasks
bd ready --parent <epic>  # Unblocked work in epic
bd dep tree <id>          # Dependency visualization
```

## Create Plan Tasks
```bash
# Create epic
bd create "Feature Title" -t epic -p 1

# Add subtasks to epic
bd create "Step 1: Setup models" --parent <epic-id> -p 1
bd create "Step 2: Add service" --parent <epic-id> -p 1
bd create "Step 3: Write tests" --parent <epic-id> -p 2

# With descriptions
bd create "Title" -d "Acceptance criteria here" --parent <epic-id>
```

## Set Dependencies
```bash
bd dep <blocker> --blocks <blocked>   # A must finish before B
bd dep add <child> <parent>           # Alternative syntax
```

## Priority Reference
| `-p 0` | Critical | `-p 2` | Medium (default) |
|--------|----------|--------|------------------|
| `-p 1` | High     | `-p 3` | Low              |

## Example: Plan → Tasks
```bash
# 1. Create epic for the plan
bd create "User Export Feature" -t epic -p 1
# Returns: bd-a1b2

# 2. Break down into ordered tasks
bd create "Add export_users service" --parent bd-a1b2 -p 1
# Returns: bd-a1b2.1

bd create "Create CSV formatter" --parent bd-a1b2 -p 1
# Returns: bd-a1b2.2

bd create "Add controller endpoint" --parent bd-a1b2 -p 1
# Returns: bd-a1b2.3

# 3. Set execution order
bd dep bd-a1b2.1 --blocks bd-a1b2.3   # service before controller
bd dep bd-a1b2.2 --blocks bd-a1b2.3   # formatter before controller
```

## Check Status
```bash
bd epic status            # Completion % for all epics
bd ready --json           # Machine-readable ready work
```
