---
name: implement
description: "Takes an issue from the repo's tracker — GitLab or GitHub — and implements its roadmap: one subagent per phase, the checkboxes ticked on the issue as the work closes, one commit per phase. It stops at the commit of the last phase: /issue-flow:close opens the merge request. Given the number of a /issue-flow:big-plan mother issue, it runs the first child not yet merged. Trigger: /issue-flow:implement, 'implement issue N', 'finish issue N', 'work on issue N'."
argument-hint: "<number> [--from N]"
hooks:
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/goal-stop.sh"
---

# /issue-flow:implement

`/issue-flow:plan` writes the work instruction, this one carries it out. Everything that is
needed is in the issue: plan, context, roadmap. No work is added that the issue does not
foresee, and no work it foresees is skipped.

## Usage

```
/issue-flow:implement <number>          # runs the issue from the first unchecked phase
/issue-flow:implement <mother>          # big-plan mother issue: runs the first open child
/issue-flow:implement <number> --from 3 # resumes from phase 3, ignoring the checkboxes
/issue-flow:implement                   # infers the number from the current branch
```

`--from N` resumes at `### Phase N` (`### Fase N` on a 1.x issue). The 1.x argument `--da N` is
still accepted (`TRACKER.md` §6).

## You are the orchestrator, and you stay one

You do not implement the phases: you assign them, verify the outcome, tick the boxes and
commit.

The reason is context. Each phase starts from a clean subagent that reads only the files it
needs, while you keep the overall view — where the roadmap stands, what the previous phase
decided, what is missing — without filling up on the details of every single file.

With `/issue-flow:big-implement` this same cycle goes down one level: for each child, an
`issue-flow:issue-runner` subagent runs it, reads this skill as a reference and leaves the goal
to the main session.

## You work in goal mode

This skill behaves like a `/goal` with the condition already written: **it does not stop until
the roadmap is complete**. A `Stop` hook of the plugin (`scripts/goal-stop.sh`) does it: at
every turn end it re-reads the issue from the tracker, and as long as the Plan has a `- [ ]`,
or the last phase is not committed, it sends you back to work, telling you which phase to
resume from.

The hook reads its state from a folder inside `.git`, which never ends up in a commit:

```bash
GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow)
```

- `$GOAL_DIR/goal` — the number of the issue being worked on. You write it at step 2; when the
  roadmap is complete the hook deletes it. As long as it exists, the turn does not close.
- `$GOAL_DIR/in-flight` — a phase subagent is at work. You create it right before delegating
  and delete it as soon as it returns: in between you may close the turn, because its
  notification wakes you up.

To stop before the end — the cases of "When to really stop", or a checkbox that stays
empty — **you delete `$GOAL_DIR/goal` yourself** and tell the user why. This is deliberate: the
stop is an explicit decision, not a turn that happens to end halfway through the roadmap. If
you stop before step 2, the file does not exist yet and there is nothing to delete.

## 0. Which tracker, and does it answer

The tracker is GitLab (`glab`) or GitHub (`gh`) depending on the remote: `git remote get-url origin`.
The full command mapping is in `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` — the file `TRACKER.md` in
this plugin's folder — to be read before the first command, because the body field changes
name between the two platforms and getting it wrong empties the issue.

```bash
glab auth status && glab issue view <number>          # GitLab
gh   auth status && gh   issue view <number>          # GitHub
```

It must show the issue, not a 404. If it gives 404 or "could not determine base repo", the
remote is an SSH alias and the remedy is in `TRACKER.md` §2. If you are not authenticated,
stop and ask the user to run `glab auth login --hostname gitlab.com` or
`gh auth login --hostname github.com`: it is interactive, you cannot do it yourself.

## 1. Read the issue, all of it, from the server

```bash
# GitLab
glab issue view <number> --output json > "$SCRATCH/issue.json"
jq -r '.title'       "$SCRATCH/issue.json"
jq -r '.description' "$SCRATCH/issue.json" > "$SCRATCH/roadmap.md"

# GitHub
gh issue view <number> --json title,body > "$SCRATCH/issue.json"
jq -r '.title' "$SCRATCH/issue.json"
jq -r '.body'  "$SCRATCH/issue.json" | sed 's/\r$//' > "$SCRATCH/roadmap.md"
```

Check that `roadmap.md` is not empty before going on: if it is, you picked the other
platform's field.

If the top of the body has `**Type:** roadmap` or `**Tipo:** roadmap`, it is the mother of a
`/issue-flow:big-plan` and it is not implemented: go to step 1 bis. If it has
`**Roadmap:** #<mother>`, it is a child: everything that follows applies, plus step 1 ter
before the branch. Both spellings are in `TRACKER.md` §6.

