---
name: review
description: "Reviews the finished work of an issue before its merge request — a pull request on GitHub — is opened: re-runs the issue's verification on the branch tip, runs Claude Code's code-review on the diff against the target branch, checks the ticked boxes and the Out of scope against that diff, and writes one comment on the issue with the verdict and the SHA it reviewed, which /crew:close requires before it opens the MR/PR. It never edits code: its findings go back to whoever implemented. Trigger: /crew:review, 'review issue N', 'review the branch of N'."
argument-hint: "[<number>]"
---

# /crew:review

`/crew:implement` stops at the commit of its last phase, `/crew:close` opens the merge request — a
pull request, if the tracker is GitHub. This skill sits between the two: `/crew:close` opens an
MR/PR towards the target branch only if the issue carries a **passed review of the exact commit
being pushed**, and `scripts/review-gate.sh` checks it right before the push. A review is bound to
a commit: one commit after it, even the merge of the base that `/crew:close` makes, and the gate
asks for a new one. Below, "MR/PR" stands for whichever of the two applies in this repo; to the
user you say the right word, not the slash.

Whoever reviews runs it — in crew, the sottoposto. It re-runs the issue's verification on the
branch tip, has Claude Code's built-in `code-review` read the diff, checks the roadmap and the
Out of scope against that diff, and writes **one comment** with a machine-readable verdict and the
SHA it looked at.

**It never edits code.** No `Edit` or `Write` on project files, no commit, no
`git switch`/`checkout`/`stash`/`reset` in any worktree, no `--fix`. Its findings go back to
whoever implemented, who fixes them with new commits and asks for a new review. On the tracker it
writes only the Status line and that one comment; on disk, at most a temporary worktree and one
line in `info/exclude` (step 2).

## Usage

```
/crew:review <number>   # reviews that issue's branch
/crew:review            # infers the number from the current branch
```

Without a number the skill reads it from the current branch, `${user_config.branch_prefix}<n>`,
as `implement` does. On any other branch — a tree on the target branch, say — it asks which issue.
It is always typed with the namespace: the bare `/review` is Claude Code's alias of its own
`code-review`, and a plugin skill does not take it over.

## 0. Which tracker, and does it answer

As in step 0 of `implement`. `scripts/tracker.sh` is the only way to the tracker — GitLab or
GitHub, it deduces which from `origin` — and `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` — the `TRACKER.md`
file in this plugin's folder — holds the vocabulary of the two platforms and their traps, to be
read before the first command. Below, `tracker.sh` stands for
`"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh"`, and the blocks write it in full.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" check
```

When it fails, what it printed is the remedy: the CLI is not installed, or the remote is an SSH
alias that the CLI does not recognise (`TRACKER.md` §2), or you are not authenticated. The
remedies are interactive or by hand: stop and ask the user to run the one that was printed.

## 1. The issue

Read it from the server, all of it:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" view <number>
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" body get <number> "$SCRATCH/roadmap.md"
```

If the issue is closed, stop: there is nothing left to review. Then work out the case, with the
table of step 0 bis of `close`: `**Type:** roadmap` at the top of the body is a mother,
`**Roadmap:** #<mother>` a child, neither a plain issue. The mother branch is
`${user_config.branch_prefix}<mother>`, and it is on `origin` if
`git ls-remote --exit-code --heads origin <mother-branch>` exits 0. The target branch is
`${user_config.default_branch}`, or what
`git symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##'` returns.

| case | branch | base |
|---|---|---|
| issue, or child towards the target branch | `${user_config.branch_prefix}<n>` | the target branch |
| mother, with its branch on `origin` | the mother branch | the target branch |
| **child on the mother branch** | — | stop: it merges into the mother branch without a review, and the review of the mother covers it |

A mother **without** its branch has nothing to review either: its children went one by one into
the target branch. Say so and stop. Tell the user which case you recognised and which branch and
base you will review, before going on.

**Every box must be ticked.** Count them in the body, the only count that holds on both
platforms (`TRACKER.md` §5):

