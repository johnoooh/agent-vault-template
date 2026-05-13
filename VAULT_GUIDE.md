# Vault — Internals Guide

A walkthrough of how I use an Obsidian vault as durable memory for Claude Code — tracking projects, capturing sessions, and keeping a literature KB. Written for teammates who want to copy the pattern.

> For the broader Claude Code workflow (how the vault fits into kickoff, brainstorming, planning, execution, and context hygiene), see [`TEAM_GUIDE.md`](./TEAM_GUIDE.md).

The short version: it's an Obsidian vault in a private git repo. Claude Code reads it at the start of every session to orient itself, and writes back to it at the end. That's it. The vault becomes a persistent project tracker that survives across sessions, machines, and model versions.

---

## 1. Why a vault at all

Claude Code sessions are stateless. Without external memory, every session starts from zero — re-reading code, re-deriving context, re-asking "where did we leave off." The vault fixes that by giving Claude Code a small, structured set of files to read first and write to last.

Concretely, I wanted one place where:

- **Project state** (what's running, what's broken, what's next) is durable across sessions and machines.
- **Session history** is captured automatically, not by me remembering to journal.
- **Papers I cite across projects** are summarized once and linked everywhere.
- **The dashboard regenerates itself** so I never hand-maintain an index.

Obsidian gives wiki-links (`[[note]]`) and a graph view. Git gives sync, history, and a pre-commit hook for security. That's the whole stack.

No Obsidian Sync — git is doing that job. The paid Sync service is the official path, but git buys you full version history, a pre-commit hook that can scan for secrets before anything leaves your machine, and identical access for every agent and device that already speaks git. No subscription, no separate auth surface.

### Where this works (and where it doesn't)

This pattern is **built for terminal agents that run in a working directory and have file-system access** — Claude Code is the primary target, and Codex CLI works the same way. Both can `git pull` the vault at session start, read project READMEs, write session notes, and push back. The protocol drops in cleanly:

- **Claude Code** — protocol lives in `~/.claude/CLAUDE.md`. Hooks (`UserPromptSubmit`, etc.) and plugins like `claude-mem` slot in.
- **Codex CLI** — same protocol, set in `AGENTS.md` (Codex reads it natively) or the equivalent system prompt. No hooks, but the read-vault-first / write-vault-last loop works identically.

What **doesn't** work:

- **Cowork** — runs in a sandboxed environment without persistent filesystem access to your machine. You can mount the vault in for a single session, but there's no continuity — the session ends and the mount is gone. Fine for one-off runs against the vault; useless as durable memory.
- **claude.ai (web)** — no filesystem at all. You can paste vault contents in by hand, but the whole point of this system is that the agent reads and writes autonomously. Web chat breaks both halves of the loop.

If your agent can't `git pull` a repo and `git push` back, this pattern doesn't apply. The vault is only useful when the agent itself maintains it.

---

## 2. Setup — copy this

### 2.1 Create the repo

```bash
mkdir ~/Documents/Github/<your_vault>
cd ~/Documents/Github/<your_vault>
git init
gh repo create <your_vault> --private --source=. --remote=origin
```

Open the folder in Obsidian as a vault.

### 2.2 Required top-level files

- `AGENTS.md` — conventions every agent that touches the vault should follow (file naming, commit style, where to write).
- `VAULT_MAP.md` — **auto-generated** by `scripts/build-vault-map.py`. Don't edit by hand.
- `MORNING_REVIEW.md` — today's briefing, regenerated each morning. Previous day's copy gets archived to `Work/ClaudeCode/morning-review/YYYY-MM-DD.md` automatically (see §8).
- `.gitignore` — must block `.DS_Store`, `.obsidian/workspace*`, and anything that could contain sensitive data.
- `.githooks/pre-commit` — blocks sensitive IDs and `.DS_Store` from being committed. Activate with:
  ```bash
  git config core.hooksPath .githooks
  chmod +x .githooks/pre-commit
  ```

### 2.3 Folder layout

```
vault/
├── Notes/        # ad-hoc reference notes
├── Literature/   # paper KB (see §5)
│   ├── INDEX.md
│   └── inbox/    # drop PDFs or .txt with PMID/DOI/URL
├── Work/
│   ├── context.md            # live project state — the dashboard source
│   └── ClaudeCode/<project>/ # per-project READMEs + session logs
├── docs/         # specs, plans, supporting docs
└── scripts/      # build-vault-map.py, etc.
```

Two paths do the heavy lifting:

- **`Work/context.md`** — one block per active project. This is the file the morning dashboard is built from.
- **`Work/ClaudeCode/<project>/`** — one folder per project, containing a living `README.md` and dated session notes (`YYYY-MM-DD-HHMM.md`).

---

## 3. How Claude Code uses the vault

The vault is not Claude Code's working directory — code work happens in each project's own repo. The vault is Claude Code's *memory*. The protocol is set in the global `~/.claude/CLAUDE.md` so every Claude Code session everywhere reads/writes the vault the same way.

This read-at-start / write-at-end loop only works because sessions are bounded — `/clear` between tasks means nothing accumulates in conversation history that should have been written to disk. See [`TEAM_GUIDE.md`](./TEAM_GUIDE.md) §§8–9 for the bounded-sessions discipline this depends on.

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

The result: every project has a README that's always current, plus a chronological trail of session notes that's effectively a git log for *thinking*, not just for code.

### What to paste into global `~/.claude/CLAUDE.md`

Inline the essentials — vault path, what to read, the session-log template, end-of-session steps, and the domain table. The point is that the agent shouldn't need to load the vault's `AGENTS.md` for a normal session; `context.md` + project README are enough. Save `AGENTS.md` for the rare cases where the agent has to double-check ownership rules.

The block I run with is ~50 lines and looks like this:

````markdown
## Shared Vault

My Obsidian vault is at `~/Documents/Github/<your_vault>`, synced via a private GitHub repo.

### At session start
```bash
git -C ~/Documents/Github/<your_vault> pull --rebase --autostash
```
Then read:
- `Work/context.md` — current project state
- `Work/ClaudeCode/<project>/README.md` — project overview and current status
- `Inbox/` — anything captured since last session (optional folder; only if you use it)

### At session end (or when asked to log)

**1. Update the project README** at `Work/ClaudeCode/<project>/README.md`:
- Living doc — rewrite sections as things change, don't append
- Create it if it doesn't exist yet

**2. Write a session log** to `Work/ClaudeCode/<project>/YYYY-MM-DD-HHmm.md`:
```markdown
# Session: <project> — YYYY-MM-DD HH:mm

## What we worked on
## Decisions
## Files changed
## Open questions / next steps
```

**3. Push:**
```bash
git -C ~/Documents/Github/<your_vault> add -A && git commit -m "claude-code: <project> session summary" && git push
```

### Domain rules
(Whatever ownership table fits your setup — see `AGENTS.md` for the canonical version.)

**Never write outside your domain without explicit instruction.**
````

Why inline instead of pointing at `AGENTS.md`? Cache economics — see [`TEAM_GUIDE.md`](./TEAM_GUIDE.md) §2. The short version: the global `CLAUDE.md` block sits in the cached system prompt and costs nothing per session; an "read `AGENTS.md` first" instruction pays the read cost every time.

---

## 4. The other memory layer — claude-mem

The vault is one of three durable memory layers — vault, claude-mem, and git (commit messages + diffs). See [`TEAM_GUIDE.md`](./TEAM_GUIDE.md) §10 for the three-layer framing; this section zooms in on the vault-vs-claude-mem split.

**claude-mem** is a Claude Code plugin (install via the Claude Code plugin marketplace; search `claude-mem`) that gives the agent a persistent, searchable database of *observations* across every session it has ever run. The two complement each other:

| | Vault | claude-mem |
|---|---|---|
| **Audience** | me (and the model) | the model |
| **Format** | human-readable Markdown | compressed observations indexed by ID |
| **Scope** | curated, structured, project-anchored | every session, automatically |
| **Lookup** | open Obsidian, click a wiki-link | semantic search / timeline / get by ID |
| **Cost to load** | I read it; cheap for me, expensive in tokens if dumped | thousands of tokens of past context for hundreds of tokens |
| **Best for** | "what is the status of project X" | "did we already solve this?" "how did we approach Y last time?" |

### How claude-mem fits in

At session start, claude-mem injects a compact **context index** — titles, types, files, and IDs for recent observations, plus a token-cost line ("122k tokens of past research available for 12.6k to read"). The model sees the index, decides which observations matter, and fetches just those by ID via the `get_observations` MCP tool. For older or cross-session lookups, the `mem-search` skill orchestrates a three-step workflow over the `search`, `timeline`, and `get_observations` tools — index first (cheap), narrow with `timeline`, then batch-fetch only the IDs that matter. Observations are captured automatically by a `PostToolUse` hook; a `Stop` hook writes a session summary at turn end.

I almost never read claude-mem directly. It's the model's notebook. The vault is mine.

### When I lean on which

- **Looking up project status, decisions I made, or papers I read** → vault. Markdown is faster to scan than chasing observation IDs.
- **Asking "have we hit this bug before / what did we try / why did we abandon approach X"** → claude-mem. The model searches its own history and surfaces the relevant observation in one shot.
- **Onboarding a new Claude Code session into an unfamiliar project** → both. The vault gives the README; claude-mem gives the texture (what was surprising, what failed, what we ruled out).

### Why both, not one

The vault is *small and curated* — `context.md` is ~one paragraph per project. That's the right granularity for a human dashboard but loses the long tail of debugging context, ruled-out approaches, and surprise findings. claude-mem captures that long tail automatically, so I don't have to decide what's worth writing down. Conversely, claude-mem is opaque to me — without the vault I'd have no way to skim my own project state at a glance.

The split also has a cost angle: the model can pull thousands of tokens of relevant context out of claude-mem for the price of a few hundred tokens of index reading. Dumping the equivalent material from the vault into the prompt would be far more expensive and far less targeted.

Practical setup: install the `claude-mem` plugin, then trust the defaults. It will start populating observations from the session it's installed in. The compounding return is real — by month three the model is regularly surfacing "we hit this in February, the fix was X" from sessions I had completely forgotten. This has actually happened to me.  I have seen it agree with decisions I tracked in the the vault as well.  

---

## 5. Daily workflow

### Morning
1. Open Obsidian → `MORNING_REVIEW.md` at the vault root. It's regenerated every morning by a Claude Code agent (see §8) — covers what got done yesterday, open tasks prioritized, inbox triage, stale items, and a suggested focus. When the next morning's review runs, this file gets archived to `Work/ClaudeCode/morning-review/YYYY-MM-DD.md` and a fresh `MORNING_REVIEW.md` lands at the root.
2. Cross-check `VAULT_MAP.md` (auto-generated dashboard) for the row-per-project status / last session / next steps.
3. Pick a project. Open `Work/ClaudeCode/<project>/README.md` for deep context.

### Working a project
1. `cd` into the project repo (not the vault) and launch Claude Code.
2. The session-start protocol fires automatically (`git pull` vault, read context, read README).
3. Work happens in the project repo. The vault stays untouched until the end.
4. At session end the session-end protocol fires (session note + README + `context.md` + commit/push).

### End of week
- Skim recent session notes per project. The folder is its own changelog.
- Reconcile against `Work/context.md`. If a status block is stale, edit it directly.

---

## 6. Literature knowledge base

Papers I cite across projects live in `Literature/`. Structure:

- `Literature/INDEX.md` — topic-indexed table of contents (e.g. HLA Analysis / Immunotherapy / Methods).
- `Literature/<FirstAuthor>-<Year>-<Slug>.md` — one paper per file with YAML frontmatter (title, authors, year, journal, pmid, doi, tags, projects) and sections: *TL;DR / Key Findings / Methods / Limitations / Relevance to My Work / Notes*.
- `Literature/inbox/` — drop a PDF or a `.txt` containing a PMID / DOI / URL here.

### Automated inbox processing

The `UserPromptSubmit` hook at `.claude/hooks/process-literature-inbox.sh` runs at the start of every Claude Code session. If `Literature/inbox/` is non-empty, it injects an instruction telling Claude to:

1. Fetch the paper (PubMed MCP for PMID/DOI, Read tool for PDF).
2. Fill the literature template and write the new `.md`.
3. Delete the inbox file.
4. Update `Literature/INDEX.md`.

So my workflow for a new paper is: drop the PDF or paste the PMID in a `.txt` into `Literature/inbox/`, open Claude Code, ask anything → it processes the inbox before responding. Zero manual templating.

Project READMEs and literature notes link to each other bidirectionally — every Literature note's "Relevance to My Work" section points at `[[Work/ClaudeCode/<project>/README]]`, and project READMEs have a `## References` section linking back. Wiki-links make the Obsidian graph view actually useful.

---

## 6.5. Meeting notes — `Notes/meetings/inbox/`

Meeting decisions are the same shape as session-note Decisions: a choice + the reason. They belong in the same homes — the relevant project README's Decisions section, and `Work/context.md` if status shifted. Raw meeting notes sitting only in `Notes/` are invisible to the project READMEs, invisible to `git log`, and quietly forgotten.

I currently do this extraction manually: jot the note in `Notes/` during the meeting, then at the next relevant session ask Claude to extract decisions into the right project doc. It works, but it's discipline-dependent — busy weeks mean decisions stay stranded.

**The pattern I'd recommend (and the one I'm moving to):** mirror the Literature inbox.

