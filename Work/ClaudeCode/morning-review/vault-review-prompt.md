---
name: vault-review
description: vault review and morning briefing
---

A reusable prompt you can run as a scheduled agent (cron, GitHub Actions, etc.) or by hand each morning. Produces `MORNING_REVIEW.md` at the vault root and archives yesterday's into `Work/ClaudeCode/morning-review/`.

## Setup

```bash
# Point this at wherever your vault lives.
VAULT=~/path/to/your/vault

# Optional: set commit author if running unattended.
GIT_AUTHOR='-c user.email="you@example.com" -c user.name="Your Name"'

TODAY=$(date +%Y-%m-%d)
```

## Steps

### 1. Pull latest vault changes

```bash
git -C "$VAULT" pull --rebase --autostash 2>&1
```

If this fails (no network, no SSH, etc.), **continue with local state** and note the failure in the briefing. Do not abort.

### 2. Review recent activity (past 24 hours)

Primary sources:

- **`Work/ClaudeCode/*/`** — session logs matching `YYYY-MM-DD-HHMM.md` from the past 24 hours:
  ```bash
  find "$VAULT/Work/ClaudeCode" -name "${TODAY}-*.md" -o -name "$(date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)-*.md"
  ```
- **`git log --since="24 hours ago" --oneline`** — all committed changes

Optional sources (skip if these folders don't exist):

- **`Logs/`** — most recent daily activity log entry, if you use that pattern
- **`Inbox/`** — anything captured since yesterday

Read each session log file you find. They're the primary source of truth for what was completed.

### 3. Review task files in `Tasks/` (optional — skip if you don't use this folder)

- **Mark done** any tasks whose work appears in session logs (update status field only — do not rewrite task bodies)
- **Surface unfiled inbox items** from `Inbox/` that haven't been made into tasks yet
- **Flag stale tasks** — open items older than 7 days with no recent activity

### 4. Write morning briefing

Today's briefing lives at the vault root as `MORNING_REVIEW.md`. Before writing it, archive the existing one (which is yesterday's, or whichever day it was last regenerated).

```bash
mkdir -p "$VAULT/Work/ClaudeCode/morning-review"

if [ -f "$VAULT/MORNING_REVIEW.md" ]; then
  # Pull the date out of the "# Morning Review — YYYY-MM-DD" header so we
  # archive under the file's own date, not today's.
  PREV_DATE=$(grep -m1 -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$VAULT/MORNING_REVIEW.md" || true)
  if [ -z "$PREV_DATE" ]; then
    PREV_DATE=$(date -r "$VAULT/MORNING_REVIEW.md" +%Y-%m-%d)
  fi
  if [ "$PREV_DATE" != "$TODAY" ]; then
    git -C "$VAULT" mv MORNING_REVIEW.md "Work/ClaudeCode/morning-review/${PREV_DATE}.md" 2>/dev/null \
      || mv "$VAULT/MORNING_REVIEW.md" "$VAULT/Work/ClaudeCode/morning-review/${PREV_DATE}.md"
  fi
fi
```

Write today's briefing to `$VAULT/MORNING_REVIEW.md` with these sections:

```markdown
# Morning Review — YYYY-MM-DD

> Optional: note any infra issues (e.g., git pull skipped — no network)

## Completed Yesterday
- **[ProjectTag]** What was done (one bullet per logical unit of work)

## Open Tasks (Prioritized)
Numbered list, most urgent first. Group by project. Include blockers.

## Inbox Items Needing Triage (optional)
Items from `Inbox/` not yet filed as tasks. If `Inbox/` doesn't exist or is empty, omit this section.

## Stale Items (Open > 7 Days, No Recent Activity) (optional)
Table: | File | Open Item | Age |
If `Tasks/` doesn't exist or there are no stale items, omit this section.

## Suggested Focus for Today
2–3 sentences. What to work on and why.
```

### 5. Regenerate VAULT_MAP.md

```bash
python3 "$VAULT/scripts/build-vault-map.py" --root "$VAULT"
```

Deterministic — running it twice in a row is a no-op. Do not hand-edit `VAULT_MAP.md`; if the output is wrong, fix the script.

### 6. Commit and push

```bash
git -C "$VAULT" $GIT_AUTHOR add MORNING_REVIEW.md VAULT_MAP.md
[ -n "${PREV_DATE:-}" ] && [ "$PREV_DATE" != "$TODAY" ] \
  && git -C "$VAULT" $GIT_AUTHOR add "Work/ClaudeCode/morning-review/${PREV_DATE}.md"
git -C "$VAULT" $GIT_AUTHOR commit -m "morning-review: $TODAY"
git -C "$VAULT" push
```

If push fails, the commit is still made locally — push manually later. Skip the commit entirely if nothing changed.

---

## Domain Rules

Per `AGENTS.md`:
- **Read** everywhere in the vault
- **Write** only to `MORNING_REVIEW.md` (today's briefing at root), `Work/ClaudeCode/morning-review/` (archived prior days), and `VAULT_MAP.md` (via `scripts/build-vault-map.py` — never hand-edit). If you use the optional `Tasks/` folder, write status-field updates there but not new task bodies.
- Do not write to `Work/context.md` (that belongs to the code agent's session-end protocol), or to the optional `Inbox/`/`Logs/`/`Personal/` folders if they exist.
