---
name: close
description: "Takes the work of an already implemented issue to a merge request — a pull request on GitHub: checks that the roadmap is really all ticked, redoes the verification on the final tree, pushes the branch and opens the MR/PR with Closes #number. Once merged, it closes the issue and, if it is a child of a /crew:big-plan, ticks it on the mother. A child of a project that has a mother branch — the one of /crew:big-implement — goes to an MR/PR towards that branch and merges it on its own; the mother goes to an MR/PR towards the target branch, which the user merges. Trigger: /crew:close, 'open the merge request of issue N', 'close issue N'."
argument-hint: "<number> [--merged]"
---

# /crew:close

`/crew:implement` leaves a branch with one commit per phase and the roadmap ticked. This
skill takes it in front of whoever has to read it: a merge request — a pull request, if the
tracker is GitHub — with a body that says what changes and how it was verified. Below,
"MR/PR" stands for whichever of the two applies in this repo; to the user you say the right
word, not the slash.

**Towards the target branch the MR/PR is opened and not merged.** The merge is requested by
the user, always: towards `${user_config.default_branch}` this skill never runs
`tracker.sh mr merge`, not even if the pipelines are green. `tracker.sh` itself refuses a merge
into the repo's default branch, whatever it is asked; a configured target branch that is not the
repo's default is guarded only by this rule.

The one exception is the child of a project that has a **mother branch** — the one that
`/crew:big-implement` opens: its MR/PR points to the mother branch, which is the
project's worksite and not the product, and this skill merges it on its own after the usual
checks. The work reaches the target branch only with the mother's MR/PR, and the user merges
that one.

## Usage

```
/crew:close <number>            # opens the issue's MR/PR
/crew:close <child>             # with the mother branch: MR/PR towards it, merged and closed here
/crew:close <mother>            # with all the children merged: the mother branch's MR/PR
/crew:close <number> --merged   # once merged: closes the issue and aligns the Status
/crew:close                     # infers the number from the current branch
```

## 0. Which tracker, and does it answer

As in step 0 of `implement`. `scripts/tracker.sh` is the only way to the tracker — GitLab or
GitHub, it deduces which from `origin` — and `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` — the
`TRACKER.md` file in this plugin's folder — holds the vocabulary of the two platforms and their
traps, to be read before the first command. Below, `tracker.sh` stands for
`"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh"`, and the blocks write it in full.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" check
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" view <number>
```

When either fails, what it printed is the remedy: the CLI is not installed, or the remote is an
SSH alias that the CLI does not recognise (`TRACKER.md` §2), or you are not authenticated. The
remedies are interactive or by hand: stop and ask the user to run the one that was printed.

## 0 bis. Which case

Re-read the issue from the server (`tracker.sh view <number> | jq -r .body`) and look at the top
of the body. The case decides the **base** — the branch the MR/PR points to — and who merges it:

| case | how you recognise it | base | merge |
|---|---|---|---|
| **issue** | no `**Type:**` and no `**Roadmap:**` | target branch | the user |
| **child** | `**Roadmap:** #<mother>`, and the mother branch is **not** on `origin` | target branch | the user |
| **child on the mother branch** | `**Roadmap:** #<mother>`, and the mother branch is on `origin` | mother branch | this skill, at step 3 bis |
| **mother** | `**Type:** roadmap`, and the mother branch is on `origin` | target branch | the user |

The target branch is `${user_config.default_branch}`, or what
`git symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##'` returns. The mother
branch is `${user_config.branch_prefix}<mother>`, and it exists if:

```bash
git ls-remote --exit-code --heads origin <mother-branch>   # exit 0: it exists
```

A mother **without** its branch has nothing to take to an MR/PR: the children went one by one
into the target branch, and the mother closes by itself with the `--merged` of the last one.
Say so and stop.

Tell the user which case you recognised, before going on.

## 1. Is the work really finished?

Three checks, before touching anything. If one fails **you stop and report it**: an MR/PR
opened on incomplete work costs more than one not opened.

**The roadmap is all ticked.** Re-read the issue from the server and count. The count in the
body is the only one that holds on both platforms — `task_completion_status` exists only on
GitLab:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" body get <number> "$SCRATCH/roadmap.md"

grep -c '^[[:space:]]*- \[[ xX]\]' "$SCRATCH/roadmap.md"   # total
grep -c '^[[:space:]]*- \[[xX]\]'  "$SCRATCH/roadmap.md"   # ticked
grep -n  '^[[:space:]]*- \[ \]'    "$SCRATCH/roadmap.md"   # the ones left
```

For the **mother** the boxes are those of the **Issues** section (`## Issues`), one per
child, and they count like the others: all ticked means all the children merged into the
mother branch. Also check that every child is closed on the tracker (`tracker.sh state <child>`
prints `closed`); a box ticked on an open child, or the opposite, is a mother that fell behind
and has to be fixed first.

If empty boxes remain, list them for the user and ask: either work is missing — and then you go
back to `/crew:implement <number>` — or they have been dropped and the line has to be
rewritten to tell the truth. Do not tick them yourself to make the count add up.

