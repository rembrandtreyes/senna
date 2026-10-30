#!/usr/bin/env bash
# SubagentStop: when a critic or reviewer finishes, record its verdict with the hash of what it
# reviewed, in .harness/verdicts/. The Stop gates (core review-gate.sh, plan step-gate.sh) read
# these. Any subagent can take part by ending its output with these two lines:
#   REVIEWED: <repo-relative path>   (specs/<slug>/prd.md, specs/<slug>/spec.md, or a task file)
#   VERDICT: <PASS | FAIL | FIX FIRST>
# Each run by a critic or reviewer, or with either line, leaves a short record of what the hook
# saw and did in .harness/.record-verdict.log (the run before it in .record-verdict.prev.log), so
# a verdict the gate can't find can be traced. Never blocks.
source "$(dirname "$0")/common.sh"

msg="$(jget '.last_assistant_message')"
agent="$(jget '.agent_type')"
case "$agent" in reviewer|*:reviewer|*critic) ;; *)
  case "$msg" in *VERDICT:*|*REVIEWED:*) ;; *) exit 0 ;; esac ;;
esac

# The record: one key=value per line, each value cut to 200 characters so the outcome line always
# fits in 4 KiB; never the whole message.
log=""
note() { local v="${2//$'\n'/ }"; log="${log}$1=${v:0:200}
"; }
# finish <outcome> : save the record (at most 4 KiB) and exit 0. Each run writes its own temp file
# and renames it into place, so concurrent runs never mix lines.
finish() {
  local d t
  note outcome "$1"
  d="$(harness_dir)"; t="$d/.record-verdict.$$.tmp"
  if { printf '%s' "$log" | head -c 4096 > "$t"; } 2>/dev/null; then
    mv -f "$d/.record-verdict.log" "$d/.record-verdict.prev.log" 2>/dev/null
    mv -f "$t" "$d/.record-verdict.log" 2>/dev/null && exit 0
  fi
  rm -f "$t" 2>/dev/null
  echo "harness: record-verdict could not save its diagnostic in $d ($1)" >&2
  exit 0
}

note time "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
note event "$(jget '.hook_event_name')"
note agent_type "$agent"
note agent_id "$(jget '.agent_id')"
note agent_transcript "$(jget '.agent_transcript_path')"
note env_project_dir "${CLAUDE_PROJECT_DIR:-(unset)}"
note input_cwd "$(jget '.cwd')"
note message_chars "${#msg}"
[ -n "$msg" ] || finish "skipped: last_assistant_message is empty"

note verdict_line "$(printf '%s\n' "$msg" | grep -m1 'VERDICT:')"
note reviewed_line "$(printf '%s\n' "$msg" | grep -m1 'REVIEWED:')"
verdict="$(printf '%s\n' "$msg" | sed -nE 's/^[[:space:]`*]*VERDICT:[[:space:]*]*([A-Za-z][A-Za-z ]*[A-Za-z]).*/\1/p' | head -n1)"
subject="$(printf '%s\n' "$msg" | sed -nE 's/^[[:space:]`*]*REVIEWED:[[:space:]*`]*([^[:space:]`*]+).*/\1/p' | head -n1)"
[ -n "$verdict" ] || finish "skipped: no line starting VERDICT: <word>"
[ -n "$subject" ] || finish "skipped: no line starting REVIEWED: <path>"

root="$(project_dir)"
top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$root")"
subject="${subject#"$top"/}"; subject="${subject#"$root"/}"; subject="${subject#./}"
case "$verdict" in
  PASS*) verdict=PASS ;;
  FIX*) verdict=FIX_FIRST ;;
  *) verdict=FAIL ;;
esac
task="$(tr -d '\n' < "$root/.harness/current-task" 2>/dev/null)"; task="${task#"$root"/}"
note root "$root"
note git_top "$top"
note subject "$subject"
note subject_is_file "$([ -f "$root/$subject" ] && echo yes || echo no)"
note current_task "${task:-(none)}"
note matches_current_task "$([ "$subject" = "$task" ] && echo yes || echo no)"

f="$(verdict_file "$subject")"
note dest "$f"
# On failure keep the reason (the text after the last ": "); dest above already names the path.
harness_dir >/dev/null
err="$(mkdir -p "$(dirname "$f")" 2>&1)" || finish "failed: mkdir: ${err##*: }"
line="$(printf '%s %s %s %s' "$verdict" "$(subject_hash "$subject")" "$agent" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
err="$( { printf '%s\n' "$line" > "$f"; } 2>&1 )" || finish "failed: write: ${err##*: }"
finish "wrote: $line"
