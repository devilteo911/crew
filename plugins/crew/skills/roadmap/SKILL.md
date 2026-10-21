---
name: roadmap
description: "Proposes the roadmap of a project's next steps by reading its documentation — the research-flow registers if the repo has them, otherwise README, CLAUDE.md, docs, a previous ROADMAP.md — plus the open issues on the tracker and the state of the code. Each step has its source, its order and its dependencies, and is sized as one issue. Once approved, it saves the roadmap as ROADMAP.md in the repo root or hands it to /issue-flow:big-plan, which creates all the issues. Trigger: /issue-flow:roadmap, 'what are the next steps?', 'propose a roadmap', 'what do we do now?', 'where do we pick up from?'."
argument-hint: "[optional focus: an area, a goal, a milestone]"
---

# /issue-flow:roadmap

`/issue-flow:plan` and `/issue-flow:big-plan` start from a request: someone already knows what
they want to do. This skill comes before, when the question is **what do we do now**. It reads
what the project knows about itself — the documentation, the open issues, the code — and
proposes the next steps in order, each with the reason it is there and the source it comes from.

The approved roadmap has two outputs, at the user's choice:

- **a file**, `ROADMAP.md` in the repo root, to keep and re-read;
- **the issues**: the skill hands the roadmap to `/issue-flow:big-plan`, which makes it a
  mother issue and one child per step, each written complete.

Read `${CLAUDE_PLUGIN_ROOT}/skills/plan/SKILL.md` — the `plan` skill of this plugin — for how to
write and for the size of an issue, and `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` for the commands of
the two platforms. **Read them before the first command.**

## Usage

```
/issue-flow:roadmap                      # the project's next steps, from all the documentation
/issue-flow:roadmap <focus>              # only an area or a milestone: "the frontend", "going live"
```

## The principle

**Every step of the roadmap has a source that can be rechecked.** A register ID, a section of a
document with its path, an issue, a `file:line`. What you propose of your own — a risk the
documentation does not see, a step that is missing between two that exist — can be proposed,
but it is declared as **our proposal**, with the reason: the user must be able to tell what the
project says about itself from what you deduce.

The practical consequence: a roadmap is not written from memory of what was seen in the
conversation. It is written after reading the sources of this session.

## Process

### 0. Which tracker, and does it answer

Identical to step 0 of `plan`. Here, though, the tracker is not indispensable: it is needed to
know what is already open, and for the "issues" output. If it does not answer and
authentication is the problem, ask the user to do it; if the user prefers to go on without it,
proceed, declare in the roadmap that the open issues were not looked at, and the "issues"
output is not offered.

### 1. Work like in plan mode, without entering it

The same rules as step 1 of `plan`: **never `EnterPlanMode` or `ExitPlanMode`**, read-only
until approval, forks asked as you go with `AskUserQuestion`, approval with `AskUserQuestion`,
and **never offer to implement**.

### 2. The sources

They are read in this order, and each one says what is found and where.

#### a. research-flow, if the repo uses it

The signal is the `.research-flow.json` file in the repo root. **If it is not there, skip this
section**: the research-flow plugin is not a requirement, and without its registers the roadmap
is built from sources b–d.

If it is there, the configuration gives the folder (`dir`), the names of the five registers and
of the official document (`ufficiale`). They are the main source, because they are written
precisely to say what we know, what is missing and what is to be tried. From each one only one
part is needed:

| document | what you take from it |
|---|---|
| official (`stato_progetto.md`) | §«Prossimi passi», §«Cosa manca», §«Cosa è da testare», §«Dove potremmo sbagliare», §«Cosa non abbiamo capito»; §«Strade scartate», so as not to re-propose what an experiment has already rejected; the date at the top, **Aggiornato al** |
| to do (`TODO`) | the open P0 and P1 entries per phase, «In corso» and the questions under «Da chiedere alle fonti» |
| experiments (`ESP`) | the proposed ones, with their success criterion |
| hypotheses (`IP`) | the ones still to verify that support a choice in force, with the impact if they are wrong |
| doubts (`DUB`) | the open ones that touch code the steps will work on |

The registers can be long: do not read them in full. If the research-flow plugin is
installed, its script gives the state without opening the files:

```bash
RF=$(jq -r '.plugins["research-flow@research-flow"][0].installPath // empty' \
       ~/.claude/plugins/installed_plugins.json 2>/dev/null)
python3 "$RF/scripts/registri.py" riepilogo   # entries per register and per status
python3 "$RF/scripts/registri.py" check       # among other things: is the official older than the registers?
python3 "$RF/scripts/registri.py" find TODO-012   # one entry, who cites it, its status
```

