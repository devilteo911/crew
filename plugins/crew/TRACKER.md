# TRACKER — GitLab or GitHub, and what changes

The skills of this plugin — `/crew:roadmap`, `/crew:plan`, `/crew:big-plan`,
`/crew:implement`, `/crew:big-implement`, `/crew:close` — work on a tracker that can be **GitLab** (`glab`) or **GitHub**
(`gh`). The plan, the roadmap, the writing rules and the way boxes get ticked do not
change: the command and two words do. This file is the single reference for the **vocabulary**
and the **traps**, and the skills cite it instead of repeating themselves.

The commands live in `scripts/tracker.sh`, the only caller of `gh` and `glab`. It deduces the
platform from the remote, hides the differences below, and refuses the calls that would damage
an issue. The skills call it by its full path, `"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh"`, and
in this file `tracker.sh` stands for that path. Claude Code substitutes `${CLAUDE_PLUGIN_ROOT}`
in a skill's own text, not in this file: a subagent that reads this file as a plain one gets the
plugin root in its prompt.

## 1. Which tracker — it is deduced, not asked

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh" kind      # gh | glab, exit 1 when origin is neither
```

`github` in the URL of the `origin` remote → `gh`; `gitlab` → `glab`. Matching on the string
also holds when the remote points to an SSH alias (`git@github.com-work:owner/repo.git`), which
is the case where the CLI alone cannot tell where it is. Every other `tracker.sh` command does
the same deduction first, so no skill repeats it.

Two cases where you **stop and ask** instead of guessing: the remote is neither GitHub nor
GitLab (self-hosted with its own domain, or no remote: `kind` exits 1 and says what it saw), and
the CLI that would be needed is not installed (every command says so, and where to get it). In
the second case, say so together with the remedy: `gh` is installed from
<https://cli.github.com>, `glab` from <https://gitlab.com/gitlab-org/cli>, then `auth login`.

`tracker.sh` reads only `origin`. If there are several remotes and `origin` is not the
tracker's, stop and ask the user: no command can be pointed at another remote.

## 2. The tracker answers — step 0 of every skill

`tracker.sh check` exits 0 and prints `gh ok` or `glab ok` when the CLI is installed,
authenticated and resolves the repo. Otherwise it exits 1 and prints the remedy on stderr. The
remedies are text for the user: **both are interactive or by hand, you cannot run them**. Stop,
and ask the user to run the one `check` printed.

| `check` fails because | GitLab | GitHub |
|---|---|---|
| not authenticated — **interactive, only the user runs it** | `glab auth login --hostname gitlab.com` | `gh auth login --hostname github.com` |
| the repo does not resolve — **by hand, only the user runs it** | `glab config set host gitlab.com` inside the repo, which writes to `.git/glab-cli/config.yml` | `gh repo set-default OWNER/REPO` inside the repo, which writes `gh-resolved` to `.git/config`; for a single command, `GH_REPO=OWNER/REPO` in front of it |

The repo not resolving is almost always the remote's SSH alias, which the CLI does not recognise
as a host.

## 3. The vocabulary

| concept | GitLab | GitHub |
|---|---|---|
| the issue number | `iid` | `number` |
| what you open at the end of the work | merge request (MR) | pull request (PR) |
| how it is cited | `!<number>` | `#<number>` |

In the skills, "MR/PR" stands for "whichever of the two applies here". When you write in the
issue, on the page or to the user, use **the word of the platform you are working on** — not
the slash.

On GitHub, issues and pull requests **share the same sequence of numbers**: the PR opened for
issue #12 will be #13 or #40, never #12. Do not assume they coincide and do not construct
the PR number: read it from the output of `tracker.sh mr create`.

## 4. The commands

The body of an issue **always** goes through a file, never inside the shell's quotes. Every
command is the same on both platforms, and every issue it prints has the same shape:
`{number,title,state,body,updatedAt}`, with `state` `open` or `closed` and the `body` without
CR. A failed CLI call is an error and exit 1, never an empty answer.