**The branch is the right one and has nothing pending.** The working branch is
`${user_config.branch_prefix}<number>` — for the mother, the mother branch itself; the base is
the one from step 0 bis.

```bash
git fetch origin
git branch --show-current             # must be the issue's branch
git status --porcelain                # must be empty
git log --oneline origin/<base>..HEAD # the phases' commits, one per phase — for the mother, the
                                      # children's merges with their commits
git merge-base --is-ancestor origin/<base> HEAD   # exit 0: the branch contains the base
```

If the branch does not contain the base — the target branch moved on while the project was on
the mother branch, or the mother branch moved on while the child was working — merge the base
into the branch (`git merge origin/<base>`) and redo the checks. If the merge has conflicts,
`git merge --abort` and stop: how to resolve them is a decision, not a typo.

If the working tree is dirty, stop: that work is in no commit and would not end up in the
MR/PR.

**Verification passes on the final tree.** The single commits were green one by one; here what
counts is the result of all of them together. Run the commands that the issue lists in its
verification phase — or `${user_config.verify_commands}` — and look at the real output, not
the summary.

For the **mother** the verification is the whole project's: the union of the commands of the
children's verification phases, or `${user_config.verify_commands}`, run on the tree of the
mother branch — it is the first time they all run together.

Then the by-hand check of what the issue promised should be visible. If anything is red you do
not open the MR/PR: you fix it with a commit on the branch, or you stop and report it.

## 2. The documentation

Before the MR/PR, not after: the documentation must describe the new behaviour, not the old.
Re-read the files that the issue's closing phase named — or those in
`${user_config.docs_paths}` — and check them against the code as it is now. If one falls short,
update it and commit before going on.

## 3. Open the MR/PR

```bash
git push -u origin <branch>

"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" mr create <number> <branch> <base> "<the same title as the issue>" "$SCRATCH/mr.md"
```

`mr create` prints the MR/PR number: read it from there. On GitHub it will not be the issue's —
issues and pull requests share the same number sequence. The link to the issue is the
`Closes #<number>` that opens the body below: on GitHub `mr create` adds it when the body lacks
it, on GitLab it also links the issue itself (`TRACKER.md` §5).

For the **child on the mother branch**, `<base>` is the mother branch: on both platforms the
`Closes #<number>` acts only on the default branch, so you close the child yourself at step
3 bis. The body is the same, with one line under the `Closes`:
`Part of #<mother> — merges into <mother-branch>.`

The body is short and stands on its own — the issue has the plan, the MR/PR has the outcome.
Whoever reviews should not have to open two pages to understand what they are looking at. It is
written in English, whatever language the chat is in:

```markdown
Closes #<issue number>

## What changes
[two or three lines on what is different for whoever uses the product, not the list of files]

## How it was verified
[the commands run and what they actually printed, with the numbers; the by-hand check and what
was seen]

## Deviations from the plan
[the roadmap lines rewritten during the implementation, with the reason. "None" if there are
none.]
```

For the **mother** the body carries `Closes #<mother>` and, between "What changes" and "How it
was verified", one more section:

```markdown
## Children
- #21 <title> — !40        # on GitHub: — #40
- #22 <title> — !41
```

with the MR/PRs through which each child entered the mother branch
(`tracker.sh mr list --base <mother-branch> --merged`). "Deviations from the plan" gathers those
of the children.

The numbers in here are those you **read** at step 1, not those you expected: an MR/PR that
declares green tests never run is the fastest way to let an error through.

Then bring the issue's **Status:** line to `in review — !<MR number>` on GitLab, or
`in review — #<PR number>` on GitHub. Take the body with `body get` **after** the MR/PR is open,
because opening it may write to the issue (on GitLab it links it) and `body put` refuses a body
read before any write. It replaces the whole body and does not merge:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" body get <number> "$SCRATCH/roadmap.md"

# you touch only the status line: `**Status:**`

"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" body put <number> "$SCRATCH/roadmap.md"
```

If `body put` refuses because the issue changed, run `body get` again and redo the change;
`implement` lists the other refusals. Never delete the `.stamp` to force it.

For the **child on the mother branch** you do not stop here: go on with step 3 bis. In the
other cases the skill ends with the MR/PR open, and goes on when the user comes back with
`--merged`.

## 3 bis. The merge into the mother branch

Only for the **child on the mother branch**, right after step 3, without asking: the checks that
whoever reviews would have made you did at steps 1 and 2.

**The pipelines, if any.** Wait for them to finish and look at the outcome:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" mr checks <mr>
```

It waits, then prints `success` or `none` — no pipeline, which is green — and exits 0, or prints
the failure and exits 1. A red pipeline is a "When to really stop" case, like a red
verification at step 1.