1. Capture the raw note in the meeting: `Notes/meetings/inbox/2026-05-13-team-sync.md`. End the note with a `## Decisions` section (2–5 bullets, same format as session-note Decisions — "we chose X because Y").
2. A `UserPromptSubmit` hook (sibling of `process-literature-inbox.sh`) detects non-empty `Notes/meetings/inbox/` and instructs Claude to:
   - Infer which project(s) each note touches (from explicit tags, mentions, or content).
   - Append the decisions into those projects' READMEs, with a `[[Notes/meetings/2026-05-13-team-sync]]` backlink.
   - Update `Work/context.md` blocks if status changed.
   - Move the processed file from `Notes/meetings/inbox/` → `Notes/meetings/`.
3. The raw note becomes the audit trail; the decisions live where you'll re-read them.

The cost is ~30 lines of shell modeled on the literature hook. Worth it if you have 2+ decision-bearing meetings a week.

**Habit that makes either flow cheap.** Separate "raw thread" from "decisions" in the note itself with a `## Decisions` header at the bottom. The structure-first habit makes the extraction trivial — manual or automated — because Claude doesn't have to infer which lines are decisions vs. discussion.

### Future direction — meeting transcripts

Some people on the team already have Teams transcriptions available — that's the easiest source. Vignesh has built a transcription summarizer and is the right person to talk to before reinventing it; check with him on what's already working for him.