Read all of it, not just the Plan: **Goal**, **Context** and **Out of scope** — on a 1.x issue
**Obiettivo**, **Contesto** and **Fuori perimetro** — are what keeps the subagents from
reinventing decisions already made, and they must be passed to them.

Then work out, and tell the user before starting:

- the working branch, `${user_config.branch_prefix}<number>` — with the default `issue-`,
  issue #12 is worked on `issue-12`;
- the list of phases (the `###` inside `## Plan`, or `## Piano` on a 1.x issue) with how many
  checkboxes each has and how many are already ticked, and which phase you resume from;
- if the issue has no phases with checkboxes, **stop**: it is not an executable issue. Report
  it and propose `/issue-flow:plan revise <number>`.

## 1 bis. The mother: which child is next

Children are run **one at a time, in order**. In the mother's **Issues** section (`## Issues`,
or `## Issue` on a 1.x issue), the first unchecked `- [ ] #<n>` line is the child to run:

```bash
grep -n '^[[:space:]]*- \[ \] #[0-9]' "$SCRATCH/roadmap.md" | head -1
```

Before taking it, check that the children it depends on — the `· depends on #<k>` line in the
mother (`· dipende da #<k>` on a 1.x issue), `**Depends on:**` in the child
(`**Dipende da:**`) — are **closed** on the tracker
(`glab issue view <k> --output json --jq '.state'` → `closed`, `gh issue view <k> --json state
--jq '.state'` → `CLOSED`). A child with a dependency still open is not started: tell the user
and say which one has to be closed first — usually an MR/PR waiting to be merged.

If all the mother's boxes are ticked, the project is finished: say so, and if the mother is
still open propose closing it. If a box is empty but the child is already closed on the
tracker, the mother has fallen behind: flag it instead of re-running the child.

Then tell the user "proceeding with #<n> — <title>" and start again from step 1 with the
child's number. **Never two children in the same run**: each has its own branch and its own
MR/PR, and the next one starts from the code that this one will have merged.

To move all the children forward in one go, without waiting for the merges, there is
`/issue-flow:big-implement <mother>`: same run, one child at a time, on the mother branch —
each child enters it on its own, and only the mother's MR/PR reaches the target branch.

## 1 ter. Does the child still hold?

A child was written before the siblings it depends on were implemented: its `file:line`
references and the hook points marked "created in #<k>" described code that is different now.
Before delegating the first phase, check:

- the dependencies are **closed** on the tracker and their work is **in the base** of step 2
  (`git log --oneline <base> | grep '#<k>'`, or the files they were meant to create exist);
- the hook points "created in #<k>" really exist, under the name the child expects;
- the `file:line` references of the first phase still point to what the issue describes.

If something does not hold in a substantial way — a file that does not exist, an interface
created with a different shape, a decision the sibling changed along the way — **stop** and
propose `/issue-flow:plan revise <number>`. Lines that only moved by a few positions are not a
reason to stop: the subagent re-verifies them anyway. The right remedy is to fix the issue
before the code.

## 2. The branch

The work never touches the target branch — `${user_config.default_branch}`, or what
`git symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##'` returns.

```bash
git status --porcelain                # must be empty: one commit per phase only makes sense
                                      # if the commit holds the phase and nothing else
git switch <branch> 2>/dev/null \
  || { git switch <base> && git pull --ff-only && git switch -c <branch>; }
```

If there are uncommitted changes, stop and ask what to do with them.

On the right branch, activate the goal — with the number of the issue you are running, which
for a mother is the child's:

```bash
mkdir -p "$GOAL_DIR" && echo <number> > "$GOAL_DIR/goal" && rm -f "$GOAL_DIR/in-flight"
```

The `rm` removes an `in-flight` left over from an interrupted session, which would otherwise
leave the goal permanently off.

For a child of a big-plan, the branch is **always** created from the branch where the
already-merged siblings are, freshly updated — the `git pull --ff-only` above:

- the **mother branch**, `${user_config.branch_prefix}<mother>`, if it exists on `origin`
  (`git ls-remote --exit-code --heads origin <mother-branch>`): the project is run by
  `/issue-flow:big-implement`, and the siblings merge there;
- the target branch otherwise.

Never from the branch of a sibling that is not merged yet.

## 3. The loop, one phase at a time

For each incomplete phase, in order. Four steps, always the same.

### Delegate

One call of the `Agent` tool with `subagent_type: "issue-flow:issue-phase"`. The subagent has
not seen the conversation and has not read the issue: **what you do not write to it does not
exist**. The prompt must contain, in full and not summarised:

- number and title of the issue, and the branch you are working on;
- the **Goal**, **Context** and **Out of scope** sections of the issue (**Obiettivo**,
  **Contesto** and **Fuori perimetro** on a 1.x issue);
