---
name: plan
description: "Turns the request for a single feature into an issue on the repo's tracker — GitLab or GitHub, depending on the remote — with the plan and its roadmap inside: code reconnaissance, design forks put to the user, phases with atomic checkboxes that the tracker makes tickable, and the instructions for ticking them as the work goes. If the work needs more than one issue it notices, warns, and proposes how to proceed, including the switch to /issue-flow:big-plan. Trigger: /issue-flow:plan, 'open an issue for…', 'write the plan for…', 'tick the roadmap of issue N'."
argument-hint: "<description of the change>"
---

# /issue-flow:plan

Nothing gets implemented that is not written in an issue. The issue is not a reminder: it is
**the work instruction**, and it holds both the plan and the roadmap that carries it out. Whoever
implements reads that and nothing else.

This skill is for **a single feature**: one issue, 5 to 8 phases, one merge request. If the
request is a development that does not fit — several increments that each merge on their own —
the right door is `/issue-flow:big-plan`, which defines the project roadmap and splits it into
issues. It is not up to the user to notice: step 2 bis always checks, and if the request does
not fit in one issue you stop, warn and propose how to proceed.

The tracker is **GitLab** (`glab`) or **GitHub** (`gh`) depending on the remote, and the difference
is only the command: `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` — the `TRACKER.md` file in this plugin's
folder — says which one is used here and how each command translates from one to the other.
Read it before running the first command of the session: the commands below are given in both
variants, but the traps (the body field that changes name, the `--limit` of
`gh issue list`, the CRLFs) are there.

## Usage

```
/issue-flow:plan <description of the change>   # the normal case: from the request to the issue
/issue-flow:plan                               # uses a plan already approved in this conversation
/issue-flow:plan check <n>                     # re-read the roadmap and update the ticks
/issue-flow:plan revise <n>                    # reopen the plan of an issue and rewrite it
```

The 1.x arguments `spunta` and `rivedi` are still accepted as `check` and `revise` (`TRACKER.md` §6).

## The principle that decides everything else

**The issue must be executable by an agent that did not attend the conversation.**

When in doubt whether to write something or take it for granted, apply this test: another model,
with the repo open and having read only the issue, would know which files to touch, what to
write in them and how to tell whether it worked? If not, something is missing.

Everything else follows from this: the verified `file.ts:42` references, the **measured** numbers
rather than estimated ones, the decisions written down with their reasons, the explicit out of scope.

## The host project

This plugin knows nothing about the project it runs on, and must not make anything up. The three
things it needs are derived in this order:

**The target branch.** `${user_config.default_branch}` if the user configured it,
otherwise from the repo:

```bash
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' \
  || git branch --show-current
```

**The verification commands.** `${user_config.verify_commands}` if configured. If not, you derive
them from the project during reconnaissance and **write them in the issue**, so the verification
phase has real commands and not a generic "run the tests": the `package.json` scripts, the
`Makefile` targets, `pyproject.toml`/`tox.ini`, the CI jobs in `.gitlab-ci.yml` or
`.github/workflows/`. The project's `CLAUDE.md`, if there is one, almost always lists them already.

**What must be kept aligned at the end.** `${user_config.docs_paths}` if configured, otherwise
the documentation files the project actually has — `README.md`, `docs/`, a changelog — and
that the change would make false.

If one of these cannot be derived and is needed, ask the user: it is a single question, and it
holds for every issue to come.

## Process

### 0. Which tracker, and does it answer

First thing, the platform: `git remote get-url origin` — `github` in the URL means `gh`,
`gitlab` means `glab`. Then check that it really answers:

```bash
glab auth status && glab issue list --all              # GitLab
gh   auth status && gh   issue list --state all        # GitHub
```

Authentication is interactive and **you cannot do it**: if it is missing, stop and ask the user to run
`glab auth login --hostname gitlab.com` or `gh auth login --hostname github.com`. If instead the
command gives a 404 or "could not determine base repo", the remote is an SSH alias, and the remedy is in
`TRACKER.md` §2 — one line per platform. If the remote is neither GitHub nor GitLab, or the CLI
that would be needed is not installed, stop and say so: an issue is not opened by hand.

### 1. Work like in plan mode, without entering it

