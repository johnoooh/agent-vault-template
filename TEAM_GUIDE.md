# Vault — Team Guide

A walkthrough of how to use an Obsidian vault as durable memory for a code agent (Claude Code, Codex) — tracking projects, capturing sessions, keeping a literature KB. This repo is the template; clone it, customize, and you're running.

The short version: it's an Obsidian vault in a git repo. The agent reads it at the start of every session to orient itself, and writes back to it at the end. The vault becomes a persistent project tracker that survives across sessions, machines, and model versions.

---

## 1. Why a vault at all

Code-agent sessions are stateless. Without external memory, every session starts from zero — re-reading code, re-deriving context, re-asking "where did we leave off." The vault fixes that by giving the agent a small, structured set of files to read first and write to last.

Concretely, you want one place where:

- **Project state** (what's running, what's broken, what's next) is durable across sessions and machines.
- **Session history** is captured automatically, not by remembering to journal.
- **Papers cited across projects** are summarized once and linked everywhere.
- **The dashboard regenerates itself** so you never hand-maintain an index.

Obsidian gives wiki-links (`[[note]]`) and a graph view. Git gives sync, history, and a pre-commit hook for security. That's the whole stack.

### Where this works (and where it doesn't)

This pattern is **built for terminal agents that run in a working directory and have file-system access** — Claude Code is the primary target, and Codex CLI works the same way. Both can `git pull` the vault at session start, read project READMEs, write session notes, and push back.

- **Claude Code** — protocol lives in `~/.claude/CLAUDE.md`. Hooks (`UserPromptSubmit`, etc.) and plugins like `claude-mem` slot in.
- **Codex CLI** — same protocol, set in `AGENTS.md` (Codex reads it natively). No hooks, but the read-vault-first / write-vault-last loop works identically.

What **doesn't** work:

- **Cowork** — sandboxed environment without persistent filesystem access to your machine. Fine for one-off runs against a mounted vault; useless as durable memory.
- **claude.ai (web)** — no filesystem at all. Web chat breaks both halves of the loop.

If your agent can't `git pull` a repo and `git push` back, this pattern doesn't apply.

---

## 2. Setup — clone this template

1. Click **"Use this template"** on GitHub (or `gh repo create your-vault --template <this-repo> --private --clone`).
2. Open the folder in Obsidian as a vault.
3. Activate the pre-commit hook:
   ```bash
   git config core.hooksPath .githooks
   chmod +x .githooks/pre-commit
   ```
4. Edit `.githooks/pre-commit` and replace the `SENSITIVE_PATTERN` regex with whatever ID shapes your data uses.
5. Skim `AGENTS.md` and tailor the ownership table / conventions to your workflow.
6. In your global agent config (`~/.claude/CLAUDE.md` for Claude Code, `~/.codex/...` for Codex), add the session-start / session-end protocol (see §3 below) pointing at your vault path.

### Folder layout

```
vault/
├── Notes/         # reference notes
├── Literature/    # paper KB (see §6)
│   ├── INDEX.md
│   ├── example-paper.md
│   └── inbox/     # drop PDFs or .txt with PMID/DOI/URL
├── Work/
│   ├── context.md            # live cross-project state — the dashboard source
│   └── ClaudeCode/<project>/ # per-project READMEs + session logs
├── docs/          # specs, plans, supporting docs
└── scripts/       # build-vault-map.py
```

**Optional add-on folders** — useful if you also use the vault as a general second-brain (not just agent memory). Create whichever fit your workflow; nothing in this template requires them.

| Folder | Use |
|---|---|
| `Inbox/` | Quick captures (works well with a phone-capture assistant like Sevry/OpenClaw) |
| `Tasks/` | Actionable task files by date |
| `Logs/` | Daily activity logs |
| `Personal/` | Non-work notes |

`VAULT_MAP.md` and the morning-review prompt both handle these gracefully whether or not they exist.

Two paths do the heavy lifting:

- **`Work/context.md`** — one block per active project. This is the file the morning dashboard is built from.
- **`Work/ClaudeCode/<project>/`** — one folder per project, containing a living `README.md` and dated session notes (`YYYY-MM-DD-HHMM.md`). Copy from `_template/` when starting a new project.

---

## 3. How the agent uses the vault

The vault is not the agent's working directory — code work happens in each project's own repo. The vault is the agent's *memory*. Bake this protocol into your global agent config (`~/.claude/CLAUDE.md` for Claude Code, equivalent for Codex) so every session everywhere reads/writes the vault the same way.

**At session start**
1. `git pull` the vault.
2. Read `AGENTS.md` (conventions).
3. Read `Work/context.md` (status of every active project).
4. Read `Work/ClaudeCode/<project>/README.md` (deep context for the project being worked on).

**At session end**
1. Write a session note → `Work/ClaudeCode/<project>/YYYY-MM-DD-HHMM.md` with sections: *What we worked on / Decisions / Files changed / Open questions*.
2. Update the project `README.md` if status, architecture, or open questions changed. (The README is a living doc, not a log — rewrite sections, don't append.)
3. Update the project's block in `Work/context.md` (status / last session / next).
4. Commit and push the vault.

Result: every project has a README that's always current, plus a chronological trail of session notes — effectively a git log for *thinking*, not just for code.

### What to paste into global `~/.claude/CLAUDE.md`

Inline the essentials — vault path, what to read, the session-log template, end-of-session steps, and a short domain table. The point is that the agent shouldn't need to load the vault's `AGENTS.md` for a normal session; `context.md` + project README are enough. Save `AGENTS.md` for the rare cases where the agent has to double-check ownership rules.

A ~50-line block like this:

````markdown
## Shared Vault

My Obsidian vault is at `~/path/to/your/vault`, synced via a private GitHub repo.

### At session start
```bash
git -C ~/path/to/your/vault pull --rebase --autostash
```
Then read:
- `Work/context.md` — current project state
- `Work/ClaudeCode/<project>/README.md` — project overview and current status
- `Inbox/` — anything captured since last session (if you use that folder)

### At session end (or when asked to log)

**1. Update the project README** at `Work/ClaudeCode/<project>/README.md`:
- Living doc — rewrite sections as things change, don't append
- Create it if it doesn't exist yet

**2. Write a session log** to `Work/ClaudeCode/<project>/YYYY-MM-DD-HHmm.md`:
```markdown
# Session: <project> — YYYY-MM-DD HH:mm

## What we worked on
## Decisions / approaches
## Files changed
## Open questions / next steps
```

**3. Push:**
```bash
git -C ~/path/to/your/vault add -A && git commit -m "claude-code: <project> session summary" && git push
```

### Domain rules
(Whatever ownership table fits your setup — see `AGENTS.md` for the canonical version.)

**Never write outside your domain without explicit instruction.**
````

**Why inline and not just say "read `AGENTS.md`"?** Cache economics. The global `CLAUDE.md` block is stable across sessions — it sits in the cached system prompt. Telling the agent to read a ~100-line file at the start of every session adds a fresh read each time, which is more expensive than the equivalent inlined content. Inline once, pay nothing per session.

**For Codex:** Codex picks up `AGENTS.md` natively, so the protocol half can be lighter — but you'll still want the session-start commands and the log template inlined in your global Codex config for the same caching reason.

---

## 4. The other memory layer — claude-mem

The vault is one half of the memory system. The other half is **claude-mem** — a Claude Code plugin (install via the Claude Code plugin marketplace; search `claude-mem`) that gives the agent a persistent, searchable database of *observations* across every session it has ever run. The two complement each other:

| | Vault | claude-mem |
|---|---|---|
| **Audience** | you (and the model) | the model |
| **Format** | human-readable Markdown | compressed observations indexed by ID |
| **Scope** | curated, structured, project-anchored | every session, automatically |
| **Lookup** | open Obsidian, click a wiki-link | semantic search / timeline / get by ID |
| **Cost to load** | cheap for you; expensive in tokens if dumped wholesale | thousands of tokens of past context for hundreds of tokens |
| **Best for** | "what is the status of project X" | "did we already solve this?" "how did we approach Y last time?" |

At session start, claude-mem injects a compact **context index** — titles, types, files, and IDs for recent observations, plus a token-cost line. The model decides which observations matter and fetches just those by ID. For older lookups it uses semantic search across the full history.

You almost never read claude-mem directly. It's the model's notebook. The vault is yours.

**Why both, not one:** the vault is small and curated — `context.md` is ~one paragraph per project. That's the right granularity for a human dashboard but loses the long tail of debugging context, ruled-out approaches, surprise findings. claude-mem captures that long tail automatically. Conversely, claude-mem is opaque to humans — without the vault you'd have no way to skim your own project state at a glance.

Codex doesn't have an equivalent today, but the vault half works the same way.

---

## 5. Daily workflow

### Morning
1. Open Obsidian → `MORNING_REVIEW.md` at the vault root. It's regenerated every morning by a scheduled agent run (see §8) — covers what got done yesterday, open tasks prioritized, inbox triage, stale items, and a suggested focus. The previous day's `MORNING_REVIEW.md` is auto-archived to `Work/ClaudeCode/morning-review/YYYY-MM-DD.md` before the new one is written.
2. Cross-check `VAULT_MAP.md` (auto-generated dashboard) for the row-per-project status / last session / next steps.
3. Pick a project. Open `Work/ClaudeCode/<project>/README.md` for deep context.

### Working a project
1. `cd` into the project repo (not the vault) and launch your agent.
2. The session-start protocol fires automatically.
3. Work happens in the project repo. The vault stays untouched until the end.
4. At session end the session-end protocol fires.

### End of week
- Skim recent session notes per project. The folder is its own changelog.
- Reconcile against `Work/context.md`. If a status block is stale, edit it directly.

---

## 6. Literature knowledge base

Papers you cite across projects live in `Literature/`:

- `Literature/INDEX.md` — topic-indexed table of contents.
- `Literature/<FirstAuthor>-<Year>-<Slug>.md` — one paper per file with YAML frontmatter (title, authors, year, journal, pmid, doi, tags, projects) and sections: *TL;DR / Key Findings / Methods / Limitations / Relevance to My Work / Notes*. See `Literature/example-paper.md` as the template.
- `Literature/inbox/` — drop a PDF or a `.txt` containing a PMID / DOI / URL here.

### Automated inbox processing (Claude Code only)

The `UserPromptSubmit` hook at `.claude/hooks/process-literature-inbox.sh` runs at the start of every Claude Code session. If `Literature/inbox/` is non-empty, it injects an instruction telling Claude to:

1. Fetch the paper (PubMed MCP for PMID/DOI, Read tool for PDF).
2. Fill the literature template and write the new `.md`.
3. Delete the inbox file.
4. Update `Literature/INDEX.md`.

Workflow for a new paper: drop the PDF or paste the PMID in a `.txt` into `Literature/inbox/`, open Claude Code, ask anything → it processes the inbox before responding. Zero manual templating.

> Codex users: the hook won't fire automatically. Either invoke the inbox-processing prompt manually, or wire it into your shell startup if you want similar behavior.

Project READMEs and literature notes link to each other bidirectionally — every Literature note's "Relevance to My Work" section points at `[[Work/ClaudeCode/<project>/README]]`, and project READMEs have a `## References` section linking back. Wiki-links make Obsidian's graph view actually useful.

---

## 7. Security — the pre-commit hook

`.githooks/pre-commit` blocks:

1. **`.DS_Store`** from being committed at all.
2. **Sensitive ID patterns** in staged content or filenames.

The default `SENSITIVE_PATTERN` catches clinical sample-ID formats (`P-XXXXXXX`, `C-XXXXXX`, `s_C_XXXXXX`) — common in biomedical / oncology workflows. **Edit the regex** for your domain (cloud keys, internal account IDs, employee numbers, whatever).

If a commit hits the pattern the hook prints the offending line/file and exits 1. Bypass is `--no-verify` and you should basically never use it; scrub the file instead. This kind of hook has caught real leaks in the wild (e.g. a sample ID embedded in a design doc).

---

## 8. Morning review + VAULT_MAP automation

Two things regenerate themselves every morning:

### `MORNING_REVIEW.md` (the daily briefing)

A scheduled agent runs the prompt at `Work/ClaudeCode/morning-review/vault-review-prompt.md`. It:

1. Pulls the vault.
2. Reads yesterday's session logs across `Work/ClaudeCode/*/`, plus `git log --since="24 hours ago"`. If the optional `Logs/` folder exists, reads the most recent entry too.
3. Reconciles the optional `Tasks/` folder if present (marks status fields, flags stale items). Skipped otherwise.
4. **Archives the previous `MORNING_REVIEW.md`** at the vault root into `Work/ClaudeCode/morning-review/YYYY-MM-DD.md` (using the date in the file's own header, not today's date — so if the agent skips a day, the archive name stays accurate).
5. **Writes the new briefing to `MORNING_REVIEW.md`** at the vault root, with sections: *Completed Yesterday / Open Tasks (Prioritized) / Inbox Items Needing Triage / Stale Items / Suggested Focus for Today*.
6. Regenerates `VAULT_MAP.md`.
7. Commits and pushes.

The root-level `MORNING_REVIEW.md` is the single file you open first thing. The archive under `Work/ClaudeCode/morning-review/` is a searchable record of past briefings (useful for "when did I first flag X as stuck?").

How you schedule it is up to you: cron + headless Claude Code session, a GitHub Actions workflow, or just run by hand each morning.

### `VAULT_MAP.md` (the dashboard)

Regenerated by `scripts/build-vault-map.py`. It produces:

- A folder-count table.
- An **Active Projects** section parsed from `Work/context.md` (one entry per `## Active Project: <name>` block).
- A **Recent Activity** table from the last 15 commits touching markdown files.

Deterministic — running it twice in a row produces a no-op diff. To change project status edit `Work/context.md`, not the map.

Between the two, you never hand-maintain either the daily briefing or the structural index. The morning review is the single most useful piece of automation in the vault.

---

## 9. Things to keep in mind

- **The README is the artifact; session notes are the trail.** The project README must stay current — the agent rewrites it. Session notes are write-once and rarely re-read. Don't over-curate.
- **Keep `context.md` short.** One paragraph per active project: status / last session / next. If it grows beyond that, archive into the project README. The dashboard depends on this file staying scannable.
- **Don't manually maintain indexes.** Anything you can regenerate from existing content, regenerate. VAULT_MAP, INDEX, anything similar. Hand-maintained indexes rot within a week.
- **Wiki-links are free; use them aggressively.** `[[Work/ClaudeCode/<project>/README]]` from a literature note costs nothing and pays off every time you traverse the graph.
- **The pre-commit hook is worth more than it looks.** A one-shot investment that turns "did I just leak an ID?" from a recurring fear into a non-issue.
- **Bake the protocol into the global agent config, not into each project.** Then every session everywhere reads the vault the same way. New projects inherit the discipline for free.
- **Let the agent own the writes.** The whole reason it works is that the agent is the one keeping state fresh. If you start hand-editing READMEs out from under it, you'll diverge.

---

## 10. Files to know in this template

- `AGENTS.md` — conventions
- `LICENSE` — MIT
- `.githooks/pre-commit` — security gate (customize the regex)
- `.gitignore` — sane defaults
- `scripts/install.sh` — one-time setup (activates the hook, marks scripts executable)
- `scripts/build-vault-map.py` — dashboard generator
- `.claude/hooks/process-literature-inbox.sh` + `.claude/settings.json` — literature automation (Claude Code)
- `Work/context.md` — project state block template
- `Work/ClaudeCode/_template/` — per-project README + session-note skeleton
- `Work/ClaudeCode/morning-review/vault-review-prompt.md` — the morning-review prompt
- `MORNING_REVIEW.md` — placeholder at the vault root; rewritten by the morning-review prompt
- `Literature/example-paper.md` — paper note template
- `Literature/INDEX.md` — topic-indexed literature table of contents
