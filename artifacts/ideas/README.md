# Ideas Directory

This directory supports the Discovery Workflow (see `../workflow-design/DISCOVERY.md`).

## Directory Structure

```
ideas/
├── scratch/        # Raw ideas (git-ignored, ephemeral)
├── analysis/       # Documented challenge analysis (committed if valuable)
└── README.md       # This file
```

## How It Works

1. **Raw ideas**: Keep in `scratch/` or just in your head (git-ignored)
2. **Challenge analysis**: If valuable, document in `analysis/`
3. **Validated ideas**: Create in beads with `bd create --type=idea`
4. **Ready to work**: Convert to task with `bd update <id> --type=task`
5. **Graduate to work**: Run `/develop <id>` to start implementation

## Key Commands

```bash
# List all validated ideas (in beads)
bd list --type=idea --status=open

# List high-priority ideas
bd list --type=idea --priority=0,1 --status=open

# Show details of an idea
bd show <idea-id>

# Update priority
bd update <idea-id> --priority=1

# Graduate to task (ready to work)
bd update <idea-id> --type=task

# Start development
/develop <idea-id>
```

## Philosophy

**Don't persist everything.** Most ideas should die quickly. Only validated, high-ROI ideas deserve to be tracked.

- 90% of raw ideas → discarded (not persisted)
- 10% pass validation → `type=idea` in beads
- 10-20% of validated ideas → `type=task` and implemented

This is about FOCUS. Say no to 90% so you can say yes to the 10% that matter.