The natural extension of the inbox pattern: drop the transcript (or some kind of summarizer output) into `Notes/meetings/inbox/` instead of (or alongside) the hand-written note, and let the hook extract decisions, action items, and open questions from the full text rather than just your summary.

Things to think about if you go this direction:

- **PHI / clinical data.** A transcript captures everything said. If meetings touch patient data, the transcript is now PHI — needs to live behind the same guardrails as the rest of your clinical data, and probably never in a cloud transcription service. Local Whisper + local LLM extraction is the safer pattern.
- **Signal-to-noise.** Raw transcripts are mostly noise; the extraction prompt matters more than the transcription quality. "Pull out decisions made, action items assigned, and open questions" is a reasonable starting prompt; iterate based on what comes back useful vs. what's filler.
- **What ends up in the vault.** The vault should get the extracted structured output, not the full transcript. Transcripts are large, mostly worthless after a week, and risky to commit. Store them outside the vault (or in a gitignored path) and only commit the distilled decisions/actions.
- **The diff layer.** Action items belong somewhere actionable — `Tasks/` if you use it, or a project README's "Open Questions / Next Steps" section. Decisions belong in the project README Decisions section. Don't pile everything into one note.

I haven't built this yet — if someone on the team prototypes it, the inbox hook is the natural drop-in point and the output format should match what manual extraction produces today.  I think a local model would be able to do a lot of this depending on the length of the meeting.  Local model's context is often small, so longer meetings could fill it up. 