**Never call `EnterPlanMode` or `ExitPlanMode`.** `ExitPlanMode` ends with the offer to implement
the plan, and here the plan is not implemented: it is written into the issue,
and `/issue-flow:implement` will implement it. The way of working is the same as plan
mode, though, and holds from here until the issue is created:

- **read-only.** Until step 5 you change nothing in the repo: no `Edit` or `Write`
  on the project files, no commands that change state. You read, search, measure. The only
  file you write is the issue body, in the scratchpad;
- **ask the questions as you go.** The design forks of step 3 are put with
  `AskUserQuestion` as soon as the reconnaissance brings them up, as plan mode would: do not
  pile them up into one burst at the end, and do not leave them implicit;
- **the plan is presented before the issue is opened.** Once the forks are closed, write a summary
  of the plan in chat: what changes, the constraints found in reconnaissance, the decisions taken on
  your own with their reasons, the phases with one line each. Then ask with `AskUserQuestion` — this
  is where approval happens, not `ExitPlanMode` — with three options: "Open the issue"
  (Recommended), "Change something" (the user says what, you fix the plan and ask again),
  "Leave it" (you open nothing and stop);
- **only "Open the issue" leads to step 5.** Never offer to implement, neither as an option
  of the question nor in the delivery message.

If the plan was already approved in this conversation — the user used plan mode
on their own and approved it, or it is `/issue-flow:plan` with no arguments — skip the
summary and the approval question: the reconnaissance is done, do the check of step
2 bis and, if the request fits in one issue, go to steps 4 and 5.

### 2. Code reconnaissance — not skippable

A request is an intention; the issue is an instruction. This step makes the difference.
**Before writing a line of plan:**

- identify the files the change will touch and **really read them**, do not infer them from the names;
- note the line numbers the issue will have to cite, and verify them;
- **measure, do not estimate.** What the project already has on disk is real data: how many lines
  the file you are about to split has, how many calls the function you are about to change has,
  how many records have the field populated, how much the bundle weighs today. A number measured in
  reconnaissance is worth ten sentences of plan, and it is what makes the final phase verifiable;
- look for the implicit constraints the plan will have to respect: invariants written in comments,
  serializations that do not digest certain types, caches or files on disk that would be
  invalidated, schema migrations, imports that would create a cycle, **mirrored fields**
  between backend and frontend that must be changed together or they do not compile;
- **backward compatibility is almost always a constraint**: data already written, responses
  already cached, clients already out there must keep working after the change. Every new
  field is born with a default, every rename brings along whoever reads it.

Every constraint you discover that the request did not foresee goes in the issue, not resolved
silently.

### 2 bis. Does it fit in one issue? — not skippable

This check is not optional and does not wait for the end: you do it **during** the reconnaissance, and
as soon as the answer is no you stop, without completing a detailed reconnaissance that would serve
an issue that will not be opened. It also holds when the plan arrives already approved from the
conversation, and in `revise <n>` when the rewrite makes the issue grow.

The request does **not** fit in one issue if even one of these holds:

- the phases, verification and closing included, would be more than 8;
- the work splits naturally into increments that can be merged one at a time, each
  leaving the product working — the data model, then the API, then the interface;
- it touches several areas of the system that are reviewed separately — services, packages, backend and
  frontend with a new contract between them;
- the final merge request would touch so many files that it can no longer be reviewed in one
  reading.

**Do not compress** a big development into huge phases to make it fit in eight: a phase that does not
close in one subagent does not close. And do not decide on your own to split it: the choice is
the user's.

#### The warning

Before the question, write a short, concrete warning in chat:

- **that the request does not fit in one issue**, said up front and without beating around the bush;
- **why**: the signals above that hold, with the numbers measured in reconnaissance — how many
  areas, how many files, how many phases it would take — not impressions;
- **the split you propose**: the issues that would result, in execution order, one line
  each with what it delivers and which one it depends on. It is a draft, not the roadmap: it lets the
  user understand what size we are talking about and choose.

#### The question

Then `AskUserQuestion`, with these options — in the description of each, write concretely what
happens next, with the numbers from the draft:

- **"Switch to /issue-flow:big-plan"** (Recommended): a mother issue with the roadmap and the N children
  of the draft, executed one at a time;
