> For vault internals (file layout, automation, security hooks), see [`VAULT_GUIDE.md`](./VAULT_GUIDE.md).

# Claude Code Workflow Guide

How I actually run Claude Code — the loop, the skills, the model choices, the memory layers, and the context-hygiene rules. Written for teammates who want the pattern.

Assumes the CLI is installed.

---

## §1. TL;DR — the loop

Five steps, repeating:

1. **Kickoff** — `/init` if there's existing material (scripts, PDF, polished prompt). Otherwise skip to §4.
2. **Brainstorm** — `superpowers:brainstorming` for anything non-trivial. Produces a validated spec.
3. **Plan** — built-in plan mode (often with `opusplan`) for medium tasks; `superpowers:writing-plans` when subagents will execute.
4. **Execute** — TDD, subagents, code review. See §6.
5. **Close** — session note → vault push → `/clear`. Every time, no exceptions.

**Model picker:** Opus/opusplan = think and design. Sonnet = execute. Haiku = parallel cheap work. See §7.

**Thinking:** `think` through `ultrathink` — dial up for design decisions and gnarly debugging, off by default. See §7.5.

---

## §2. Why this exists

Three principles the whole pattern rests on:

**Bounded sessions.** Clear context in, clear context out. Durability lives in the vault and claude-mem, not in chat history. A session that ends cleanly costs almost nothing to resume — you read the project README, load the latest session note, and you're oriented in a few hundred tokens. A session that sprawls costs a lot to reload and tends to drift.

**Discipline in skills, not in your head.** Brainstorming, planning, TDD, code review — they're skills the agent invokes consistently. You stop having to remember to do them. The skills enforce the gates: brainstorming enforces "no implementation until design approved." TDD enforces "tests before code." You don't rely on the agent's initiative or your own memory.

**Rules in CLAUDE.md and hooks, not in vibes.** The global `~/.claude/CLAUDE.md` is the durable enforcement layer: identity, environment defaults (uv/mamba/conda strategy, HPC partition), hard security rules ("NEVER commit secrets or patient IDs"), new-project scaffolding standards, and the vault protocol. Hooks (see §12) backstop the agent when it would otherwise violate a rule. Rules in CLAUDE.md survive model updates, session resets, and teammates using a different machine.

A practical corollary: **inline durable content into `~/.claude/CLAUDE.md` rather than telling the agent to read a file at session start.** The global block sits in the cached system prompt and costs nothing per session. A "read `AGENTS.md` first" instruction pays the read cost every time. Reserve external files for material that's genuinely needed only occasionally — the canonical version can live elsewhere, but the day-to-day content belongs inline.

The three principles interact. Bounded sessions only work because the skills and CLAUDE.md discipline are durable — otherwise clearing context means losing everything you built. Skills only work consistently because CLAUDE.md defines the defaults so you're not re-negotiating them each session. CLAUDE.md only works because hooks provide the hard enforcement layer when the agent would drift. Remove any leg and the system is weaker.

This guide is about *the pattern*, not the tools. Claude Code is the agent, but the loop — brainstorm before building, plan before executing, write notes before clearing — is transferable to any sufficiently capable agent with file-system access.

**Onboarding shortcut:** I'll share my `~/.claude/CLAUDE.md` directly — adopt the parts you want, edit the rest.

---

## §3. Kickoff — you're rarely starting from scratch

Realistic on-ramps:

**Folder with existing scripts.** Drop the scripts in, open the folder, run `claude`, then `/init`. The agent reads the contents, infers purpose and structure, and generates a `CLAUDE.md`. Review what was generated — the inferred "purpose" usually needs a sentence or two of tightening. Commit it, then move on to brainstorming.

```bash
cd ~/my-project
claude
# inside Claude Code:
/init
# review CLAUDE.md, edit the overview, save
# commit and proceed to brainstorm
```

**PDF or prompt from elsewhere.** Drop it in the folder, then either `/init` (lets the agent absorb it during scaffolding) or skip straight to brainstorming: "read `paper.pdf`, then brainstorm a plan for implementing the method in section 3."