| command | what it does | what it prints |
|---|---|---|
| `kind` | which tracker the `origin` remote is | `gh` or `glab`; exit 1 when it is neither |
| `check` | the CLI is installed, authenticated and resolves the repo | `gh ok` or `glab ok`; otherwise the remedy on stderr and exit 1 |
| `view <n>` | reads an issue | the issue, as JSON |
| `state <n>` | the state of an issue | `open` or `closed` |
| `list` | the open issues, every page | an array of issues |
| `body get <n> <file>` | writes the body to `<file>` and the issue's updated timestamp to `<file>.stamp` | nothing; refuses an empty body |
| `body put <n> <file> [--shrink]` | rewrites the whole body from `<file>`, guarded as below, and refreshes the stamp | nothing |
| `create <title> <file>` | opens an issue with `<file>` as body | the new number |
| `close <n>` | closes an issue | `closed`, or `already closed` |
| `comment add <n> <file>` | adds `<file>` as a comment | nothing |
| `comment list <n>` | the comments of an issue, oldest first, without GitLab's system notes | `[{body,createdAt}]` |
| `mr create <issue> <head> <base> <title> <file>` | opens the MR/PR for the issue, with `<file>` as body | the MR/PR number |
| `mr list [--head B] [--base B] [--merged]` | the MR/PRs that match; the open ones, or the merged ones with `--merged` | `[{number,state,head,base,url}]` |
| `mr state <n\|branch>` | the state of an MR/PR | `open`, `merged` or `closed` |
| `mr retarget <n> <base>` | changes the target branch of an MR/PR | nothing |
| `mr checks <n>` | waits for the pipelines to finish | `success` or `none` and exit 0; the failure and exit 1 |
| `mr merge <n> <sha>` | merges the MR/PR, only that commit | nothing; exit 1 unless the MR/PR is `merged` now |

**What `body put` refuses.** It rewrites the whole body, so it checks before it writes:

- an **empty file**: the body would be erased;
- **no `<file>.stamp`**: the file was not read by `body get`, so there is nothing to compare;
- an issue that **changed since `body get`**: its updated timestamp is not the one in the stamp.
  The user ticked a box from the page, or something else wrote to the issue, and a rewrite would
  erase it;
- a file **under half the size of the body**: an edit of a line or two never does that, so
  something cut the text. `--shrink` says that it is meant.

**On a refusal because the issue changed, run `body get` again and redo the change; never remove
the stamp to force it.** There is no force on purpose. A `body put` that succeeds refreshes the
stamp, so the same file can be put again.

**`mr merge` refuses** the MR/PR whose target is the repo's default branch (that merge belongs to
the user), a `<sha>` that is not hexadecimal, and it exits 1 unless the state is `merged` once
it is done.

## 5. The differences that bite

**The body field is named differently.** `description` on GitLab, `body` on GitHub.
It is the easiest mistake to make when copying a command from one platform to the other: a
`jq` that picks the wrong field returns `null`, and you end up rewriting the issue with an empty
description. `tracker.sh` always says `body`, and refuses to write nothing: `body get` refuses
an empty body, `body put` and `create` an empty file.

**`gh issue list` stops at 30.** The default of `--limit` is 30, and `gh pr list` is the same.
`glab` paginates in its own way, and `--all` there means "every state", not "every page".
`list` reads every page on GitLab and up to 1000 issues on GitHub; `mr list` asks for 1000 on
GitHub and one page of 100 on GitLab, which is enough for the MR/PRs of one branch. A skill
never sees the default page of 30 as a whole list.

**The box count exists only on GitLab.** `glab issue view --output json` carries
`task_completion_status` (`{count, completed_count}`); `gh` exposes nothing equivalent.
The method that works on both is to count them in the body, and it is the one to always use:

```bash
grep -c '^[[:space:]]*- \[[ xX]\]' "$SCRATCH/roadmap.md"   # total
grep -c '^[[:space:]]*- \[[xX]\]'  "$SCRATCH/roadmap.md"   # ticked
grep -n  '^[[:space:]]*- \[ \]'    "$SCRATCH/roadmap.md"   # the ones left
```

**A body written from GitHub's web UI comes back with CRLF line endings.** The `grep`s above
would still work — the pattern is not anchored to the end of the line — but any expression that
is (`- \[ \]$`, the `**Status:**` line) would find nothing, and the leftover `\r` characters
would get back into the issue when you rewrite it. `view`, `body get` and `comment list` strip
the CR, so what you edit has none, and nothing is left to remove by hand.

**GitLab's open state is `opened`.** An issue or an MR is `opened` there and `OPEN` on GitHub:
a comparison with `open` finds none on GitLab. `tracker.sh` prints `open` on both.

