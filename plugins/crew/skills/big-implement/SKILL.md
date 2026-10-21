---
name: big-implement
description: "Runs, in a single execution, all the child issues of a /issue-flow:big-plan mother issue — GitLab or GitHub — on the mother branch: one child at a time, in the mother's order, each handed to an issue-runner subagent that does the round of /issue-flow:implement (one subagent per phase, checkboxes ticked, one commit per phase) and the one of /issue-flow:close, which verifies, opens the merge request — pull request on GitHub — towards the mother branch and merges it by itself. At the end it opens the mother's MR/PR towards the target branch, which only the user merges. Trigger: /issue-flow:big-implement, 'implement the whole project N', 'run the whole roadmap N', 'run all the children of N'."
argument-hint: "<mother>"
hooks:
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/goal-stop.sh"
---

# /issue-flow:big-implement

`/issue-flow:implement <mother>` runs **one** child and stops: the next one starts only after the
previous one is merged, which the user does. This skill carries the **whole project** forward in
one go, without waiting for anyone until the end:

```
main ──────────────────────────────────────────────── ◀── MR/PR issue-20 (merged by the user)
  └─ issue-20 ──●──────────●──────────●─────────
                ▲          ▲          ▲
            issue-21   issue-22   issue-23     (each is born from issue-20 and returns to it on its own)
```

- the mother has its own branch, `${user_config.branch_prefix}<mother>`, born from the target
  branch;
- each child is born from the updated mother branch, is implemented, and then goes through `close`:
  verification on the final tree, documentation, MR/PR **towards the mother branch** — which
  here `close` **merges by itself**, because the mother branch is not the product: it is the
  project's building site, and the real review comes at the end;
- when the last child is merged, the mother's MR/PR towards the target branch is opened as
  usual and **is not merged**: the user approves and merges that one.

The execution rules are those of `implement` and `close` and are not repeated here:
`${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md` for the phases, the verification, the ticks, the
commits and goal mode; `${CLAUDE_PLUGIN_ROOT}/skills/close/SKILL.md` for the final verification,
the documentation, the MR/PR, the merge into the mother branch and the closing;
`${CLAUDE_PLUGIN_ROOT}/TRACKER.md` for the commands of the two platforms. **Read all three
before the first command.** Below there is only what changes.

## Usage

```
/issue-flow:big-implement <mother>   # runs, in sequence, all the children not yet merged
```

## You are the orchestrator, of the whole project

You do not implement the children and you do not orchestrate their phases: you hand each child to
an `issue-flow:issue-runner` subagent, which does the round of `implement` and `close` for it
up to the merge into the mother branch, and in turn hands each phase to an
`issue-flow:issue-phase` subagent:

```
you (big-implement)                 the project: chain, mother branch, goal, mother's MR/PR
 └─ issue-runner, one per child     the child: phases, verifications, ticks, commits, close, merge
     └─ issue-phase, one per phase  the phase: the code
```

The reason is context, as in `implement` but one level up: the phases of all the children in
your context would fill it halfway through the project. You keep the vision of the project —
which child is in progress, with which MR/PR, how many are already in the mother branch, what
they changed along the way — and you check the outcome of each child on the tracker and on git,
not on the runner's story.

The chain uses all the depth that Claude Code allows: under the main session, subagents can
launch others for two levels, and the third no longer has the `Agent` tool. That is why
`issue-phase` does not delegate, and the runner must never be launched by another subagent.

**Never two children together.** Neither in parallel nor interleaved: child N+1 is born from the
mother branch **after** N has been merged into it, and starts from the code that N left.

## 0. Which tracker, and does it answer

Identical to step 0 of `implement`.

## 1. Read the mother and work out the chain

Read the mother from the server as in step 1 of `implement`. If the top of the body does not have
`**Type:** roadmap` (or `**Tipo:** roadmap` on a 1.x issue), it is not a mother: say so and
propose `/issue-flow:implement <number>`. Both spellings are in `TRACKER.md` §6.

From the **Issues** section (`## Issues`, or `## Issue` on a 1.x issue), in order, take the
`- [ ] #<n>` lines: they are the children to carry forward. The `- [x]` ones are already merged —
into the mother branch or, from a round done by hand, into the target branch — and are not
touched. For each child still to do, look on the tracker:

- **the state**: if it is already closed but the box is empty, the mother has fallen behind —
  flag it, do not re-run it, and treat it as merged;
- **the dependencies** — `· depends on #<k>` in the mother (`· dipende da #<k>` on a 1.x issue),
  `**Depends on:**` in the child (`**Dipende da:**`): each one must be merged (box ticked or
  issue closed) **or** a child that this run carries forward **before** it. A dependency in
  neither case — an open external issue, a sibling that comes later in the order — is a roadmap
  that does not hold: stop and say so;