**One-off exploration.** Skip `/init`. The CLAUDE.md overhead won't pay off in a single-session throwaway. Just talk.

**Pre-polished prompt from another session.** Don't carry the building-it-elsewhere context forward — see §4 for the `/clear`-then-execute escape hatch.

---

## §4. Brainstorm — turn an idea into a spec

The `superpowers:brainstorming` skill. What it does: asks clarifying questions one at a time, proposes 2–3 approaches with trade-offs, presents a design section by section, and writes the validated spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.

```text
/brainstorm
# or invoke via skill:
# superpowers:brainstorming
```

When to invoke: anything non-trivial. Rough rule — if a wrong design decision would cost more than an hour to undo, brainstorm it first. For single-file edits, renames, doc tweaks: skip it, just talk through the change.

The critical gate the skill enforces is "no implementation until design approved." The agent will not start writing code until you've signed off on the approach. That gate is the whole value. Resist the urge to skip it when you think you already know the answer — the clarifying questions tend to surface constraints you hadn't named.

**The pre-polish escape hatch.** If you already spent a lot of context building the prompt elsewhere (drafting requirements, pulling in references, iterating), running brainstorming on top of it just adds noise. Instead: `/clear`, then re-issue the polished prompt with "execute this using superpowers:executing-plans." You keep the clean context, and the subagents get a focused task. Same bounded-sessions principle as §8 — don't drag finished thinking into the execution context.

**The spec as a written contract.** When brainstorming produces the spec, you have: the approach you chose, the approaches you rejected and why, any explicit constraints surfaced during the Q&A, and the review checkpoints the plan needs to hit. That's what §5 planning consumes. A subagent that reads a well-written spec from brainstorming can execute independently without re-asking design questions. A subagent that reads a vague prompt cannot.

The spec also serves as a session boundary. You can brainstorm in one session, `/clear`, and execute in the next — the spec in `docs/superpowers/specs/` is the handoff. No context needed; just the file.

---

## §5. Plan — built-in plan mode vs. superpowers writing-plans

Two tiers, picked by *who will execute the plan*:

**Built-in plan mode.** Trigger with `/plan` or shift-tab into plan mode. Often pair with the `opusplan` model for heavier planning. Plan mode writes the plan to a real `.md` file (auto-generated name like `dreamy-orbiting-quokka.md`) in Claude Code's plans folder, then `ExitPlanMode` surfaces it for your approval. Lightweight, executed in the same session, no formal review checkpoints or subagent handoffs. Good for medium tasks where you want alignment on the approach before touching code. The file survives the session but it's not where you'd point a future agent — if you want the plan as a long-lived contract, use `writing-plans` instead (next).

```text
/plan
# or shift-tab → plan mode
# ask: "plan the implementation of X"
```

**`superpowers:writing-plans`.** Phased written plan with explicit review checkpoints. Designed for `superpowers:executing-plans` or `superpowers:subagent-driven-development` to consume. The plan is written to disk and survives a `/clear` between brainstorming and execution. Use when:

- The work is multi-phase and subagents will execute phases independently.
- You want a written contract that a future session can pick up without context.
- You'll be handing the plan off to a teammate or a different agent.

```text
# invoke the skill:
# superpowers:writing-plans
```

**Third option — `claude-mem make-plan` / `do`.** Phased plan with automated subagent execution. I don't lean on it day-to-day, but it's there if you want a more automated flow than manually stepping through `executing-plans`.

**Rule of thumb:** if the next step is "I'll execute this now and you watch," built-in plan mode. If it's "subagents take it from here," use `writing-plans`. If you need the plan to survive across sessions or `/clear` boundaries, writing-plans wins every time.

**On scope.** A plan that spans more than one session needs to be explicit about what "done" means at the end of each phase. Otherwise you resume the next day with a half-executed plan and no clear stopping point. `writing-plans` enforces review checkpoints between phases for exactly this reason — each checkpoint is a natural `/clear` boundary.

---

## §6. Execute — TDD, subagents, code review

Three patterns that actually show up in real sessions:

### TDD