**The state of the MR/PR is capitalised differently.** `merged` on GitLab, `MERGED` on
GitHub — compared as they come, the outcome is always "not merged yet". `state` and `mr state`
print the states lowercase on both: `open|closed` and `open|merged|closed`.

**`gh pr create` has neither `--related-issue` nor `--remove-source-branch`.** The link to
the issue is made **only** with `Closes #<number>` as the first line of the body — on GitHub
it closes the issue at merge if the PR targets the repo's default branch. `mr create` puts
that line in when the body does not start with it, and on GitLab passes `--related-issue` and
`--remove-source-branch` instead. An MR/PR that targets the mother's branch, on both platforms,
closes nothing: the child is closed by `/crew:close` right after the merge. After a merge into
the default branch, the branch is deleted by hand (`git push origin --delete <branch>`) or by
the repo's "Automatically delete head branches" setting: it is not these skills' job.

**On GitHub the issue may already be closed.** If the PR contained `Closes #<n>` and was
merged, GitHub closed it by itself. `close` looks at the state first: an issue that is already
closed prints `already closed` and nothing is written. Closing an issue that is already closed
is not an error, but telling the user that you closed it is: say what `close` printed.

**`--yes` belongs to `glab`.** `gh` does not have it and does not need it: when you pass
`--title` and `--body-file` (and `--head` for the PR, with the branch already pushed) it asks
nothing. `tracker.sh` passes it where `glab` would otherwise stop to ask.

**`glab issue note` has no file flag.** The text of a comment goes only as `--message`. `comment
add` reads the file and passes its content as that one argument, so a comment cannot be longer
than one command-line argument (about 128 KB on Linux). `gh issue comment` has `--body-file`.

**GitLab's system notes come back among the comments.** Every "changed the description", "closed"
or "mentioned in merge request" is a note with `"system": true`. `comment list` leaves them out;
what it prints is what people wrote.

**Any write moves the issue's timestamp.** A close, `body put`, and very likely a comment too —
that last one is not verified, so assume it does. The guard of `body put` compares the
timestamp with the one `body get` stored, so it fires on **your own** earlier write on the same
issue. The order is: the close or the comment first, **then** `body get`, the edit and
`body put`. On GitHub two writes in the same second carry the same timestamp, and the guard
cannot tell them apart.

**`mr checks` and a project without pipelines.** `gh pr checks` answers "no checks reported"
for a PR with none, and that is green; GitLab has no `head_pipeline` then. Both print `none` and
exit 0. A pipeline still running is waited for; one that fails exits 1.

**`mr merge` on GitLab needs `--auto-merge=false`.** Without it `glab` defers the merge to the
end of the pipeline and returns at once, and the next child would be born from a mother branch
that still lacks this one. `tracker.sh` passes it, and re-reads the state: it exits 1 unless the
MR is `merged` now. If the server queued the merge, set auto-merge or refused it — conflicts,
required approvals, protected branch — the error says what state it found.

**`mr merge` on GitHub keeps the phases' commits.** It merges with `--merge`, so the commits,
with their `(#<number>)`, stay in the history of the mother branch, and with `--match-head-commit`
so that only the commit you verified is merged.

**A checkbox that cites an issue shows it live.** In the mother of `/crew:big-plan`,
the lines `- [ ] #13 title` are task lists like any other — they are counted with the same
`grep`s — and on top of that both platforms render `#13` as a link with the title and state
of the issue. The state shown, however, is the issue's, not the tick: the box is flipped
only by `/crew:close --merged`, and the count that matters stays the one in the body.

## 6. Markers and arguments

| | Marker |
|---|---|
| header | `- **Status:**` |
| header (mother) | `- **Type:** roadmap` |
| header | `- **Planned branch:**` |
| header (child) | `- **Depends on:** #<k>` |
| header (child) | `- **Roadmap:** #<n>` |
| mother's child line | `· depends on #<k>` |
| sections | `## Goal`, `## Context`, `## Plan`, `## Out of scope`, `## How to update this roadmap` |
| mother sections | `## Architecture`, `## Decisions`, `## Issues`, `## How to proceed` |
| phases | `### Phase N — <title>`, `**Done when:**` |
| arguments | `close <n> --merged`, `plan check <n>`, `plan revise <n>`, `implement <n> --from N` |

The skills write and read only these. An issue written with other markers is not recognised: rewrite it with these by hand.
