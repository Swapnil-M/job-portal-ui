#!/usr/bin/env bash
# Claude Code status line — project-scoped.
# Shows: model name · current dir · git branch/status · context remaining %

input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
cur_dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // "."')
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // ""')
dir_name=$(basename "$cur_dir")

# Git branch + dirty marker
git_part=""
if git -C "$cur_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cur_dir" branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cur_dir" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$(git -C "$cur_dir" status --porcelain 2>/dev/null)" ]; then
    git_part=" · ⎇ ${branch}*"
  else
    git_part=" · ⎇ ${branch}"
  fi
fi

# Context remaining %: derive from the last usage entry in the transcript.
ctx_part=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  used=$(jq -s '
    [ .[] | select(.message.usage != null) | .message.usage ] as $u
    | if ($u | length) > 0 then
        ($u[-1].input_tokens // 0)
        + ($u[-1].cache_read_input_tokens // 0)
        + ($u[-1].cache_creation_input_tokens // 0)
      else 0 end
  ' "$transcript" 2>/dev/null)
  if [ -n "$used" ] && [ "$used" -gt 0 ] 2>/dev/null; then
    limit=200000
    remaining=$(( (limit - used) * 100 / limit ))
    [ "$remaining" -lt 0 ] && remaining=0
    ctx_part=" · ${remaining}% ctx left"
  fi
fi

printf '%s · %s%s%s' "$model" "$dir_name" "$git_part" "$ctx_part"