`superpowers:test-driven-development` for new features and bugfixes. Tests get written before the code they cover. The skill enforces the Red/Green/Refactor cycle — you don't proceed to implementation until the failing test is in place. This catches mis-specified requirements early, when they're cheap to fix. Most of the value is in the "write the test first" discipline, not in the tooling.

### Subagents

`superpowers:subagent-driven-development` / `superpowers:dispatching-parallel-agents` — fan independent phases of the plan out to subagents. Each subagent gets a focused task and a clean context, usually from the plan written in §5. The orchestrator (typically running Opus) coordinates; subagents (typically Sonnet or Haiku) do the bounded work cheaply and in parallel.

Model downshifting is automatic — the skill judges task complexity and picks the subagent model accordingly. You rarely hand-pick the subagent model; you configure the orchestrator and let it delegate.

**Worktrees** (`superpowers:using-git-worktrees`) — when the change is large enough to warrant isolation, or when parallel subagents might step on each other's working trees. Spin up a worktree per subagent, each with its own branch. Cheap to create, easy to throw away, clean merge target.

```bash
# the skill handles this, but manually:
git worktree add ../my-project-feature feature-branch
```

### Code review

`superpowers:requesting-code-review` at the end of a phase, before merging. The skill enforces "engage with the feedback, don't performatively agree." For the receiving side (`superpowers:receiving-code-review`): the rule is verify before implementing — push back on suggestions that don't hold up under scrutiny. Technical rigor, not deference.

### Inspecting the actual diff

The agent's self-review and the code-review skill are necessary but not sufficient. Always read the diff yourself before committing. A few ways to do that, ranked roughly by friction:

- **`git diff`** and **`git diff --staged`** — base case, always start here. Run `git diff --stat` first for a bird's-eye view of what changed where, then dive into the full diff for the parts that matter.
- **`git diff HEAD~N HEAD`** — review a session's worth of work in one go before pushing. Useful when the agent committed in small steps and you want to see the cumulative effect.
- **`git show <sha>`** — review a single commit (message + diff together). Good for "what did this specific change do" lookups, especially when reading `git log` and you want to drill into one entry.
- **`delta`** — pretty pager for git. Side-by-side mode, syntax highlighting, much easier on the eyes than the default. One-time setup in `~/.gitconfig`, pays off every diff after.
- **`difft` (difftastic)** — syntax-aware diff. Renders renames, large refactors, and structural changes in a way that line-based diff can't. Worth reaching for when the default diff is confusing.
- **GitHub web UI** (`gh pr view --web` or `gh pr diff`) — for PR-style review with threaded comments. Even on solo work, opening a PR for non-trivial changes and reviewing in the web UI before merging is worth the friction.
- **IDE diff panel** — VS Code's git view, JetBrains' diff viewer. Best for big refactors where you want to scroll through changes file by file with the full editor context.

The agent's self-review catches obvious mistakes. Reading the diff catches what the agent didn't realize was wrong — including things outside the scope of what it was reviewing.

**Downshifting note.** The most common mistake in execute mode is running the entire phase in Opus because that's what you used for planning. Planning done, switch to Sonnet. If individual steps get hard (unexpected edge case, debugging a subtle bug), `think hard` on that turn or briefly upshift — then return to Sonnet for the mechanical remainder. Matching the model to the *kind of thinking* the current turn actually requires is the habit.

**Stay-in-the-folder rule.** The agent shouldn't roam outside the working directory without asking — see §13 for the full rationale and the `uv` tie-in.

---

## §7. Model selection — task-mode based

Pick by *what kind of thinking the task requires*, not by what you've been using.

| Task type                                | Model                 |
| ---------------------------------------- | --------------------- |
| Planning, architecture, gnarly debugging | Opus 4.7 / `opusplan` |
| Executing a plan, routine code           | Sonnet 4.6            |
| Parallel bounded subagent work           | Haiku 4.5             |
| Parallel bounded subagent work           | Local model?          |

Subagent skills downshift automatically when the task is bounded and cheap. You rarely pick the subagent model by hand — the orchestrating skill decides.

A Sonnet-default user who upshifts for hard work is making the same choice from the other direction. The heuristic is symmetric: recognize when the task is actually a *planning* task disguised as an execution task (pick Opus), and when it's genuinely a *bounded execution* task that Sonnet handles fine (don't burn Opus on it).