---

## 7. Security — the pre-commit hook

I work with clinical-adjacent data, so the vault has hard guardrails. `.githooks/pre-commit` blocks:

1. **`.DS_Store`** from being committed at all.
2. **Sensitive ID patterns** in staged content or filenames:
   - `P-XXXXXXX` (7 digits)
   - `C-XXXXXX` (6 digits)
   - `s_C_XXXXXX` (6 digits)

If a commit hits these patterns the hook prints the offending line/file and exits 1. Bypass is `--no-verify` and I never do it; I scrub the file instead. 

If you adapt this for your team, change the regexes to whatever ID format your data has.

---

## 8. Morning review + VAULT_MAP automation

Two things regenerate themselves every morning:

### `MORNING_REVIEW.md` (the daily briefing)

A scheduled Claude Code agent runs the prompt at `Work/ClaudeCode/morning-review/vault-review-prompt.md`. It:

1. Pulls the vault.
2. Reads yesterday's session logs across `Work/ClaudeCode/*/`, plus `git log --since="24 hours ago"`. Also reads the most recent `Logs/` and `Tasks/` entries if those folders are populated.
3. Reconciles `Tasks/` if used — marks status fields on tasks whose work appears in session logs, flags stale items.
4. **Archives the previous `MORNING_REVIEW.md`** at the vault root into `Work/ClaudeCode/morning-review/YYYY-MM-DD.md` (using the date in the file's own header, not today's date — so if the agent skipped a day, the archive name stays accurate).
5. **Writes the new briefing to `MORNING_REVIEW.md`** at the vault root, with sections: *Completed Yesterday / Open Tasks (Prioritized) / Inbox Items Needing Triage / Stale Items / Suggested Focus for Today*.
6. Regenerates `VAULT_MAP.md`.
7. Commits and pushes.