If `$RF` is empty or the script is missing, work on the files the configuration points to, with
`grep` on the statuses and on the section headings: the registers are readable markdown even
without it.

**If the official is older than the registers** — `check` flags it, or the date at the top
precedes the latest entries — the registers win: the roadmap starts from them, you say so in
the summary, and you propose `/research-flow:stato` to realign the official. Do not rewrite it
yourself: research-flow's documents are written by research-flow's skills.

In an exploratory project part of the next steps is not code: an experiment, a measurement, a
question to a source. Experiments and measurements that require scripts or changes to the code
**are** steps, and become issues like the others; questions to the sources and waits (data to
accumulate, an answer that has to arrive) are not: they go among the **Waiting on**, and the
steps that depend on them say so.

#### b. The project's documentation

Always, with or without research-flow:

- `ROADMAP.md` in the root, if there is one: it is the roadmap of a previous time. **Compare it
  with today's state** — which steps were done (closed issues, code present), which were
  dropped, which remain — and say so in the summary;
- `CLAUDE.md` and `README.md`: the project's goal, the phases or the roadmap if they declare
  them, the constraints;
- `${user_config.docs_paths}` if configured, otherwise `docs/`, a `TODO.md`, a `CHANGELOG` if
  they exist: for the things announced and not yet done.

#### c. The tracker

The open issues, with a high `--limit` on GitHub (`TRACKER.md` §5):

- the open **mothers** — `**Type:** roadmap` at the top of the body, or `**Tipo:** roadmap` on a
  1.x issue (`TRACKER.md` §6) — with the children not yet ticked: it is work already planned. It
  is not to be re-proposed: the roadmap cites it as **already open** and starts from after it,
  or leans on it as a dependency;
- the single open issues: if a step you are about to propose already has its issue, the step
  cites it instead of duplicating it.
- **the issues the sources cite** — "in progress (#29)", "still to merge #48" — are checked on
  the tracker one by one: a source that gives as in progress an issue already closed is an
  inconsistency to flag, and the step that depended on it may be already unblocked.
  `registri.py check` does not see it: it checks the registers' consistency with each other,
  not with the tracker.

#### d. The code and the history

It serves to verify, not to invent steps:

- `git log --oneline -30` and the open branches: what is being worked on right now;
- for each candidate step, **check in the code that it is not already done.** A TODO left open
  in the register, a README line never updated, a forgotten issue left open are the normal
  case, not the exception. A step that turns out already done does not enter the roadmap: you
  flag it in the summary, because the source that listed it as to do has to be corrected.

The reconnaissance by `file:line` of each phase is not needed here: `big-plan` and its writers
do it, if the roadmap becomes issues.

### 3. The focus, if there is one

With an argument, the roadmap covers only that area or milestone. The sources are still all
read — a step outside the focus may be a dependency of one inside — but only the steps of the
focus and their dependencies, declared as such, enter the roadmap.

Without an argument, if the sources point to more directions than fit in a single roadmap — two
phases of the project open together, two areas that do not touch — ask with `AskUserQuestion`
which one to concentrate on, with one line per direction and the sources that support it.

### 4. Build the roadmap

The rules:

- **a step is an issue.** Each step has the size of a `plan` issue: an increment that merges on
  its own, 5 to 8 phases. If a step is bigger, split it; if two are small and touch the same
  thing, merge them. It is the condition for `big-plan` to be able to make one child per step;
- **first what removes uncertainty.** The P0s, the hypotheses with high impact that other steps
  rely on, the experiments whose outcome decides between two roads, the data model before
  whoever uses it. Then what is built on top;
- **the order is explicit and the dependencies are declared**: the same linear chain as
  `big-plan`, because the issues will be run in sequence;
- **operating constraints weigh on the order.** A test that is running and must not be
  interrupted, an environment that cannot be restarted, a freeze before a release: look for
  them in the sources and see which steps touch them — in the code, not from the title. If a
  constraint blocks half the steps, how to order them is a fork to ask the user about, not a
  choice to make alone;
- **the horizon stops at the first fork that cannot be decided now.** If a step depends on the
  outcome of an experiment or on a source's answer, the roadmap goes that far and then writes
  the two branches, one line each, under **After**. Planning in detail beyond an outcome you do
  not know is guessing;
- **3 to 8 steps.** Fewer than 3 is not a roadmap: with a single step propose
  `/issue-flow:plan`, with two consider whether they are a single issue. More than 8 means the
  horizon is too long: the steps beyond the eighth go under **After**;