Thinking (§7.5) is a separate lever — you can crank thinking on Sonnet for a hard-debugging turn without switching to Opus.

---

## §7.5. Thinking — dial it for the task

Extended thinking is a separate lever from model choice. Anthropic's effort-level evaluation (low / medium / high / xhigh / max) shows steep diminishing returns: on Opus 4.7, low → medium is roughly a 6-point score gain for ~15k extra tokens, but xhigh → max is roughly 3 points for ~100k extra tokens. The curve flattens hard. Most of the benefit is in the first two steps up. Cranking everything to max is expensive and rarely worth it.

**What it actually does.** Thinking gives the model a separate token budget to reason internally — plan, decompose, self-critique, verify — before producing the visible response. Thinking tokens cost like output tokens but stay scoped to the reasoning step; in Claude Code you see them in collapsed "thinking" blocks. More budget = more room to work through a problem. The diminishing-returns curve above is the practical limit.

**How to set it in Claude Code:**

- **Keyword triggers in the prompt** — cheapest way to dial up for a single turn. Approximate budgets:
  - `think` — ~4K tokens (routine debugging, small refactors)
  - `think hard` — ~10K tokens (API design, planning, optimization)
  - `think harder` — between the two above
  - `ultrathink` — ~32K tokens (architecture, complex migrations, critical debugging)
- **`/effort <level>`** — slash command that sets thinking effort for the current session. Levels pair directly with the chart labels: `low / medium / high / xhigh / max`. Granular session-level control without per-turn keywords. Resets on `/clear`.
- **Env var `MAX_THINKING_TOKENS`** — hard ceiling, applies everywhere. Useful when you want to cap a long-running orchestrator that might otherwise go expensive on routine turns. Persistent across sessions.
- **Env var `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`** — forces a fixed reasoning budget instead of letting the model decide per turn. Use when you want predictable cost regardless of perceived task difficulty.
- **Default** — thinking is off / low unless explicitly invoked. Most turns don't need it.

**When to crank it up:**
- Brainstorming a new design — `ultrathink` or `think harder` on the framing question.
- Debugging when the bug has no obvious cause — `think hard` before proposing a fix.
- Architectural decisions with real trade-offs — give it room to work through them.

**When to leave it low:**
- Routine code edits, renames, file moves.
- Anything where the answer space is small.
- Subagents doing bounded execution — let them burn through cheaply.

**Practical rule:** if I'd want a human teammate to sit quietly and think for a few minutes before answering, I dial thinking up. Otherwise low/off is correct. The diminishing-returns curve means cranking everything to max is the wrong default — most tasks don't move past the medium plateau, and you pay for every token past that point.

---

## §8. Close — session note, vault push, `/clear`

Three steps, in order. Not optional.

**Step 1: Write the session note and update project docs.**

Write `Work/ClaudeCode/<project>/YYYY-MM-DD-HHmm.md` with four sections: *What we worked on / Decisions / Files changed / Open questions*. The Decisions section matters more than Files changed — capture what you considered and rejected, not just what shipped. "Files changed" is reconstructible from git. Why you picked approach A over B is not.

Update the project README if status changed. Update `Work/context.md` if the project's priority block is stale.

**Step 2: Commit and push the vault.**

```bash
git -C ~/Documents/Github/sevry_vault add -A \
  && git commit -m "claude-code: <project> session summary YYYY-MM-DD" \
  && git push
```

**Step 3: `/clear`.**

Non-negotiable. Bounded sessions prevent context rot and prevent the next task from inheriting noise from this one. See §9 for why this is `/clear` and not `/compact`.

**End-of-day discipline.** Resuming a session (`--resume`) reloads the entire conversation context, so the first turn the next morning costs as much as everything already accumulated — and it keeps climbing from there. Practically: finish the task, or at minimum push a handoff to the vault, before wrapping up. A session note plus an updated project README is a complete handoff. Tomorrow you start fresh with `/clear`, re-orient from the vault in a few hundred tokens, and pay nothing to reload.