```bash
grep -c '^[[:space:]]*- \[[ xX]\]' "$SCRATCH/roadmap.md"   # total
grep -c '^[[:space:]]*- \[[xX]\]'  "$SCRATCH/roadmap.md"   # ticked
grep -n  '^[[:space:]]*- \[ \]'    "$SCRATCH/roadmap.md"   # the ones left
```

Empty boxes mean `implement` has not finished: stop and say so, listing them, and send the user
back to `/crew:implement <number>`. Do not tick them yourself. For the **mother** the boxes are
those of `## Issues`, one per child, and all must be ticked; also check that every child is closed
(`tracker.sh state <child>` prints `closed`). A box ticked on an open child, or the opposite, is a
mother that fell behind: stop.

## 2. The commit, and the tree that has it

The branch is usually local only — `implement` stops without pushing — and it may be checked out
in the main checkout, in a linked worktree under `.claude/worktrees/`, or nowhere. Linked
worktrees share `refs/heads/`, so the tip is the same from any of them, and git refuses to check a
branch out twice: find the tree that has it with one lookup, wherever you are.

```bash
git fetch origin
SHA=$(git rev-parse --verify -q "refs/heads/<branch>" || git rev-parse --verify -q "refs/remotes/origin/<branch>")
WT=$(git worktree list --porcelain | while read -r k v; do
  case $k in worktree) p=$v ;; branch) [ "$v" != "refs/heads/<branch>" ] || { echo "$p"; break; } ;; esac
done)
```

No positional parameter — a dollar sign followed by a digit — goes in these commands, not even
inside awk: Claude Code replaces it with the skill's argument when it loads the skill.

Stop if:

- `$SHA` is empty: there is no branch, locally or on `origin`;
- the local branch and `origin/<branch>` both exist and `origin/<branch>` has commits the local
  branch lacks — `git rev-list --count refs/heads/<branch>..refs/remotes/origin/<branch>` is not
  0 —, because then `origin` is ahead or the two diverged, and it is not clear which commit `close`
  will push. Say which (`git rev-list --left-right --count
  refs/heads/<branch>...refs/remotes/origin/<branch>`). A local branch strictly ahead is no stop:
  its tip is what `close` pushes — after it merged `origin/<base>` into a branch already on
  `origin`, say — and `$SHA` is that tip;
- `$WT` is set and `git -C "$WT" status --porcelain` is not empty: uncommitted work is not in the
  commit under review.

`$SHA` is what you review, from here to the end. Keep it, `$WT`, and whether you made the worktree
below: the later steps use them, and if the shell does not keep variables between calls, write
their values into the commands.

**When no tree has the branch** (`$WT` empty), make a temporary detached worktree at `$SHA`, under
the main checkout's `.claude/worktrees/` like the worktrees of a profile. Not under `.git`, where
Claude Code prompts on every write. First make sure `<git-common-dir>/info/exclude` has the
`/.claude/worktrees/` line that `crew run` adds, appending it if missing: otherwise the temporary
worktree would show as untracked in the main checkout, where the ciurma may be working.

```bash
MAIN=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
EXCL=$(git rev-parse --path-format=absolute --git-common-dir)/info/exclude
grep -qxF '/.claude/worktrees/' "$EXCL" 2>/dev/null || {   # a last line without its newline keeps its own
  mkdir -p "${EXCL%/*}" && { [ ! -s "$EXCL" ] || [ -z "$(tail -c 1 "$EXCL")" ] || echo >>"$EXCL"; } &&
    echo '/.claude/worktrees/' >>"$EXCL"
}
WT=$MAIN/.claude/worktrees/review-<number>
git worktree remove --force "$WT" 2>/dev/null; git worktree prune   # left over from an interrupted run
git worktree add --detach "$WT" "$SHA"
# … step 8: git worktree remove --force "$WT"
```

**A fresh worktree needs its setup.** It has only the tracked files, none of the git-ignored ones
such as `node_modules`, `.venv` or build output. Before the first verification, if this folder lacks
what the commands need, run there the project's setup command once, as `implement` does in step 2:
the one the issue's **Context** names, otherwise the one the project's README, `CLAUDE.md` or CI
runs before its tests. If no source names one and a verification fails for a missing dependency,
stop and ask: a guessed setup installs the wrong thing. A tree that already had the branch is set
up, and you skip it.