- **"Open only the first issue"**: this skill continues with the first increment of the draft; the
  rest goes into the issue's **Out of scope**, one point for each of the following issues,
  so it is not lost;
- **"Narrow the scope"**: the user says what goes in; start over from the check with the new
  scope;
- **"Keep a single issue"**: the user takes responsibility. Go on even past
  8 phases, and the issue's **Context** must say that the size is a declared choice,
  with the numbers that would have made it split.

#### How to proceed

- with **big-plan**: immediately load the `issue-flow:big-plan` skill with the `Skill` tool, in the
  same conversation, passing it the original request. The reconnaissance done so far is not thrown away:
  `big-plan` picks it up where you got to and starts from the split draft. From that
  moment `big-plan` applies, not this skill;
- with **only the first issue** or **narrow**: go back to the reconnaissance for the new scope —
  the `file:line` references and the numbers in the issue must concern what the issue actually does — and
  continue from step 3;
- with **a single issue**: continue from step 3.

### 3. Ask only the real forks

Use `AskUserQuestion` when two readings of the request would lead to different work —
the layout of a table, which columns, whether something goes in or stays out. Not for
choices that have an obvious default: those you take yourself and **declare** in the final
message, with the reasons, so the user can overturn them.

For layout choices put a `preview` with an ASCII sketch: they can be compared at a
glance and the user answers in two seconds.

### 4. Title and branch

The title says **what changes for whoever uses the product**, not which file is touched: a short
sentence in lowercase, with no final period. The number is the one the tracker assigns, and it is read
from the URL that the creation command prints.

The working branch is `${user_config.branch_prefix}<issue number>` — with the default
`issue-`, issue #12 is worked on `issue-12`.

### 5. Write the issue

Follow `TEMPLATE.md`, the file next to this one, which describes the sections one by one. Write
the body into a temporary file and create the issue from there:

```bash
glab issue create --title "<title>" --description-file <file> --yes   # GitLab
gh   issue create --title "<title>" --body-file        <file>         # GitHub
```

The file avoids passing a long body through the shell's quotes. The assigned number is the one
the command prints in the URL: read it from there, do not deduce it.

### 6. Delivery

In a few lines: the link, what you found in reconnaissance that the request did not foresee, the
decisions you took on your own with their reasons, and what you left out of scope.
Do not paste the issue in the reply: it is a page, the user opens it.

## The roadmap

It is the reason the issue exists, and it lives **inside the issue**, in the Plan section, as
phases with checkboxes. Both GitLab and GitHub recognise them as task lists and make them clickable:
GitLab shows "0 of N tasks completed" and counts them in `task_completion_status`, GitHub
shows "0 of N tasks" at the top of the issue. The count via API exists only on GitLab, though:
the way that holds on both is to count the lines in the body, and it is the one used by
`/issue-flow:implement` and `/issue-flow:close` (`TRACKER.md` §5).

### The phases

A phase is **a piece of work that closes**: it leaves the repo in a coherent and
verifiable state. Not a day, not a thematic area. 5 to 8 phases is the normal range.

Two phases are mandatory and always go at the end, in this order:

- **the second to last is verification**, and includes the project's commands — the ones configured in
  `${user_config.verify_commands}` or the ones you derived in reconnaissance — plus a manual check of
  what the issue promised should be visible. If the change touches the interface,
  also the keyboard check, the responsive layout and accessibility;
- **the last is closing**: the documentation files that need rewriting, named one by
  one, and the commit on the issue's branch. The MR/PR **is not a roadmap checkbox**: it is
  opened by `/issue-flow:close <number>` when all the phases are closed.

A third is conditional: if `${user_config.figma_file}` is configured and the change touches the
frontend, **the first phase is the Figma**. You work with the `figma:figma-use` skill and the
`use_figma` tool; the Figma is aligned **before** the code, not after, because the code adapts
to the Figma and not the other way around; existing components are restructured in place and not
recreated, otherwise the instances detach. If the configuration is empty, this phase does not exist: do
not invent it.

### The checkboxes

- **Total coverage.** Every piece of work has its own: code, models, mirrored types between
  backend and frontend, interface strings, documentation lines, verifications. Work that has no
  checkbox is work that will be forgotten.
- **Atomic.** One checkbox = one thing that gets ticked without reservations. If to tick it you have to
  say "yes, but halfway", it should have been split in two.