**What a complete session note looks like.** Not long — usually 15–30 lines. The "Decisions" section is 3–6 bullet points: each one is a choice you made and the reason. "Used uv instead of pip because the project needs Python 3.12 and uv handles it cleanly" is more useful than "updated dependencies." The Open Questions section is particularly valuable — it's what you'd need to explain to a teammate picking up the work mid-stream. Write it that way.

```markdown
# Session: my-project — 2026-05-13 14:30

## What we worked on
- Implemented the PMID parser for the literature inbox hook.

## Decisions
- Used regex over a PMID library — no library needed for the simple case, avoids a dependency.
- Deferred DOI support to a follow-up; PMIDs cover 90% of the use case.

## Files changed
- `scripts/hooks/process-literature-inbox.sh` (new)
- `.githooks/pre-commit` (added PMID pattern to block list)

## Open questions
- Should the hook fire for every UserPromptSubmit or only when inbox is non-empty?
```

---

## §9. Why never `/compact`

**The rule:** I never compact. Always clear.

**Why:** `/compact`'s job is to summarize the current conversation and replace the in-session history with that summary. When the summary is wrong — and it is, in subtle ways you can't see — that summary becomes the agent's working ground truth for everything that follows in the session. The errors are not easily inspectable: you can't diff what actually happened against what the summary remembered. And they compound. A single misremembered decision shapes every subsequent turn.

Most community advice says use `/compact` proactively at around 60% capacity with a steering hint ("compact, focus on the auth refactor"). That's a reasonable defense for users whose only continuity layer is the conversation history. Anthropic's own docs present both clear and compact as valid options for different cases. Most power-user writeups land on "compact with hints." That position is reasonable — I'm not arguing it's wrong in general.

**Why the never-compact rule works *for this workflow specifically*:** the vault and claude-mem provide lossless continuity already. The session note captures every decision; claude-mem captures the long tail; the project README captures current state. Compact would be summarizing material that's already been captured — trading a lossless handoff for a lossy one. Clearing costs nothing because nothing is being lost.

**The compounding failure mode in practice.** The worst version isn't a single bad summary — it's ten sessions of `/compact` where each summary drifts slightly from the previous, and by session twelve the model's working assumptions about the project are wrong in ways that are hard to trace. The session note + vault loop avoids this entirely because the vault is the source of truth, not the conversation history. Also, the vault can easily be audited by me for mistakes. Misremembers in conversation don't persist past a `/clear`.

**The 1M-token trap — never get into this position.** Opus 4.7 has a 1M-token context window. Autocompact fires around 960k. The catch: by the time you're anywhere near that ceiling, the model is already performing worse — context rot from sheer token volume degrades reasoning well before autocompact triggers. When the autocompact then runs, *both the live reasoning and the summary it produces are operating on a degraded baseline*. You get a worse compact than you would have earlier, and the post-compact session inherits that worse baseline. The lesson isn't "compact earlier" — it's never let context grow that far in the first place. Finish the task, write to the vault, `/clear`. Bounded sessions are an architectural answer to a problem `/compact` can't actually solve.

**TL;DR on the mechanics:** the first-order harm is in-session — the lossy summary replaces the real history and the agent operates on it for every following turn. The second-order harm leaks across sessions when the agent, operating on that corrupted summary, then writes session notes, updates the project README, or modifies CLAUDE.md. The persistent memory layer gets contaminated indirectly, through the agent's outputs. That's what makes it hard to audit: the artifact you'd inspect later looks fine on its face. The error lives in the gap between what actually happened and what the summary kept. Session notes you review before commit don't have this property — the review is the quality gate. A compact summary happens inline, invisibly.

**If you adopt this rule without the scaffolding, you'll lose continuity.** Build the vault and session-note discipline first. Then the never-compact rule follows naturally. Without that infrastructure, fall back to proactive `/compact` with hints — but know what you're trading.

---

## §10. Memory layers — three of them

Three durable memory layers with different audiences and access patterns. They compose — a question gets answered fastest when you reach for the right layer.