The root-level `MORNING_REVIEW.md` is the single file I open first thing — it's the digest of everything that happened while I was away. The history under `Work/ClaudeCode/morning-review/` becomes a searchable record of past briefings (useful for "wait, when did I first flag X as stuck?").

### `VAULT_MAP.md` (the dashboard)

Regenerated by `scripts/build-vault-map.py`. It produces:

- A folder-count table.
- An **Active Projects** section parsed from `Work/context.md` (one entry per `## Active Project: <name>` block).
- A **Recent Activity** table from the last 15 commits touching markdown files.

The script is deterministic — running it twice in a row produces a no-op diff. To change project status I edit `Work/context.md`, not the map.

Between the two, I never hand-maintain either the daily briefing or the structural index. The morning review is the single most useful piece of automation in the vault.

---

## 9. Things I'd tell a teammate adopting this

- **The README is the artifact; session notes are the trail.** The project README must stay current — Claude Code rewrites it. Session notes are write-once and you'll rarely re-read most of them. Don't over-curate.
- **Keep `context.md` short.** One paragraph per active project: status / last session / next. If it grows beyond that, archive into the project README. The dashboard depends on this file staying scannable.
- **Don't manually maintain indexes.** Anything that can be regenerated from existing content, regenerate. VAULT_MAP, INDEX, anything similar. Hand-maintained indexes rot within a week.
- **Wiki-links are free; use them aggressively.** `[[Work/ClaudeCode/<project>/README]]` from a literature note costs nothing and pays off every time you traverse the graph.
- **The pre-commit hook is worth more than it looks.** A one-shot investment that turns "did I just leak an ID?" from a recurring fear into a non-issue.
- **Bake the protocol into global `CLAUDE.md`, not into each project.** Then every Claude Code session everywhere reads the vault the same way. New projects inherit the discipline for free.
- **Let Claude Code own the writes.** The whole reason it works is that Claude Code is the one keeping state fresh. If you start hand-editing READMEs out from under it, you'll diverge. 

---

## 10. Files to crib from this repo

If you want to copy the pattern, these are the load-bearing files:

- `AGENTS.md` — conventions
- `.githooks/pre-commit` — security gate
- `.gitignore` — `.DS_Store`, `.obsidian/workspace*`, anything sensitive
- `scripts/build-vault-map.py` — auto-index generator
- `.claude/hooks/process-literature-inbox.sh` + `.claude/settings.json` — literature automation
- `Work/context.md` — template for project state blocks
- `Work/ClaudeCode/<project>/README.md` — template for a living project doc
- `Literature/<example>.md` — paper note template
- This file — the meta-explanation