- **whether it has already started** in a previous round: the branch
  `${user_config.branch_prefix}<n>` exists, has ticked checkboxes, already has an MR/PR
  (`glab mr list --source-branch <branch>`, `gh pr list --head <branch>`). Resume from where it
  was left instead of starting over: from the first unticked phase, from the MR/PR if the
  phases are all done, from the merge if the MR/PR is open.

Look at the **mother** too: if it already has an MR/PR open towards the target branch
(`glab mr list --source-branch <mother-branch>`, `gh pr list --head <mother-branch>`), the
project is already delivered — say so and do not start again.

Then present the chain to the user and start without asking for confirmation:

```
issue-20  mother branch, born from main
#21  issue-21  born from issue-20   MR/PR → issue-20, merged by close
#22  issue-22  born from issue-20   MR/PR → issue-20, merged by close
#23  issue-23  born from issue-20   MR/PR → issue-20, merged by close
issue-20  MR/PR → main, merged by the user
```

If there is no child to do but the mother does not have its MR/PR yet, jump to step 5.

## 2. The mother branch

The mother branch is `${user_config.branch_prefix}<mother>` — with the default `issue-`, mother
#20 has `issue-20`. It is born from the updated target branch, and goes **immediately to the
remote**: the children's MR/PRs point to it, and `close` recognises the big-implement flow
precisely from its existence on `origin`.

```bash
git status --porcelain                 # must be empty
git fetch origin
git switch <mother-branch> 2>/dev/null \
  || git switch -c <mother-branch> --track origin/<mother-branch> 2>/dev/null \
  || { git switch <target> && git pull --ff-only && git switch -c <mother-branch>; }
git push -u origin <mother-branch>
```

If the branch already existed from a previous round, align it to `origin` with
`git pull --ff-only`. If the target branch has moved on in the meantime, **do not** chase it: the
mother branch is realigned only once, at step 5 — in `close` on the mother —, where a conflict
is the user's decision.

Bring the mother's **Status:** line to `in progress — k of M issues merged into <mother-branch>`
(on a 1.x mother, on the status line that is already there — `TRACKER.md` §6).

## 3. The goal covers the whole project

Goal mode is the one of `implement`, with one difference: `$GOAL_DIR/goal` contains **all** the
children to carry forward and **the mother**, one number per line. The `Stop` hook re-reads each
one from the tracker and does not let the turn close while any of them has a `- [ ]`: in the
Plan for the children, in the **Issues** section for the mother — which is ticked only when a
child is merged into its branch. So the goal holds until the last merge, not only until the last
phase.

```bash
GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow)
mkdir -p "$GOAL_DIR" && printf '%s\n' 21 22 23 20 > "$GOAL_DIR/goal" && rm -f "$GOAL_DIR/in-flight"
```

You write it after step 2, before the first child. `in-flight` works as in `implement`, but it
signals the **runner** at work: you create it right before delegating the child and delete it
as soon as the runner returns. One runner at a time. The runner does not touch `.git/issue-flow/`:
the goal and `in-flight` are yours alone.

When the last child is merged the hook lets you stop even if the mother's MR/PR is not open
yet. Do not stop there: the delivery comes after step 5.

To stop before the end, **you delete `$GOAL_DIR/goal`** and tell the user why.

## 4. The round, one child at a time

For each child of the chain, in order: you delegate it to a runner (4.1), the runner does the
child's round (4.2), you check how it ended (4.3). Then the next child.

### 4.1 Delegate the child

One call of the `Agent` tool with `subagent_type: "issue-flow:issue-runner"`. The runner has not
seen the conversation: **what you do not write to it does not exist**. In the prompt:

- the number and title of the child, the number of the mother, the mother branch and the target
  branch;
- the absolute paths of the instructions it must read:
  `${CLAUDE_PLUGIN_ROOT}/skills/big-implement/SKILL.md` — for step 4.2, its round —,
  `${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md`, `${CLAUDE_PLUGIN_ROOT}/skills/close/SKILL.md`
  and `${CLAUDE_PLUGIN_ROOT}/TRACKER.md`;
- the configuration values: `${user_config.branch_prefix}`, `${user_config.default_branch}`,
  `${user_config.verify_commands}`, `${user_config.docs_paths}`, `${user_config.figma_file}` —
  empty ones included, stated as empty;
- where to resume from, if step 1 found the child already started: the first unticked phase,
  the MR/PR already open, the merge;
- what the siblings already merged in this run left behind, if they deviated from their
  issue — the child's writer knew them only as a plan. It is the deviations from the plan in
  the previous runners' reports.

Right before the call `touch "$GOAL_DIR/in-flight"`, and as soon as the runner returns
`rm -f "$GOAL_DIR/in-flight"`, before the check.