**Vault** = mine. Curated, project-anchored, Obsidian-readable Markdown. I open it; the model reads from it at session start. Best for: *"what's the status of project X / why did I pick approach Y / which paper covers Z."* The session notes and project READMEs in `Work/ClaudeCode/` are the primary interface. I write them; I can also read them in Obsidian.

**claude-mem** = the model's notebook. Automatic, observation-indexed, semantically searchable. I rarely read it directly; the model fetches what it needs by ID or search query. Best for: *"have we hit this bug before / what did we rule out / what was surprising."* It captures the operational details that don't fit cleanly into a session note but might matter three weeks later.

**Git** = code memory. Diffs and commit messages, both human- and agent-readable. Claude Code writes good commits when asked — small scope, the "why" in the body, conventional prefixes — which makes `git log` a scannable history of *why the code looks the way it does*. Best for: *"when did this change / what was the intent / show me the diff between then and now."* `git log -p`, `git blame`, and `git show <sha>` are first-class lookups.

The three layers don't overlap as much as it looks: the vault captures decisions I want to *remember*, claude-mem captures decisions the *model* needs to remember, and git captures the *literal change*. A good commit message links them — it explains the why while the diff shows the what. For the deeper vault-vs-claude-mem comparison (audience, format, lookup cost), see [`VAULT_GUIDE.md`](./VAULT_GUIDE.md) §4.

**Practical rule:** invest in commit messages the same way you invest in session notes. "fix bug" is a hole in the third memory layer. `git log` should read like a project changelog without extra tooling.

```bash
# the kind of commit message git log rewards:
git log --oneline
# 4d3f8a1 fix: skip empty lines in PMID parser — caused off-by-one in chunk indexing
# 8c1e972 feat: add literature-inbox hook — fires on UserPromptSubmit, injects queued entries
# 2b7f3a9 refactor: extract ID sanitizer — was duplicated in 3 hooks, now in lib/sanitize.py
```

A log like that tells you *why the code looks the way it does*. A log full of "wip" and "fix stuff" is opaque to the agent at the next session start and to you after three weeks away.

The vault requires 5–10 minutes per session to write the note and push. claude-mem is automatic. Good commit messages cost 30 seconds. The cost of *not* maintaining them is paid later, usually at the start of the next session when you're trying to re-orient.

For vault setup, file layout, automation scripts, and security hooks, see [`VAULT_GUIDE.md`](./VAULT_GUIDE.md).

---

## §11. Small commands worth knowing

Quality-of-life things that compound once you know them:

**`!` prefix.** Runs the typed line as a shell command in the session, with output landing in context for the agent to read. Use for one-shot commands you'd otherwise type in a separate terminal — `! gh pr view 42`, `! sbatch run.sh`, `! gcloud auth list`. No permission round-trip, no separate terminal, output immediately available to the model.

```text
! gh pr view 42
! gcloud auth list
! pwd
```

**`/context`.** Prints a breakdown of what's currently using the context window — system prompt, tools, memory files, skills, messages, free space. Reach for it before a `/clear` decision or when a session feels sluggish. Useful for seeing how much MCP and skill metadata is already loaded.

**`/statusline`.** Sets up the status bar at the bottom of the terminal: model, working directory, git branch, context %. One-time setup; pays off every session. The `statusline-setup` agent will configure it for you.

**`/btw`.** Sends a quick remark to the agent without derailing the active task. Useful for tossing in a constraint or context note mid-flight — `/btw this needs to work on the HPC partition` — without rephrasing the whole prompt or interrupting the current flow.

**`/clear`.** Covered in §8 and §9. The most important command in this list. Use it every time a task ends, not just when you hit the context limit.

**`/skills`.** Lists all available skills in the current session — useful when you know you want a superpowers skill but can't remember the exact name. Each skill listed is invocable directly by name. If you see a skill mentioned in this guide (`superpowers:brainstorming`, etc.), this is how you find and verify it's loaded.

These are shortcuts, not framework. Worth knowing early because they compound across every session. The ones that matter most in order of daily use: `!` for inline shell, `/context` before clearing, `/clear` after finishing.

---

## §11.5. Skills and MCPs — the toolbox

