# Issue Flow

From the request to the merge request, by way of an issue that holds the plan **and** the
roadmap that carries it out. Six skills that hand the work to one another, on **GitLab** (`glab`)
or **GitHub** (`gh`) alike: the platform is deduced from the remote.

The principle that holds it all together: *the issue must be executable by an agent that did not
attend the conversation.* From it follow the verified `file.ts:42` references, the numbers
measured rather than estimated, the decisions written down with their reasons, the explicit
out of scope.

| skill | what it does |
|---|---|
| `/issue-flow:roadmap` | **what do we do now**: reads the project's documentation — the [research-flow](https://github.com/MatteoSid/Research-Master-Skills) registers if there are any, otherwise README, CLAUDE.md, docs — plus the open issues and the code, and proposes the next steps with their sources; once approved, it saves them in `ROADMAP.md` or creates their issues with `big-plan` |
| `/issue-flow:plan` | **one feature**: code reconnaissance, design forks put to the user, then opens the issue with the plan and a checkbox roadmap inside |
| `/issue-flow:big-plan` | **a large development**: defines the project roadmap in a mother issue and splits it into child issues, each written complete by a subagent |
| `/issue-flow:implement` | runs the roadmap one phase per subagent, ticks the boxes as it goes, one commit per phase; works like a `/goal` and does not stop until the roadmap is complete; on a mother issue it takes the first open child |
| `/issue-flow:big-implement` | runs all the children of a mother in one go on the mother's branch: one at a time, in order, each handed to a subagent that goes through `implement` and `close` and merges it into the mother branch on its own; at the end it opens the mother's MR/PR, which you merge |
| `/issue-flow:close` | verifies the final tree, opens the MR/PR, and once merged closes the issue and ticks it on the mother; a child of a project with a mother branch is merged there on its own |

Plus three subagents: `issue-flow:issue-phase`, which runs a single phase and can neither commit
nor touch the issue — the orchestrator does that, after checking the real output —;
`issue-flow:issue-runner`, which for `big-implement` takes a child from its branch to the merge
into the mother branch, orchestrating its phases with one `issue-phase` each, so the main
session's context stays the project's and does not fill up with the phases of every child; and
`issue-flow:issue-writer`, which writes the body of a `big-plan` child issue into a file and
cannot create issues: the orchestrator creates them, in order, after checking them.

## Installation

```
/plugin marketplace add devilteo911/crew
/plugin install issue-flow@crew
```

The `marketplace add` clones with the machine's git credentials, so SSH works too:
`git@github.com:devilteo911/crew.git`. From a local clone it is
`claude plugin marketplace add <path to the clone>`.

`glab` or `gh` must be installed and authenticated — the skills check this at step 0 and stop
with the command to run if it is missing. The login is interactive and Claude cannot do it.
`jq` is also needed, which the `implement` hook uses.

## Configuration

All options are optional: without them, the skills derive what they need from the repo. They are
set when you enable the plugin, or with `claude plugin install --config key=value`.

| option | default | what it is for |
|---|---|---|
| `default_branch` | from the repo | the branch the MRs/PRs are merged into |
| `branch_prefix` | `issue-` | the working branch is `<prefix><issue number>` |
| `verify_commands` | from the project | the commands that must pass before a phase is closed |
| `docs_paths` | from the project | the documentation that the closing phase re-reads |
| `figma_file` | empty | the id of the Figma file to align before the code; empty = no Figma phase |

When `verify_commands` and `docs_paths` are not set, `/issue-flow:plan` derives them during the
reconnaissance — `package.json` scripts, `Makefile` targets, `pyproject.toml`, CI jobs — and
**writes them into the issue**, so the verification phase has real commands instead of a generic
"run the tests". If the project has a `CLAUDE.md`, it usually says them already.

## How to work

To know where to pick up from:

```
/issue-flow:roadmap                  →  proposes the next steps, each with its source
                                        once approved: ROADMAP.md in the root, or
                                        big-plan makes the mother and one child per step
/issue-flow:roadmap the frontend     →  only the steps of one area or milestone
```

`roadmap` reads the research-flow registers when the repo has `.research-flow.json` — the
project's state, the open TODOs, the proposed experiments, the hypotheses to verify — but
research-flow is not a requirement: without it, it relies on a previous `ROADMAP.md`,
`CLAUDE.md`, `README.md`, the `docs_paths` and the open issues. Every step cites the source it
comes from; what the documentation does not say and `roadmap` proposes on its own is marked as
such. The horizon stops at the first fork that depends on an outcome not yet known: beyond it,
the two branches in one line.

For a feature:

