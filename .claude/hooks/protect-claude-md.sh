#!/usr/bin/env bash
# PreToolUse hook: blocks any modification of CLAUDE.md (any directory, case-insensitive).
set -euo pipefail

input="$(cat)"
tool="$(jq -r '.tool_name // ""' <<<"$input")"

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

case "$tool" in
  Write|Edit|MultiEdit|NotebookEdit)
    path="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' <<<"$input")"
    name="$(basename "$path" | tr '[:upper:]' '[:lower:]')"
    if [[ "$name" == "claude.md" ]]; then
      deny "CLAUDE.md is protected and must not be modified."
    fi
    ;;
  Bash)
    cmd="$(jq -r '.tool_input.command // ""' <<<"$input")"
    shopt -s nocasematch
    if [[ "$cmd" =~ claude\.md ]]; then
      # Block shell commands that reference CLAUDE.md and look like they write to it.
      write_re='(>|>>|\btee\b|\bsed[[:space:]]+(-[a-z]*[[:space:]]+)*-i|\bperl[[:space:]].*-i|\brm\b|\bmv\b|\bcp\b|\bln\b|\btruncate\b|\bchmod\b|\bchown\b|\btouch\b|\bdd\b|\bed\b|\bex\b|\bvi\b|\bvim\b|\bnano\b|\binstall\b|\brsync\b|\bgit[[:space:]]+(checkout|restore|reset|rm|mv|apply|stash)\b|\bpatch\b|open\(|write_text|writeFile)'
      if [[ "$cmd" =~ $write_re ]]; then
        deny "CLAUDE.md is protected; shell commands that may modify it are blocked."
      fi
    fi
    ;;
esac

exit 0
