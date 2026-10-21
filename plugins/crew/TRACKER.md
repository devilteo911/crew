# TRACKER — GitLab or GitHub, and what changes

The skills of this plugin — `/issue-flow:roadmap`, `/issue-flow:plan`, `/issue-flow:big-plan`,
`/issue-flow:implement`, `/issue-flow:big-implement`, `/issue-flow:close` — work on a tracker that can be **GitLab** (`glab`) or **GitHub**
(`gh`). The plan, the roadmap, the writing rules and the way boxes get ticked do not
change: the command and two words do. This file is the single reference, and the
skills cite it instead of repeating themselves.

## 1. Which tracker — it is deduced, not asked

```bash
git remote get-url origin
```

`github` in the URL → `gh`; `gitlab` → `glab`. Matching on the string also holds when the
remote points to an SSH alias (`git@github.com-work:owner/repo.git`), which is the case where
the CLI alone cannot tell where it is.

```bash
case "$(git remote get-url origin)" in
  *github*) TRACKER=gh   ;;
  *gitlab*) TRACKER=glab ;;
  *)        TRACKER=     ;;   # neither one: stop and ask
esac
command -v "$TRACKER"          # if the CLI is missing, stop: it cannot be installed silently
```

Two cases where you **stop and ask** instead of guessing: the remote is neither GitHub nor
GitLab (self-hosted with its own domain, or no remote), and the CLI that would be needed is
not installed. In the second case, say so together with the remedy: `gh` is installed from
<https://cli.github.com>, `glab` from <https://gitlab.com/gitlab-org/cli>, then `auth login`.

If there are several remotes and `origin` is not the tracker's, the remote the user names
applies: this is a case to ask about, not to deduce.

## 2. The tracker answers — step 0 of every skill

| | GitLab | GitHub |
|---|---|---|
| authentication | `glab auth status` → "Logged in to gitlab.com" | `gh auth status` → "Logged in to github.com" |
| the repo resolves | `glab issue list --all` gives no 404 | `gh issue list --state all` gives no error |
| login (interactive, **you cannot do it**) | `glab auth login --hostname gitlab.com` | `gh auth login --hostname github.com` |

**When the repo does not resolve**, it is almost always the remote's SSH alias, which the CLI
does not recognise as a host:

- GitLab: `glab config set host gitlab.com` inside the repo, which writes to
  `.git/glab-cli/config.yml`;
- GitHub: `gh repo set-default OWNER/REPO` inside the repo, which writes `gh-resolved` to
  `.git/config`. Alternatively, for a single command, `GH_REPO=OWNER/REPO gh ...`.

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
the PR number: read it from the output of `gh pr create`.

## 4. The command mapping

The body of an issue **always** goes through a file, never inside the shell's quotes.

| what | GitLab | GitHub |
|---|---|---|
| list all issues | `glab issue list --all --output json` | `gh issue list --state all --limit 500 --json number,title` |
| read an issue | `glab issue view <n> --output json` | `gh issue view <n> --json number,title,body,state` |
| the body only | `glab issue view <n> --output json --jq '.description'` | `gh issue view <n> --json body --jq '.body'` |
| create | `glab issue create --title T --description-file F --yes` | `gh issue create --title T --body-file F` |
| rewrite the body | `glab issue update <n> --description-file F` | `gh issue edit <n> --body-file F` |
| close | `glab issue close <n>` | `gh issue close <n>` |
| open an MR/PR | `glab mr create --source-branch B --target-branch <base> --title T --description-file F --yes` | `gh pr create --head B --base <base> --title T --body-file F` |
| MRs/PRs that target a branch | `glab mr list --target-branch B` | `gh pr list --base B` |
| change the target of an MR/PR | `glab mr update <n> --target-branch <base>` | `gh pr edit <n> --base <base>` |
| state of the MR/PR | `glab mr view <B> --output json --jq '.state'` → `merged` | `gh pr view <B> --json state --jq '.state'` → `MERGED` |
| outcome of the pipelines | `glab mr view <n> --output json --jq '.head_pipeline.status'` | `gh pr checks <n> --watch --fail-fast` |
| merge — **only** into the mother's branch | `glab mr merge <n> --sha <SHA> --auto-merge=false --remove-source-branch --yes` | `gh pr merge <n> --merge --match-head-commit <SHA> --delete-branch` |

## 5. The differences that bite