- **for each step**: a title that says what changes for whoever uses the product — like an
  issue's title —, what it delivers, why it is there with the sources (`TODO-012`, `ESP-031`,
  `README.md` §Roadmap, `#45`, `backend/app/x.py:88`), which step it depends on, whether it
  closes or makes verifiable something (a hypothesis, a doubt, a success criterion).

Keep aside, for the summary and for the file:

- **Waiting on**: the questions to the sources, the data to accumulate, the decisions that
  belong to someone else, with the steps that depend on them;
- **After**: what comes beyond the horizon, one line per entry;
- **Left out**: what the sources list as to do and that you did not put in the roadmap, with
  the reason (already done, superseded by a decision, out of focus, low priority). It is the
  section that lets the user say "no, this goes in".

### 5. Present it and get it approved

Write a summary in chat:

- **the sources read**: whether there was research-flow and what date the official is, the
  previous `ROADMAP.md` and what remains of it, the open issues found; if you read documents
  with uncommitted changes, say so (`git status`), because the roadmap rests on that version;
- **where we are**, in three or four lines;
- **the steps**, numbered, one line each with what it delivers, the sources and the dependency;
- the **Waiting on**, the **After** and the **Left out**, brief;
- the inconsistencies found between sources and code (steps already done but open in the
  registers, forgotten issues), so that someone corrects them.

Then `AskUserQuestion`, with these options — in the description of each, write concretely what
happens next, with the roadmap's numbers:

- **"Create the issues"**: a mother with the roadmap and one child per step, written by
  `big-plan`;
- **"Save to ROADMAP.md"**: the file in the repo root, nothing on the tracker;
- **"Change something"**: the user says what, you fix it and ask again;
- **"Leave it"**: you write nothing and stop.

The **Recommended** goes to "Create the issues" when all the steps are concrete, decided work,
to "Save to ROADMAP.md" when the roadmap is mostly exploratory — steps waiting on outcomes,
forks close by — and opening issues now would mean rewriting them soon. If the user asks for
both, with the free answer, first you save the file and then move on to `big-plan`. If there is
no tracker, "Create the issues" is not offered.

### 6a. Save to `ROADMAP.md`

The file is `ROADMAP.md` in the repo root (`git rev-parse --show-toplevel`), and follows
`TEMPLATE.md`, the file next to this one.

If it already exists, you read it at step 2: it gets **rewritten**, not appended to — it
describes today's next steps, and the old version stays in git's history. In the delivery
summary say what changed from that one.

Do not commit: the file stays in the working tree, and tell the user. If the project uses
research-flow and the roadmap diverges from §«Prossimi passi» of the official, propose
`/research-flow:stato` to align it; do not touch its documents yourself.

### 6b. Create the issues with `big-plan`

Load the `issue-flow:big-plan` skill with the `Skill` tool, in the same conversation. From that
moment `big-plan` applies, which knows it comes from here (its section "When you arrive from
`/issue-flow:roadmap`") and reuses what you have already done: the verified tracker, the
sources read, the approved roadmap as the draft of the split into children.

In the handover these must arrive, already written in the conversation in the summary of step 5:

- the roadmap's goal, which becomes the mother's **Goal**;
- the steps with title, what each delivers, sources and dependencies: one child per step;
- **Waiting on**, **After** and **Left out**, which end up in the mother's **Context** and
  **Out of scope**;
- if the roadmap comes from research-flow, the mapping between steps and register entries
  (`step 2 ← TODO-012, ESP-031`), so that the delivery says which entries to mark `in corso`
  with their issue.

### 7. Delivery

For the file output: the file's path, what changed from the previous roadmap, the
inconsistencies found between sources and code, and how to start — `/issue-flow:plan` on the
first step, or `/issue-flow:roadmap` again with "create the issues" once the forks are decided.

For the issues output the delivery is done by `big-plan`.

Do not paste the roadmap in the final reply: the user already saw it at step 5, and the file or
the mother is where it gets re-read.

## How to write

As in `plan`: dense prose, identifiers in the original, no estimates in hours or days, no
`TBD`. The language is `plan`'s rule, which `ROADMAP.md` falls under:

Issue bodies, merge/pull request bodies and `ROADMAP.md` are written in English, whatever language the chat is in. With the user — summaries, questions, AskUserQuestion options, the delivery message — you talk in the language of the current chat. The option labels quoted in these skills are given in English: render them in that language.

In addition:

- the sources are **always** cited with their precise reference — ID, path and section, issue
  number — never "as the documentation says";
- **our proposal** in bold where a step or a rationale does not come from a source;
- the steps of an exploratory project say **what will be known** afterwards, not only what will
  be done: "after this step we know whether IP-014 holds" is worth more than "implement the
  backtest".