- the phase number and its **full text**: lead-in, list of files, all the checkboxes with the
  code snippets under them, the "Done when" line;
- what the previous phases left behind, if they deviated from the written plan.

Right before the call, `touch "$GOAL_DIR/in-flight"`, and as soon as the subagent returns,
`rm -f "$GOAL_DIR/in-flight"`, before the verification.

Non-negotiable rules:

- **a new subagent for every phase.** Never reuse one with `SendMessage` for the next phase,
  never hand it two at once, never two phases in parallel: phase N+1 starts from the code that
  phase N left, and in parallel they step on each other's toes on the same files;
- if the roadmap has a Figma phase, it is a phase like the others and goes to its own
  subagent, which will use the `figma:figma-use` skill and the `use_figma` tool on the file
  `${user_config.figma_file}`. It goes **before** the code, always, because the code adapts to
  the Figma and not the other way round;
- the closing phase — documentation and commit — you keep yourself: it is coordination, not
  implementation.

### Verify

When the subagent returns, **you** run the phase's commands and look at the real output. A
subagent's report is a story, not proof.

If the phase has no commands of its own, the project's apply for the part that was touched:
the ones the issue lists in the verification phase, or `${user_config.verify_commands}`.

If verification fails: a second pass with a **new** subagent, to which you give the error
output and what had been tried. If it fails again, stop and report — two failures on the same
phase say that the issue is wrong, not the subagent.

### Tick the boxes on the issue

As soon as verification passes, and not when the work is done. It is the step that makes the
issue readable to whoever resumes after a `/clear`: without it, the roadmap lies.

```bash
# GitLab
glab issue view <number> --output json --jq '.description' > "$SCRATCH/roadmap.md"

# GitHub
gh issue view <number> --json body --jq '.body' > "$SCRATCH/roadmap.md"
sed -i 's/\r$//' "$SCRATCH/roadmap.md"

# turn into `- [x]` ONLY the checkboxes of the phase just closed
# bring the "**Status:**" line to `in progress — phase N of M`

glab issue update <number> --description-file "$SCRATCH/roadmap.md"   # GitLab
gh   issue edit   <number> --body-file        "$SCRATCH/roadmap.md"   # GitHub
```

On a 1.x issue, write the English value on the status line that is already there, and never add
a second one (`TRACKER.md` §6).

**Always re-read the body from the server before rewriting it**, never from a copy kept in the
conversation: the update replaces the whole field and does not merge, so an old version erases
what the user ticked from the page while you were working. And check that the file is not
empty before sending it back up.

If a decision changed during the implementation, **rewrite the line** instead of ticking it:
the roadmap must say what was really done. If the subagent could not complete a checkbox, it
stays `- [ ]` and the reason goes to the user at the end. With an empty checkbox the roadmap
never counts as complete: at the end of the work, delete `$GOAL_DIR/goal` yourself, or the
hook sends you back.

### Commit

The phase and nothing else:

```bash
git add -A && git commit -m "<type>(<scope>): <what changes for whoever uses it> (#<number>)"
```

Messages follow the convention already in the project's log — look at it with
`git log --oneline -20` before the first commit, instead of imposing one of your own. Never
commit with verification failing, never a commit that covers two phases.

## 4. Where this skill ends

At the commit of the last phase, with all the boxes ticked on the issue. **You do not open the
MR/PR here**: `/issue-flow:close <number>` opens it, redoing the verification on the final tree
and writing its body. Telling the user so in the delivery is part of the job — otherwise they
are left with a ready branch and nobody to take it to its destination.

Bring the issue's **Status:** line to `implemented — awaiting merge request` (on GitHub:
`awaiting pull request`), so that whoever reopens the page knows where things stand without
looking at the git log.

## 5. Delivery

A few lines: the closed phases with their commits (`git log --oneline`), the checkboxes left
empty with the reason, the deviations written in the roadmap, the problems the subagents saw
outside their perimeter, and how to continue: `/issue-flow:close <number>`. Do not paste the
issue or the diff.

If it was a child of a big-plan, say so too: which child comes next in the mother, and that it
starts only after the merge of this one, with `/issue-flow:close <number> --merged` ticking the
box on the mother — or that `/issue-flow:big-implement <mother>` moves all the remaining
children forward without waiting for the merges. For a child on the mother branch,
`/issue-flow:close <number>` merges it there by itself, and there is no merge to wait for.

## When to really stop

Stop and ask, instead of carrying on, if: the same phase fails twice; a phase requires a
decision that the issue has not taken; the work substantially touches files that the issue did
not foresee; a verification cannot be run on this machine (missing port, service or
credential); the issue contradicts the code you find.

Before stopping, `rm -f "$GOAL_DIR/goal"`: otherwise the hook sends you back to work.

The right remedy is almost always to fix the issue before fixing the code.