```
/issue-flow:plan add a date filter to the list                   →  opens issue #12
/issue-flow:implement 12                                         →  branch issue-12, one commit per phase
/issue-flow:close 12                                             →  opens the MR/PR
/issue-flow:close 12 --merged                                    →  once merged, closes the issue
```

For a development that does not fit in one issue:

```
/issue-flow:big-plan notification system with user preferences   →  mother #20, children #21 #22 #23
/issue-flow:implement 20                                         →  takes the first open child, #21
/issue-flow:close 21                                             →  opens the MR/PR of #21
/issue-flow:close 21 --merged                                    →  closes #21 and ticks it on #20
/issue-flow:implement 20                                         →  now it is #22's turn, and so on
```

The children are run one at a time, each with its own branch and its own MR/PR, and each starts
from the target branch with the previous ones already merged. Or all at once, without waiting
for the merges:

```
/issue-flow:big-implement 20      →  branch issue-20 from main; #21, #22, #23 are born from issue-20
                                     and merge back into it on their own; then the MR/PR issue-20 → main
/issue-flow:close 20 --merged     →  after you have merged the mother's MR/PR: closes #20
```

Every child goes through `close` as usual — verification on the final tree, documentation,
MR/PR — but towards the mother's branch, and there the plugin merges it on its own: it is the
project's worksite, not the product. Only the mother's MR/PR reaches the target branch, and the
plugin never merges that one: you approve it and merge it. You do not need to know in advance
which of the two to use: `/issue-flow:plan` always checks whether the request fits in one issue,
and when it does not it stops, warns with the measured numbers and a draft split, and proposes
how to proceed — switch to `big-plan` (which restarts from the reconnaissance already done),
open only the first issue, narrow the scope, or keep a single issue anyway.

Each one picks up on its own after a `/clear`: the state lives in the issue's checkboxes, not in
the conversation. `/issue-flow:implement` without a number infers it from the current branch.

`/issue-flow:implement` and `/issue-flow:big-implement` do not need `/goal`: they carry a `Stop`
hook (`scripts/goal-stop.sh`) that at every turn end re-reads the issue from the tracker and
sends the work back on as long as the `## Plan` section has an unchecked box or the last phase
is not committed. They stop earlier only for an explicit decision — a phase that failed twice, a
choice the issue did not make — and say so. With `big-implement` the goal covers all the
children of the project and the mother, up to the last merge into the mother branch. The goal's
state lives in `.git/issue-flow/` (the files `goal`, `in-flight` and `blocks`), outside the
commits.

## The three rules the plugin does not negotiate

**Tick as you go.** At the end of each phase, in the same commit that carries it — not when the
work is done. A roadmap that does not say its own state is useless, and one that lies is worse
than no roadmap: if a decision changes, rewrite the line instead of ticking it.

**Re-read the body from the server before rewriting it.** The update replaces the whole field
and does not merge: starting from a copy kept in the conversation wipes the boxes that someone
ticked from the page in the meantime.

**The MR/PR is opened, not merged.** The merge is requested by the user, always — not even with
green pipelines.

## Language

Issue bodies, merge/pull request bodies and `ROADMAP.md` are written in English, whatever language the chat is in. With the user — summaries, questions, AskUserQuestion options, the delivery message — you talk in the language of the current chat.

## 2.0.0

2.0.0 is the English release: every file of the plugin is in English, and so are the markers the
skills write into issues. Renamed: the issue header (`**Status:**`, `**Type:**`,
`**Planned branch:**`, `**Depends on:**`), the section names (`## Goal`, `## Context`, `## Plan`,
`## Out of scope`; for a mother `## Architecture`, `## Decisions`, `## Issues`,
`## How to proceed`), the phase headings (`### Phase N`, `**Done when:**`), the status values
(`to do`, `in progress — phase N of M`, `closed — merged on DD/MM/YYYY`, …), the arguments
(`close <n> --merged`, `plan check <n>`, `plan revise <n>`, `implement <n> --from N`) and two
of the hook's state files (`in-flight`, `blocks`; `goal` keeps its name). The plugin, skill and
agent names do not change. Issues and commands written for 1.x keep working: the Italian markers
and argument spellings are still read and accepted, and `TRACKER.md` §6 has the table with both
forms. The plugin only ever writes the English ones.

## GitLab and GitHub

`TRACKER.md`, in the plugin folder, has the full command mapping and the differences that bite:
the body field that is called `description` here and `body` there, the `--limit` of
`gh issue list` stuck at 30, `task_completion_status` that exists only on GitLab, the CRLFs in
bodies written from GitHub's web UI, `gh pr create` that has no `--related-issue`.

## License

MIT.