**The merge**, tied to the commit you verified, so nothing you have not seen gets merged:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" mr merge <mr> "$(git rev-parse HEAD)"
```

`mr merge` merges only that commit, refuses the repo's default branch, and re-reads the state:
it exits 1 unless the MR/PR is `merged` **now**. If the server queued it or put it in
auto-merge, or refused it — conflicts, required approvals, protected branch — stop and report
what it says. Why it merges the way it does is in `TRACKER.md` §5.

**The closing**, without waiting for `--merged`: all of step 4 — the issue closed, the child's
**Status:** to `closed — merged into <mother-branch> on DD/MM/YYYY`, the working branch deleted
if the server has not already done it, and the box ticked on the mother as in "The mother, if
the issue is a child". Locally you go to the tip of the mother branch, freshly fetched (`<base>`
below is the mother branch). A linked worktree must never take a branch the main checkout may
need, so there you detach at `origin/<base>` instead of switching to it, and bring the local
`<base>` to the same commit: whoever switches to it later — step 5 of `big-implement`, on the
mother branch — lands on the tip, not on the commit the branch had when it was created. That
fetch fails, silently, when another checkout has `<base>`; that checkout keeps it up to date:

```bash
git fetch origin
if [ "$(git rev-parse --path-format=absolute --git-dir)" = "$(git rev-parse --path-format=absolute --git-common-dir)" ]; then
  git switch <base> && git pull --ff-only     # the main checkout: back on the base, as before
else
  git switch --detach origin/<base>           # a linked worktree: the tip of the base, no branch taken
  if git show-ref -q --verify refs/heads/<base>; then git fetch -q origin <base>:<base> 2>/dev/null || :; fi   # the local <base> there too
fi
```

## 4. After the merge — `--merged`

Only when the user says the MR/PR has been merged — or, for the child on the mother branch,
from step 3 bis as soon as the merge is confirmed. You check that it is true, then close:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" mr state <number-or-branch>    # must say "merged"
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" close <number>
```

`close` prints `closed`, or `already closed` when the issue was closed before — on GitHub the
`Closes #<number>` of a merged PR does it by itself — and then it did not write anything: that
is what you tell the user, not that you closed it.

Then bring the **Status:** line to `closed — merged on DD/MM/YYYY`, with today's date — for the
mother, `closed — completed on DD/MM/YYYY` — with the `body get` **after** the close, because the
close moved the issue's timestamp, then the edit and `body put`. Locally: the block at the end of
step 3 bis, with this issue's `<base>`. The working branch is deleted only if the server has not
already done it — `mr merge` deletes it for the child on the mother branch, GitLab does it for an
MR opened by `mr create`, GitHub does it when the repo's "Automatically delete head branches"
option is on —, and if none has removed it, `git push origin --delete <branch>`.

If the state of the MR/PR is not `merged`, close nothing and say so.

### The mother, if the issue is a child

If the top of the issue body has `**Roadmap:** #<mother>`, the child just closed has to be
ticked on the mother: it is the only place where you can read how far the project is.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" body get <mother> "$SCRATCH/mother.md"

# turn into `- [x]` ONLY the `- [ ] #<number>` line of the Issues section (`## Issues`)
# bring the mother's status line to `in progress — k of M issues merged`

"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" body put <mother> "$SCRATCH/mother.md"
```

The usual rules: `body get` right before the edit, touch only those two lines, and when `body put`
refuses — the mother changed since the `body get` — read it again and redo the two lines. The
child's MR/PR carries `Closes #<child>` and **never** the mother's number: the mother is not
closed at the merge of a child.

For the **child on the mother branch** the mother's **Status:** becomes
`in progress — k of M issues merged into <mother-branch>`, and the mother is **not closed**
even when the last box is ticked: the work is in the mother branch, not yet in the target
branch. In the delivery name the next child — or, if they were all done, the next step:
`/crew:close <mother>`, which opens the mother's MR/PR.

For the **child** merged directly into the target branch, if after the tick all the boxes of the
Issues section are `- [x]`, the project is finished: close it (`tracker.sh close <mother>`),
then `body get` it again — the close moved its timestamp — and bring the mother's **Status:** to
`closed — completed on DD/MM/YYYY` with a `body put`. Otherwise, in the delivery, name the next
child: the first `- [ ] #<n>` left, to start with `/crew:implement <n>` — or
`/crew:implement <mother>`, which finds it on its own.

### The mother

`--merged` on the **mother**, with the mother's MR/PR merged: step 4 as it stands, with the
mother branch as the working branch. The children are already closed and ticked; what is left
is to close the mother (`tracker.sh close <mother>`, which says `already closed` if the
`Closes #<mother>` got there first) and to delete the mother branch.

## 5. Delivery

The MR/PR link, what you verified with the real numbers, the documentation files you had to
update, and what you found not right and fixed in order to open it. After a `--merged` on a
child — or a merge at step 3 bis — how far the mother is (`k of M issues merged`) and which
child comes next. If you stopped, the reason in one line and what is needed to unblock.

## When to really stop

Stop and ask, instead of opening the MR/PR, if: there are unticked checkboxes left; the working
tree is dirty; a verification is red and the cause is not an obvious typo; the branch is behind
the base in a way that merging it brings conflicts to decide; the issue is already closed or
already has an open MR/PR (a `tracker.sh mr list --head <branch>` that is not empty) — except,
for the child on the mother branch, an MR/PR left open by an interrupted run, which is resumed
from step 3 bis; a pipeline is red, or the server does not merge the child's MR/PR into the
mother branch.