- **Verifiable from outside.** `- [ ] every new field has default ""` can be checked;
  `- [ ] understand how the filter works` cannot: it is not a checkbox, it is a thought.
- **Imperative and concrete.** Name the file, the function, the line: better
  `- [ ] src/api/user.ts:104, UserOut gains the five fields with default ""` than
  `- [ ] update the API`.
- **Self-contained.** It must not depend on something said only in chat.

When the decision is already made and the how is already settled, put the code fragment that
defines it under the checkbox: a checkbox followed by three lines is worth a paragraph.

## How boxes get ticked — and why it goes in the issue

Every issue produced by this skill **must contain the "How to update this roadmap" section**
of the template. It is not ceremony: the roadmap serves whoever resumes the work after a
`/clear`, and a roadmap that does not say its own state is of no use at all.

The rule, which holds for the user as well as for you:

- you tick **as you go**, at the end of each piece, not when the work is done;
- you tick **at the same moment** the work is done and verified, and the tick goes into the
  commit of that phase;
- if a decision changes during implementation, you **rewrite the line** of the roadmap:
  a roadmap that lies is worse than no roadmap.

The round to update it, which is also what `/issue-flow:plan check <n>` does:

```bash
# GitLab — the body field is called `description`
glab issue view <n> --output json --jq '.description' > "$SCRATCH/roadmap.md"

# GitHub — it is called `body`, and often arrives with CRLF terminators
gh issue view <n> --json body --jq '.body' > "$SCRATCH/roadmap.md"
sed -i 's/\r$//' "$SCRATCH/roadmap.md"

# flip the `- [ ]` that are done into `- [x]`, touch the **Status:** line if the phase is closed

glab issue update <n> --description-file "$SCRATCH/roadmap.md"    # GitLab
gh   issue edit   <n> --body-file        "$SCRATCH/roadmap.md"    # GitHub
```

**Always re-read the body from the server before rewriting it**, never from a copy kept in the
conversation. The update replaces the whole field and does not merge: if the user ticked
a box from the page while you were working, rewriting an old version erases it.
For the same reason, check that the file you just wrote is not empty: a `jq` on the
wrong field gives `null`, and sending it back up empties the issue.

When all of an issue's checkboxes are ticked and the work is merged, it gets closed —
`glab issue close <n>` or `gh issue close <n>` — and the **Status:** line is moved to
`closed — merged on DD/MM/YYYY`. On GitHub it may have already closed by itself, if the PR carried
`Closes #<n>`: look at the state before saying you closed it.

On a 1.x issue, rewrite the value on the status line that is already there, and never add a second one (`TRACKER.md` §6).

## Who runs the issue

Not this skill: `/issue-flow:implement <n>` picks it up, sends one phase per subagent and ticks
the boxes as it goes; then `/issue-flow:close <n>` verifies the final tree, opens the MR/PR and,
after the merge, closes the issue. Write the roadmap knowing that whoever reads it will be an
agent that attended nothing — it is the reason the phases must be self-contained.

The same rules hold for the child issues of `/issue-flow:big-plan`: the subagent
`issue-flow:issue-writer` writes them following this skill and `TEMPLATE.md`, with in addition at
the top the **Roadmap** and **Depends on** lines. `/issue-flow:plan revise <n>` works on them too:
if the child has the **Roadmap** line, re-read the mother before rewriting it and do not
contradict its decisions.

## How to write

Dense prose, technical terms and identifiers in the original. Sentences that carry
information: the *why* of a choice, not its paraphrase.

Issue bodies, merge/pull request bodies and `ROADMAP.md` are written in English, whatever language the chat is in. With the user — summaries, questions, AskUserQuestion options, the delivery message — you talk in the language of the current chat. The option labels quoted in these skills are given in English: render them in that language.

`revise` on a 1.x issue rewrites the body in English with the English markers (`TRACKER.md` §6).

- no estimates in hours or days, no story points, no percentages;
- no `TBD`, `to be defined`, `consider whether`: if a decision has not been made, make it now or
  write it as an open question with who must answer;
- code references always as `path/file.ts:42`, verified in reconnaissance;
- numbers always measured, saying **where** they were measured;
- bold only where a decision changes, not at random.