Non-negotiable rules: **a new runner for every child**, never reuse one with `SendMessage` for
the next child, never two children in parallel. While the runner works you do not touch the
working tree or the tracker: you are on the same folder and on the same issues.

### 4.2 The child's round

The runner does this, and it sits here because it is its reference. Three steps.

#### The branch, from the mother

The base of every child is the updated mother branch, **after** the previous sibling's merge:

```bash
git status --porcelain                 # must be empty
git switch <branch> 2>/dev/null \
  || { git switch <mother-branch> && git pull --ff-only && git switch -c <branch>; }
```

It is the rule of step 2 of `implement` with the mother branch in place of the target branch:
that is where the siblings already merged are. The check of step **1 ter** of `implement` is
made against the mother branch: the dependencies are closed and their work is there
(`git log --oneline <mother-branch> | grep '#<k>'`), and the hook points "created in #<k>" exist
there. If they do not hold, you stop as `implement` says.

#### The phases

Step 3 of `implement`, with a single variant: no `in-flight` and no `goal`, which belong to
`big-implement`. A **new** `issue-flow:issue-phase` subagent for every phase with the child's
full context, verification run by the runner, tick on the issue re-reading it from the server,
one commit per phase with `(#<child>)` in the message. At the end of the phases, the child's
**Status:** line as at step 4 of `implement`.

The prompt of every phase also carries what the siblings already merged left behind, if they
deviated from their issue.

#### Close, up to the merge into the mother branch

All of `close` on the child, in its "child on the mother branch" case: the checks of step 1, the
documentation of step 2, the MR/PR of step 3 **towards the mother branch**, then the merge and
the closing of step 3 bis, which do not wait for the user. At the end:

- the child's MR/PR is merged into the mother branch, and the child's branch is deleted;
- the child is closed, with **Status:** `closed — merged into <mother-branch> on DD/MM/YYYY`;
- its box on the mother is ticked, and the mother's **Status:** says `k of M`;
- you are on the mother branch, updated: the next child is born from here.

If `close` stops — an empty box, a red verification, a failed pipeline, an MR/PR that the server
does not merge — the runner stops and writes it in the report.

### 4.3 Check how it ended

The runner's report is a story, not proof. Before moving on to the next child you check, on the
server and on git:

```bash
# the child's MR/PR is merged into the mother branch
glab mr list --source-branch <branch> --target-branch <mother-branch> --merged   # GitLab
gh   pr list --head <branch> --base <mother-branch> --state merged               # GitHub

# the child is closed, with all the Plan boxes ticked
glab issue view <child> --output json --jq '.state'    # "closed"
gh   issue view <child> --json state --jq '.state'     # "CLOSED"

# its box is ticked on the mother: re-read the mother from the server

# you are on the mother branch, clean and updated, with the child's commits in it
git branch --show-current && git status --porcelain
git fetch origin && git status -sb | head -1              # no "behind"
git log --oneline <mother-branch> | grep '(#<child>)'
```

If the runner stopped, or one of these checks does not come out right, the project stops: see
"When to really stop". A runner that says "merged" when the server says otherwise is not
retried: the child has to be looked at.

Keep the report's deviations: they go in the next child's runner prompt and in the delivery.

Then move on to the next child.

## 5. The mother's MR/PR

When all the boxes of the mother's **Issues** section (`## Issue` on a 1.x issue) are ticked,
`close` on the mother, in its "mother" case: it redoes the verification on the final tree of the
mother branch, aligns the documentation, pushes and opens the MR/PR
`mother branch → target branch` with `Closes #<mother>`. **Never the merge**: the user approves
and merges this one, like every MR/PR towards the target branch.

## 6. Delivery

The link to the mother's MR/PR, at the top: it is the only thing the user has to do. Then a
table, in the order the children entered the mother branch:

```
child   MR/PR  phases  merged into
#21     !40    6/6     issue-20
#22     !41    7/7     issue-20
#23     !42    5/5     issue-20
```

Then the checkboxes left empty with the reason, the deviations written in the roadmaps, the
problems the subagents saw outside their perimeter. And how to continue: once the mother's MR/PR
is merged, `/issue-flow:close <mother> --merged`, which closes the mother and deletes its
branch.

Do not paste the issues or the diff.

## When to really stop

All the cases of "When to really stop" of `implement` and of `close` — which for a child the
runner meets, and reports to you —, plus one: **if a child stops, the project stops with it.**
The next one would be born from a mother branch without its work, so there is no skipping ahead.
In the delivery say which child stopped, at what point — phase, MR/PR, merge — why, and that you
resume with `/issue-flow:big-implement <mother>` once it is sorted out: step 1 finds the children
already merged and restarts from there.

Before stopping, `rm -f "$GOAL_DIR/goal"`: otherwise the hook sends you back to work.
