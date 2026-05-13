# AGENTS.md — Vault Agent Guide

This is a shared agent vault. Any agent (Claude Code, Codex, etc.) that has filesystem access to this repo can use it as durable cross-session memory.

---

## Folder Structure

```
vault/
├── Notes/         # Reference notes
├── Literature/    # Paper knowledge base (see Literature/INDEX.md)
├── docs/          # Specs, plans, supporting docs
└── Work/
    ├── context.md             # Live cross-project state (the dashboard source)
    └── ClaudeCode/            # Per-project READMEs + session notes
        └── <project>/
            ├── README.md              # Living project overview
            └── YYYY-MM-DD-HHMM.md     # Per-session notes
```

> The `Work/ClaudeCode/` name is historical — it's where any code-writing agent (Claude Code, Codex, etc.) drops session notes. Rename if you like.

### Optional extras

If you also use the vault as a general second-brain (not just an agent memory store), these folders are common additions. Create whichever fit your workflow; the agent-memory side of the vault doesn't require any of them.

| Folder | Use |
|---|---|
| `Inbox/` | Quick captures awaiting triage (good for a phone-capture agent like Sevry/OpenClaw) |
| `Tasks/` | Actionable task files by date |
| `Logs/` | Daily activity logs |
| `Personal/` | Non-work notes |

The auto-generated `VAULT_MAP.md` and the morning-review prompt both handle these gracefully whether they exist or not.

---

## Ownership

If you run more than one agent against the vault (e.g. a phone-capture assistant *and* a code agent), assign clear write-ownership per path so they don't clobber each other. Suggested default:

| Path | Writer | Others |
|---|---|---|
| `Work/context.md`, `Work/ClaudeCode/` | code agent (Claude Code / Codex) | read-only |
| `Literature/`, `Notes/`, `docs/` | either, but coordinate | — |
| Optional `Inbox/`, `Tasks/`, `Logs/`, `Personal/` | personal-assistant agent | code agent: read-only |

> **Rule:** Don't write outside your owned paths without explicit instruction.

If you only run one agent, ignore the column and treat the whole vault as writable.

---

## Conventions

### File Naming
- **Captures / Tasks / Logs:** `YYYY-MM-DD-<slug>.md`
- **Session notes:** `YYYY-MM-DD-HHMM.md`
- **Slugs:** lowercase, hyphen-separated, descriptive

### Task Format
```markdown
- [ ] Task description
- [x] Completed task (done YYYY-MM-DD)
```

### Commit Messages
- Keep them short and descriptive
- Prefix with action: `Add`, `Update`, `Done`, `Fix`
- Examples: `Add task: renew passport`, `Done: e2e pipeline test`, `Update context: <project> session`

### Sync Protocol
- `git pull` before reading
- `git add -A && git commit -m "<msg>" && git push` after writing
- Never force-push

---

## `Work/context.md` — Cross-Session State

The code agent maintains `Work/context.md` as a live project status file. Other agents read it to answer "what's the status of X?"

Format per project:
```markdown
## Active Project: <name>
- **Status:** <one-line summary>
- **Last session:** YYYY-MM-DD — <what was done>
- **Next:** <next actions>
```

This file is the source of truth for the auto-generated `VAULT_MAP.md` dashboard. Keep one paragraph per project; archive deeper context into the project README.

---

## For a New Code-Agent Session

1. `git pull` the vault.
2. Read this file (`AGENTS.md`).
3. Read `Work/context.md` for current project state.
4. Read `Work/ClaudeCode/<project>/README.md` for deep context on the project you're touching.
5. Work happens in the project's own repo, not the vault.
6. At session end, write `Work/ClaudeCode/<project>/YYYY-MM-DD-HHMM.md`, update the project README and `Work/context.md`, commit and push.

That's it. You're oriented.
