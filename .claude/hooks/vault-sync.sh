#!/usr/bin/env bash
# Vault sync hooks: keep the Obsidian vault (.knaifu/knowledge) in step with the conversation and project changes.
#   session-start  inject vault location, writing rules and current contents
#   prompt         reset per-turn tracking, remind to capture vault-worthy facts from the conversation
#   post-tool      record project files changed this turn, and whether the vault was written
#   stop           if project files changed but the vault wasn't touched, ask Claude to update it (once per turn)
#   session-end    drop per-session state
set -euo pipefail

input="$(cat)"
event="${1:-}"
project_dir="${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // ""' <<<"$input")}"
vault_rel=".knaifu/knowledge"
vault="$project_dir/$vault_rel"
session_id="$(jq -r '.session_id // "default"' <<<"$input")"
state="${TMPDIR:-/tmp}/claude-vault-sync/$session_id"
mkdir -p "$state"

context() {
  jq -n --arg event "$1" --arg ctx "$2" '{hookSpecificOutput: {hookEventName: $event, additionalContext: $ctx}}'
}

case "$event" in
  session-start)
    ctx="Project knowledge lives in the Obsidian vault at \`$vault_rel/\` (vault root). Keep it current as you work:
- Record decisions (with rationale and rejected alternatives), requirements, architecture, conventions and non-obvious findings as they come up, whether from the conversation or from changes you make to the project.
- Update an existing note before creating a new one. Link related notes with [[wikilinks]]. Keep \`index.md\` as the entry point that links every note.
- Write Obsidian Flavored Markdown (obsidian:obsidian-markdown skill): YAML properties, wikilinks, callouts.
- Don't record chatter, what the code already makes obvious, or secrets."
    if [[ -d "$vault" ]]; then
      notes="$(cd "$vault" && find . -name '*.md' -not -path './.obsidian/*' | sed 's|^\./||' | sort | head -n 200 || true)"
      ctx+=$'\n\nVault notes:\n'"${notes:-(none yet)}"
      if [[ -f "$vault/index.md" ]]; then
        ctx+=$'\n\nindex.md:\n'"$(head -c 6000 "$vault/index.md")"
      fi
    else
      ctx+=$'\n\nThe vault does not exist yet. Create it, starting with index.md, when you first have something to record.'
    fi
    context SessionStart "$ctx"
    ;;

  prompt)
    rm -f "$state/changed" "$state/vault-touched" "$state/nudged"
    context UserPromptSubmit "Vault: if this exchange settles a decision, requirement or fact worth keeping, record it in \`$vault_rel/\` before finishing."
    ;;

  post-tool)
    case "$(jq -r '.tool_name // ""' <<<"$input")" in
      Write|Edit|MultiEdit) paths="$(jq -r '.tool_input.file_path // empty' <<<"$input")" ;;
      NotebookEdit) paths="$(jq -r '.tool_input.notebook_path // empty' <<<"$input")" ;;
      # Only populated when Claude Code records Bash edit diffs (git repos only, best effort).
      Bash) paths="$(jq -r 'try .tool_response.bashEditDiff.changedFiles[] catch empty' <<<"$input")" ;;
      *) paths="" ;;
    esac
    while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      [[ "$path" != /* ]] && path="$project_dir/$path"
      if [[ "$path" == "$vault"/* ]]; then
        touch "$state/vault-touched"
      elif [[ "$path" == "$project_dir"/* ]]; then
        echo "${path#"$project_dir"/}" >>"$state/changed"
      fi
    done <<<"$paths"
    ;;

  stop)
    [[ "$(jq -r '.stop_hook_active // false' <<<"$input")" == "true" ]] && exit 0
    [[ -e "$state/nudged" || -e "$state/vault-touched" || ! -s "$state/changed" ]] && exit 0
    touch "$state/nudged"
    files="$(sort -u "$state/changed" | head -n 30 | sed 's/^/- /' || true)"
    reason="Project files changed this turn, but the vault (\`$vault_rel/\`) was not updated:
$files

If these changes carry anything worth keeping (a decision, convention, architecture, requirement or gotcha), record it in the vault now: update existing notes and index.md. If not, finish without further changes."
    jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
    ;;

  session-end)
    rm -rf "$state"
    ;;
esac

exit 0
