# Global Instructions

## Tmux Window Naming

When running inside tmux ($TMUX is set), after understanding the user's task in your first response, rename the tmux window to a short task description (2-4 words, lowercase). Run this via Bash:

```bash
tmux rename-window -t "$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}')" "short task name"
```

Do this once at the start, silently — no need to mention it to the user. If the window already has a descriptive name (not "claude" or a directory name), don't override it.

## Messaging Tomáš on Telegram

To send Tomáš a Telegram message, run `notify-tomas-telegram <bot> "your message"` (plain text is
auto-escaped). Pick the bot by topic — **`devops`**: code, ops, deploys, CI, bugs, infra;
**`assistant`**: personal/business chores, reminders, interests. The arg is mandatory, so choose
deliberately. Requires `DEVOPS_TELEGRAM_NOTIFY_TOKEN` in the env. It goes through the
devops-telegram `/notify` service — never use a raw Telegram bot token or chat id. Delivery is
logged at https://devops-telegram.kopernici.cz/telegram/admin/events.

## Memory Store

Use the memory-store MCP server as the primary knowledge store for all persistent information learned during conversations. Store and query it actively.

### What to store
- User preferences (tools, keybindings, workflow habits, UI choices)
- Project decisions (architecture choices, trade-offs, why something was done a certain way)
- Learnings & gotchas (bugs encountered, non-obvious fixes, things that didn't work)
- Facts about people, projects, and systems (who works on what, what services exist, relationships)
- Temporal information (deadlines, status changes, what changed when)
- Reminders and action items for future sessions

### Scoping with group_id
- `group_id: "global"` for cross-project information (user preferences, tool configs, personal workflow)
- `group_id: "<project-name>"` for project-specific knowledge (e.g., `"agentic-memory-benchmarking"`, `"medicmee"`)
- Always be explicit with group_id, never rely on the default

### When to store
After learning something non-obvious that would be useful in a future conversation. Don't store ephemeral debugging steps or things derivable from code.

### When to query
At the start of relevant tasks, before making recommendations, and whenever the user references prior work or decisions. Search both the project group and the `"global"` group.
