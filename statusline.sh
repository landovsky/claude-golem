#!/bin/sh
# Claude Code status line script
# Receives JSON on stdin, outputs model, effort, context bar, and rate limits

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.reasoning_effort // empty')
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Model + effort
info=""
if [ -n "$model" ]; then
  info="$model"
  if [ -n "$effort" ]; then
    info="$info ($effort)"
  fi
fi

# Context bar
bar=""
if [ -n "$ctx" ]; then
  pct=$(printf '%.0f' "$ctx")
  bar_width=20
  filled=$(( pct * bar_width / 100 ))
  [ "$filled" -gt "$bar_width" ] && filled=$bar_width
  empty=$(( bar_width - filled ))
  bar_fill=$(printf '%*s' "$filled" '' | tr ' ' '=')
  bar_empty=$(printf '%*s' "$empty" '' | tr ' ' '-')
  bar="Ctx ${bar_fill}${bar_empty} ${pct}%"
fi

# Rate limits
rates=""
if [ -n "$five" ]; then
  rates="5h: $(printf '%.0f' "$five")%"
fi
if [ -n "$week" ]; then
  [ -n "$rates" ] && rates="$rates  "
  rates="${rates}7d: $(printf '%.0f' "$week")%"
fi

# Combine: model (effort)  │  Ctx bar  │  rates
parts=""
[ -n "$info" ] && parts="$info"
if [ -n "$bar" ]; then
  [ -n "$parts" ] && parts="$parts  │  "
  parts="${parts}${bar}"
fi
if [ -n "$rates" ]; then
  [ -n "$parts" ] && parts="$parts  │  "
  parts="${parts}${rates}"
fi

echo "$parts"