The temporary worktree is removed at step 8 and at every stop. It is the only thing this skill
makes that is not on the tracker.

## 3. Status becomes `reviewing`

The Status line says a review is running, so that nobody takes the branch to `close` meanwhile.
`body put` replaces the whole body and does not merge, so the `body get` comes right before the
edit, and you touch only the `**Status:**` line:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" body get <number> "$SCRATCH/roadmap.md"

# you touch only the status line: `**Status:**` becomes `reviewing`
# keep the line you found: a stop gives it back

"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" body put <number> "$SCRATCH/roadmap.md"
```

If `body put` refuses because the issue changed, run `body get` again and redo the change; the
refusals are those listed in step 3 of `implement`. Never delete the `.stamp` to force it.

**From here to step 7, every stop** removes a temporary worktree if you made one, writes no
comment, and puts the line you found back: a fresh `body get`, the Status line set to what it was,
`body put`. A review that did not finish leaves no trace on the page.

## 4. The verification

Run it in `$WT`, with `cd "$WT" && <command>` for each command, because the shell may not stay
there between calls. The commands are those the issue lists in its verification phase, or
`${user_config.verify_commands}`. For the **mother** they are the union of the commands of the
children's verification phases (`tracker.sh body get <child> "$SCRATCH/child-<child>.md"` for each
one), as `close` does for the mother: it is the first time they all run on the whole project.

Read the real output: a report is a story, not proof. What goes in the comment is the line each
command printed that gives the outcome, with its numbers.

- A **red command is a finding**, not a stop: the review goes on, and the verdict will say
  `changes-requested`.
- A command that **cannot run on this machine** — a missing service, port or credential — is a
  stop: a review that did not run the verification passes nothing.

Then check that the branch holds the base, because `close` would otherwise merge it itself and
that merge would not be reviewed:

```bash
git merge-base --is-ancestor origin/<base> "$SHA"   # exit 0: the branch contains the base
```

Exit 1 is a **finding**: merge `origin/<base>` into the branch, then ask for a new review. Any other
non-zero exit is an error of the command: stop. You do not do the merge yourself.

## 5. Claude Code's review

The built-in `code-review` skill, through the `Skill` tool:

```text
skill: "code-review"
args:  "high origin/<base>...<SHA>, checked out at <WT>"
```

Each argument is what it is for a reason:

- **`high`** is written out. Without a level the review reuses the last level the user typed, even
  in an earlier session, so the same branch would be reviewed differently from one run to the next.
- **`origin/<base>...<SHA>`** pins the reviewed commit, not the branch name: the branch can move
  while the review runs.
- **`checked out at <WT>`** points the reviewer at the files of that commit, because the session's
  own tree can be on another branch.
- Never `--fix` or `--comment`, and never `ultra`, which reviews the current branch in the cloud
  and not a given SHA. This skill never edits code, and there is no MR/PR yet to comment on.

The skill is named `code-review`, never `review`: the bare name is the alias that this skill does
not take over.

Wait for the findings. In a terminal session `code-review` runs as a forked background subagent,
and what it finds arrives in the conversation as text when it completes. Then check each one
against the code in `$WT`:

- a correctness bug that you can show in the code is a **finding**;
- a cleanup — reuse, simplification, efficiency — is a **note**;
- one that the code refutes is a note too, with the reason in one line.

If the `Skill` tool cannot run `code-review`, stop and say why: it needs Claude Code 2.1.246 or
later, and no `"skillOverrides": {"code-review": "user-invocable-only"}` entry hiding it from
Claude.

## 6. The roadmap against the diff

Read what the branch really did, not what the roadmap says it did:

```bash
git log --oneline origin/<base>.."$SHA"
git diff origin/<base>..."$SHA"
```

Each of these is a **finding**:

- a ticked box whose work is missing from the diff, or done differently from what the line says
  without the line having been rewritten: the roadmap lies;
- a change that no box covers;
- anything the issue's **Out of scope** excludes;
- a documentation file that the closing phase names and that does not describe the new behaviour.

For the **mother** the boxes are the children: each child's commits, with their `(#<child>)`, are
in the log, and the mother's Out of scope held.

## 7. The comment

First check that the branch still points at `$SHA`, with the `rev-parse` of step 2. If it does not,
stop: the branch moved during the review, and the verdict would be about a commit nobody pushes.

The verdict is `passed` only when there is **no finding**; notes never block. Write the comment to
`$SCRATCH/review-<number>.md`, in English whatever language the chat is in, and send it:

```bash
git rev-list --count origin/<base>.."$SHA"        # <k> commits
git diff --shortstat origin/<base>..."$SHA"       # the numbers of the diff

"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" comment add <number> "$SCRATCH/review-<number>.md"
```

There is **one comment per run**, and an older review comment is never edited or deleted: the
latest one wins, and the history stays. The comment is the source of truth, not the Status line.

```markdown
<!-- crew:review verdict=passed sha=<full SHA> -->
## Review — passed at `<sha7>`

`<branch>` against `origin/<base>`: <k> commits, <the output of git diff --shortstat>.

### Verification
- `<command>` — <the line of the real output that gives the outcome, with its numbers>

### Findings
None.

### Notes
None.
```

The first line is the marker that `scripts/review-gate.sh` reads, and it is the first line: no
blank line, no heading before it, and the full 40-character SHA, never a prefix. With a finding the
first line is `<!-- crew:review verdict=changes-requested sha=<full SHA> -->` and the heading is
`## Review — changes requested at <sha7>`. Each finding is numbered: `path/file:42` — what is
wrong, why it matters, what would fix it.

## 8. Status, and the worktree

After the comment, in this order:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" body get <number> "$SCRATCH/roadmap.md"

# you touch only the status line: `reviewed — <sha7>` or `changes requested — <sha7>`

"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" body put <number> "$SCRATCH/roadmap.md"

git rev-parse --short "$SHA"        # <sha7>
git worktree remove --force "$WT"   # only if you made it, at step 2
```

The `body get` is needed because the comment moved the issue's `updatedAt` (`TRACKER.md` §5), and
`body put` refuses the stamp of step 3. The comment goes first because it is what the gate reads:
a Status write that fails leaves a valid review, and you say so in the delivery instead of
retrying forever. Only then remove the temporary worktree, if you made one.

## 9. Delivery

The verdict, the SHA, the findings in one line each, and the link to the issue. Then the way on:

- **passed**: `/crew:close <number>` opens the MR/PR, as long as the branch stays at `<sha7>`. A
  commit added after the review, and `close`'s own merge of the base, need a new one;
- **changes requested**: the findings go to whoever implemented, the fixes are new commits, and
  `/crew:review <number>` runs again on the new tip.

If a Status write failed, say so: the comment is on the issue and stands, the line is not
up to date. Do not paste the diff or the whole comment.

## When to really stop

Stop and say why, instead of carrying on, if:

- **step 1**: the issue is closed; a box is empty, or for the mother a child is open or its box is
  not ticked; it is a child on the mother branch, or a mother without its branch;
- **step 2**: there is no branch; the local branch and `origin/<branch>` differ; the tree that has
  the branch is dirty;
- **step 4**: a verification command cannot run on this machine, including a fresh worktree whose
  setup no source names; `git merge-base` fails with anything but 0 or 1;
- **step 5**: the `Skill` tool cannot run `code-review`;
- **step 7**: the branch moved during the review.

Steps 1 and 2 stop before anything is written, so there is nothing to give back. Every stop from
step 3 to step 7 does three things: it puts the Status line back (a fresh `body get` first), it
removes the temporary worktree if it made one, and it writes no comment. A stop at step 2 after
the worktree was added removes it too. Then tell the user what is needed to unblock, and that
`/crew:review <number>` starts again. A red command, a base not contained in the branch and a
finding of `code-review` are not stops: they are findings, and the review ends with its comment.