**The body field is named differently.** `description` on GitLab, `body` on GitHub.
It is the easiest mistake to make when copying a command from one skill to another: a `jq`
that picks the wrong field returns `null`, and you end up rewriting the issue with an empty
description. Always check that the written file is not empty before sending it back up.

**`gh issue list` stops at 30.** The default of `--limit` is 30. `glab` paginates in its own
way, and `--all` there means "every state", not "every page".

**The box count exists only on GitLab.** `glab issue view --output json` carries
`task_completion_status` (`{count, completed_count}`); `gh` exposes nothing equivalent.
The method that works on both is to count them in the body, and it is the one to always use:

```bash
grep -c '^[[:space:]]*- \[[ xX]\]' "$SCRATCH/roadmap.md"   # total
grep -c '^[[:space:]]*- \[[xX]\]'  "$SCRATCH/roadmap.md"   # ticked
grep -n  '^[[:space:]]*- \[ \]'    "$SCRATCH/roadmap.md"   # the ones left
```

**A body written from GitHub's web UI comes back with CRLF line endings.** The `grep`s above
still work — the pattern is not anchored to the end of the line — but any expression that
is (`- \[ \]$`, the `**Status:**` line) finds nothing, and the leftover `\r` characters get
back into the issue when you rewrite it. A `sed -i 's/\r$//' "$SCRATCH/roadmap.md"` right
after reading the body removes the problem at the root, and is harmless if the `\r` are not
there.

**`gh pr create` has neither `--related-issue` nor `--remove-source-branch`.** The link to
the issue is made **only** with `Closes #<number>` as the first line of the body — on GitHub
it closes the issue at merge if the PR targets the repo's default branch. An MR/PR that
targets the mother's branch, on both platforms, closes nothing: the child is closed by
`/issue-flow:close` right after the merge. After the merge, the branch is deleted by hand
(`git push origin --delete <branch>`) or by the repo's "Automatically delete head branches"
setting: it is not these skills' job.

**The state of the MR/PR is capitalised differently.** `merged` on GitLab, `MERGED` on
GitHub — compare case-insensitively, or the outcome is always "not merged yet".

**On GitHub the issue may already be closed.** If the PR contained `Closes #<n>` and was
merged, GitHub closed it by itself. Before closing, look at the state: if it is already
`CLOSED`, what is left is to bring the **Status:** line in the body up to date. Closing an
issue that is already closed is not an error, but telling the user that you closed it is.

**A checkbox that cites an issue shows it live.** In the mother of `/issue-flow:big-plan`,
the lines `- [ ] #13 title` are task lists like any other — they are counted with the same
`grep`s — and on top of that both platforms render `#13` as a link with the title and state
of the issue. The state shown, however, is the issue's, not the tick: the box is flipped
only by `/issue-flow:close --merged`, and the count that matters stays the one in the body.

**`--yes` belongs to `glab`.** `gh` does not have it and does not need it: when you pass
`--title` and `--body-file` (and `--head` for the PR, with the branch already pushed) it asks
nothing.

## 6. Markers and arguments — English, 1.x Italian still read

| | 2.x writes | 1.x form, still read / accepted |
|---|---|---|
| header | `- **Status:**` | `- **Stato:**` |
| header (mother) | `- **Type:** roadmap` | `- **Tipo:** roadmap` |
| header | `- **Planned branch:**` | `- **Branch previsto:**` |
| header (child) | `- **Depends on:** #<k>` | `- **Dipende da:** #<k>` |
| header (child) | `- **Roadmap:** #<n>` | same |
| mother's child line | `· depends on #<k>` | `· dipende da #<k>` |
| sections | `## Goal`, `## Context`, `## Plan`, `## Out of scope`, `## How to update this roadmap` | `## Obiettivo`, `## Contesto`, `## Piano`, `## Fuori perimetro`, `## Come si aggiorna questa roadmap` |
| mother sections | `## Architecture`, `## Decisions`, `## Issues`, `## How to proceed` | `## Architettura`, `## Decisioni`, `## Issue`, `## Come si avanza` |
| phases | `### Phase N — <title>`, `**Done when:**` | `### Fase N — <titolo>`, `**Fatto quando:**` |
| arguments | `close <n> --merged`, `plan check <n>`, `plan revise <n>`, `implement <n> --from N` | `--chiudi`, `spunta`, `rivedi`, `--da N` |

The rule: read either form, write only the English one. On a 1.x issue, rewrite the value on the status line that is already there, and never add a second one.