**Skills** are reusable behavior templates the agent invokes. Run `/skills` to see what's loaded. They enforce discipline (TDD, brainstorming, plan/execute) and capture know-how (writing good commits, security audits). Skills are the connective tissue between the loop in §1 and the actual session.

**MCPs** (Model Context Protocol servers) expose external systems — APIs, databases, file sources — to the agent as tools. The agent calls MCP tools the same way it calls Read or Bash, but the work happens on the MCP server. MCPs are how you give the agent access to things outside the working folder without it roaming (see §13).

What I actually run with:

**Skills:**
- `superpowers:*` — the pipeline that powers §1–§8: `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `dispatching-parallel-agents`, `test-driven-development`, `requesting-code-review` / `receiving-code-review`, `using-git-worktrees`. If I had to keep one skill set, this is it. Source: [obra/superpowers-marketplace](https://github.com/obra/superpowers-marketplace) (skills themselves at [obra/superpowers](https://github.com/obra/superpowers)).
- `claude-mem:*` — memory plugin. `mem-search` for "have we hit this before" (drives the `search → timeline → get_observations` workflow); `smart-explore` for token-efficient code-structure lookups via tree-sitter (separate from memory); `make-plan` / `do` as a third planning option (§5). Source: [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem).
- `hookify` — turns "this friction annoyed me twice" into a working hook in one command (§12).
- `code-review` — focused code-review plugin, complements the superpowers code-review skill.
- `commit-messages`, `security-audit` — built-in, used at commit time and during reviews.

**MCPs:**
- `claude-mem` (mcp-search) — semantic search across the model's observation history (§10). The model uses it; I rarely call it directly.
- `pubmed` — paper fetching for the `Literature/inbox/` automation in the vault. Drop a PMID into the inbox folder and it fetches the paper, fills the template, writes the note. See `VAULT_GUIDE.md` §6.
- `context7` — library/framework docs lookup. Better than web search when you know the library name and need accurate, current API references — especially for fast-moving libs where the model's training data is stale.
- Anthropic-provided MCPs (Gmail, Calendar, Drive) — auth-gated, used for ad-hoc external lookups when relevant.

**Practical rule:** install a skill or MCP when the same friction shows up twice. The first time is signal; the second is the trigger. Most of the skills above were installed exactly that way.

---

## §12. Hooks and hookify — automating the rules

Hooks are Claude Code's lifecycle callbacks: shell commands the harness runs at specific events. They're how you enforce a rule deterministically instead of trusting the agent to follow it. **The harness runs hooks — not the agent — so a hook that blocks something cannot be argued around or accidentally bypassed.**

### Event types

- **`PreToolUse`** — fires before a tool runs. Match by tool name (`Read|Edit|Write`, `Bash`, etc.). Exit non-zero to block the tool call. This is where security gates live.
- **`PostToolUse`** — fires after a tool returns. Good for formatting, linting, or logging.
- **`UserPromptSubmit`** — fires when you submit a prompt, before the model sees it. Can inject context into the prompt — the vault's `process-literature-inbox.sh` hook uses this to automatically include any queued literature entries when a session starts.
- **`Stop`** — fires when the agent finishes its turn. Useful for end-of-turn reminders, log rotation, status updates.
- **`Notification`** — fires on system notifications (e.g., agent waiting for input). Pair with macOS desktop notifiers so you don't babysit long runs.

### Configuration

Configured in `~/.claude/settings.json` (global, applies everywhere) or `.claude/settings.json` (per-project). Each hook entry has a `matcher` (regex against the tool name, or empty for "all") and a `command` (a shell script path or inline command).

### My production hooks — copy these as starting points

- **`PreToolUse / Read|Edit|Write` → `block-secrets.py`** — scans file paths and content for sensitive ID patterns (`P-XXXXXXX`, `C-XXXXXX`, etc.). Blocks the read/edit if it matches. The agent literally cannot open a file containing a patient ID.
- **`PreToolUse / Bash` → `block-dangerous-commands.sh`** — blocks `rm -rf`, force-pushing to main, and similar. Opt-in override required.
- **`PostToolUse / Edit|Write` → `after-edit.sh`** — runs formatter/linter on the modified file immediately after the edit.
- **`Stop` → `end-of-turn.sh`** — end-of-turn housekeeping: log rotation, status checks, whatever the project needs.
- **`Notification` → `notify.sh`** — desktop notification when the agent is waiting for input. Lets me walk away from long-running sessions.

### hookify — the easy way to write hooks

`hookify` is a Claude Code plugin that turns "this behavior annoyed me" into a working hook in one command:

- **`/hookify`** with no arguments — scans the recent conversation for patterns worth automating (e.g., the agent ran a build without saving first, kept overwriting a file you'd just hand-edited). Proposes hooks.
- **`/hookify "<rule>"`** — write the rule in plain English, get a hook generated and installed.

When the same friction shows up twice in a week, that's a hook. `/hookify` lowers the bar enough that you'll actually write them instead of just tolerating the friction.

---

## §13. Things I'd tell a teammate adopting this

**Clear, don't compact.** The single most important habit. See §9. Build the vault discipline first; then the never-compact rule costs you nothing.

**The spec is the handoff.** When you write a spec via brainstorming, you're writing the document a subagent will execute. Make it precise. Vague specs produce vague code — the garbage-in problem applies across agent boundaries.

**The "Decisions" section of session notes is the artifact.** "Files changed" is reconstructible from git. Why you picked approach A over B is not. Write the Decisions section like you're explaining it to yourself six months from now.

**Let subagents do the cheap work.** Don't burn Opus thinking on string-replacement passes or mechanical refactors. Fan it out to Sonnet/Haiku and orchestrate. Opus's value is in the planning and the hard calls, not the execution.

**Trust the brainstorming skill to push back.** It's designed to ask annoying questions before you commit to an approach. The annoying questions are the value — they surface assumptions and constraints you hadn't named. Answer them rather than dismissing them.

**`/init` is for onboarding existing material, not blank projects.** New projects with no scripts, specs, or PDFs don't benefit from `/init`. Start with brainstorming instead.

**Pick the model for the kind of thinking, not the task name.** "Build feature X" might be a planning task (Opus) followed by an execution task (Sonnet) — don't run both in Opus. The task type changes mid-session; the model should change with it.

**Bake the protocol into global CLAUDE.md.** Per-project enforcement is fragile and easy to forget. Global means every session everywhere inherits the discipline. One edit to `~/.claude/CLAUDE.md` propagates to every project, every machine, every session.

**Hooks enforce what CLAUDE.md only requests.** If something in CLAUDE.md is genuinely non-negotiable — don't commit patient IDs, don't force-push to main — write a hook. The agent respects `~/.claude/CLAUDE.md` most of the time; the harness enforces a hook every time.

**Tell the agent not to leave the folder.** If it needs a file, a package, a credential, or anything else outside the working directory, it should ask. Roaming agents pick up unrelated files, run unrelated commands, and pollute the working context. The rule "stay put and ask" pairs naturally with `uv` for Python work — all dependencies live in `.venv/` inside the project folder, so there's nothing the agent legitimately needs from elsewhere on the filesystem. Same logic for `mamba` environments and per-project `.env` files. When the agent does need to step outside, the question itself is useful information: it forces you to notice the cross-folder dependency before it becomes invisible.

**Start with the loop before the tooling.** The value is in kickoff → brainstorm → plan → execute → close as a discipline, not in any specific skill or plugin. If you start using Claude Code heavily with no loop, you end up with long tangled sessions, no notes, and context that resets unpredictably. The loop is the skeleton; everything else is muscle on top of it.

**Context window size is not a goal.** A 200k-token context window doesn't mean you should fill it. Smaller focused sessions with good handoffs outperform marathon sessions that accumulate noise. The skill at context management — knowing when to `/clear`, what to write to the vault, how to re-orient in 200 tokens — is what compounds over months.

**Sessions should end with the work done, not with the context full.** If you notice yourself compacting or wondering whether to compact, the session has already drifted. The signal isn't context fullness — it's task completion. Finish the task, write the note, clear. If the task is too big for one session, write the plan, hand it off, clear. Never let the session end just because the context is filling up.
