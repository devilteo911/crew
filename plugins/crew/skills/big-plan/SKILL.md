---
name: big-plan
description: "Turns a large development — more than fits in one issue — into a project roadmap on the repo's tracker, GitLab or GitHub: a mother issue with goal, architecture and decisions, and the child issues that carry it out in sequence, each complete with plan and checkboxes and written by a dedicated subagent. Trigger: /issue-flow:big-plan, 'plan the project…', 'split into issues…', 'make the roadmap of…'."
argument-hint: "<description of the development>"
---

# /issue-flow:big-plan

`/issue-flow:plan` is for **one** feature: one issue, 5 to 8 phases, one merge request. When the
development does not fit — a new subsystem, a migration in several stages, a feature that
crosses backend, data and interface — this skill turns it into a **project**: a mother issue
that holds the overall roadmap, and the child issues that carry it out one at a time, each
with its own branch and its own MR/PR.

Everything `plan` says holds here too, and is not repeated: `${CLAUDE_PLUGIN_ROOT}/skills/plan/SKILL.md`
— the `plan` skill of this plugin — for the principle ("the issue must be executable by an
agent that did not attend the conversation"), the host project, the reconnaissance, the phases,
the checkboxes, how boxes get ticked and how to write. `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` for the
commands of the two platforms and their traps. **Read both before the first command.**

## Usage

```
/issue-flow:big-plan <description of the development>   # from the request to the mother and the children
/issue-flow:big-plan                                    # uses a roadmap already approved in the conversation
```

### When you arrive from `/issue-flow:plan`

`plan` always checks whether the request fits in one issue, and when it does not it warns the
user and proposes switching here. If the user accepts, this skill is loaded in the same
conversation, and some work is already done: the tracker verified, the reconnaissance up to
the point where `plan` stopped, a draft split into issues that the user has seen.

Do not redo it. Skip step 0, **complete** the reconnaissance of step 2 only where it is not
enough for a roadmap — typically the overall architecture and the cross-cutting constraints,
because `plan` was looking closely at the first piece — and at step 3 start from the draft of
`plan` instead of from zero: correct it where the complete reconnaissance requires, and in the
summary of step 4 say what changed from the draft the user had seen.

### When you arrive from `/issue-flow:roadmap`

`roadmap` proposes the project's next steps by reading its documentation, and when the user
chooses "Create the issues" it loads this skill in the same conversation. Here too some work is
done: the tracker verified, the sources read, a roadmap **approved** by the user, with one step
per child, each step's sources and the dependencies.

Skip step 0. The reconnaissance of step 2 must still be done, though: `roadmap` looked at
**what** to do, not **how** — the architecture touched and the cross-cutting constraints between
the steps are missing. At step 3 the roadmap's steps are the children: the roadmap's goal becomes
the mother's **Goal**, its **Waiting on**, **After** and **Left out** go into the **Context** and
the **Out of scope**, and the sources of each step (register IDs, document sections, issues)
are passed to the writer of its child, who cites them in the Context.

If the reconnaissance does not change the split, the roadmap is already approved: skip the
summary and the question of step 4 and go to step 5. If it does change it — a step has to be
split, two have to be merged, a dependency does not hold — step 4 is done, and the summary says
what changed from the approved roadmap and why.

In the delivery of step 9, if the roadmap came from the research-flow registers, add the
mapping between children and entries (`#21 ← TODO-012, ESP-031`) and propose
`/research-flow:annota` to mark them `in corso` with their issue: the registers are written by
research-flow, not by this skill.

## You are the orchestrator

You define the roadmap, take the decisions with the user, open the mother, **delegate** the
writing of each child to a subagent, and then check and create everything on the tracker. You do
not write the children's bodies yourself.

The reason is the same as for `/issue-flow:implement`: each child requires its own reconnaissance
in the code — files really read, lines verified, numbers measured — and done all in here it
would fill the context until you lose the overall view, which is the only thing that only you
have. The subagent starts clean, reads only what its issue needs, and hands you a body to check.

## Process

### 0. Which tracker, and does it answer

Identical to step 0 of `plan`: `git remote get-url origin`, then `glab auth status` or
`gh auth status` and an `issue list` that answers. If authentication is missing, stop and ask
the user to do it: it is interactive.

### 1. Work like in plan mode, without entering it

The same rules as step 1 of `plan`: **never `EnterPlanMode` or `ExitPlanMode`**, read-only
until the mother is opened, forks asked as you go with `AskUserQuestion`, approval with
`AskUserQuestion` and not with `ExitPlanMode`, and **never offer to implement**.

### 2. Overall reconnaissance — not skippable

Wider than the one in `plan`, less deep: here you do not yet need every `file:line` of each
phase — the writer of each child finds those — but you need to know how the part of the system
that the development crosses is built.

- **the architecture touched**: which modules, services, packages; where the boundaries between
  them run; who calls whom. Read the entry files, do not infer them from the names;
- **the cross-cutting constraints**, the ones that hold for several children and that none of them
  alone would see: the data schema and its migrations, the mirrored fields between backend and
  frontend, the caches, the clients already out there, backward compatibility;
- **the measured numbers** that size the work: how many lines, how many callers, how many
  records, how many endpoints;
- the host project as in `plan`: target branch, verification commands, documentation to keep
  aligned. Derive them once here and pass them to all the writers.

### 3. The decomposition

This is the work this skill does and `plan` does not. The rules:

- **an issue is an increment that merges on its own.** After the merge of each child the product
  compiles, the tests pass and nothing that worked has broken. No "half the backend" issue that
  leaves the target branch broken until its sibling arrives: if two pieces cannot stand
  separately, they are a single issue, or the first goes behind a flag;
- **each child fits in the 5–8 phases of `plan`**, verification and closing included. If one
  does not fit, it has to be split; if two together fit comfortably, they have to be merged;
- **the order is explicit and the dependencies are declared.** Execution is sequential, so the
  chain is normally linear: child N starts from the code that the children before it have merged.
  Put first what removes uncertainty — the data model, the interface between two modules — and
  after it what relies on it;
- **for each child**: a title that says what changes for whoever uses the product, what it
  delivers, what it leaves to the later ones (types, interfaces, endpoints, files that will be
  created — with the name they will have), what stays out.

If the decomposition gives **a single** issue, the development is not big: say so and propose
`/issue-flow:plan`, instead of opening a mother with a single child.

### 4. Present the roadmap and get it approved

Once the forks are closed, write a summary in chat: the goal, the architecture in a few lines,
the cross-cutting constraints found, the decisions taken on your own with their reasons, and the
list of children — one line each, with what it delivers and what it depends on. Then
`AskUserQuestion` with three options: "Open the issues" (Recommended), "Change something" (the
user says what, you fix it and ask again), "Leave it" (you open nothing and stop).

If the roadmap was already approved in this conversation — or it is `/issue-flow:big-plan` with no
arguments — skip the summary and the question and go to step 5.

### 5. Open the mother

Follow `TEMPLATE.md`, the file next to this one. The **Issues** section at this point has the
lines with a placeholder in place of the number — `- [ ] #(1) title — what it delivers` — because
the children do not exist yet; you put the number in at step 8. The mother is opened first because
the children must be able to cite it from the very first moment.

```bash
glab issue create --title "<title>" --description-file "$SCRATCH/mother.md" --yes   # GitLab
gh   issue create --title "<title>" --body-file        "$SCRATCH/mother.md"         # GitHub
```

The mother's title says what the product gains when the project is finished, as for every issue.
You read the number from the URL the command prints.

### 6. Write the children, one subagent per child

One invocation of the `Agent` tool with `subagent_type: "issue-flow:issue-writer"` **for each
child**. The writers read the code and write a file in the scratchpad, nothing more: they do not
step on each other's toes, so **launch them all together, in a single message**.

The writer did not see the conversation: **what you do not write to it does not exist**. In the
prompt, in full and not summarised:

- the number of the mother and its **Goal**, **Architecture**, **Decisions**, **Context** and
  **Out of scope** sections;
- the complete list of the children, with the placeholder `#(k)`, the title and what each one
  delivers: the writer must know what its siblings do so as not to redo it and to say so in its
  out of scope;
- the position of its child — `#(3)`, third of 5 — and **what it will find already done** when
  its turn comes: the types, the interfaces, the files that the children before it will have
  created, with the names decided;
- the target branch, the verification commands and the documentation files derived at step 2;
- if `${user_config.figma_file}` is configured, the file id: the child that touches the frontend
  will have the Figma phase first;
- the exact path of the file to write the body in: `$SCRATCH/child-<k>.md`.

### 7. Check the bodies

When the writers return, re-read **every** file — a subagent's report is a story, the file is the
proof:

- it is not empty, and it has all the sections of the `plan` template, including "How to update
  this roadmap" in the right platform variant;
- at the top it has `- **Roadmap:** #<mother>` and, if it has any, the `- **Depends on:** #(k)`
  lines;
- the phases are 5 to 8, with verification second to last and closing last; the checkboxes are
  counted with the `grep`s of `TRACKER.md` §5;
- it does not do the work of a sibling, and it does not contradict the mother's decisions.

If a writer reported a constraint that the roadmap did not foresee, **you decide** — with the
user, if it changes the decomposition — and do not leave it silently resolved inside a child.
If a body does not hold up, a **new** writer with the defect spelled out in full; never fix by
hand pieces of reconnaissance that you did not do.

### 8. Create the children and align the references

Create the children **in the roadmap's order**, one at a time, so the numbers grow with the
execution order. The title is the one in the roadmap; you read the number from the printed URL,
you do not deduce it — on GitHub issues and pull requests share the sequence, and someone else
may open an issue in the meantime.

Then the placeholders become numbers:

- in every child that cites a sibling — `**Depends on:** #(2)`, "created in #(2)", the out of
  scope — `#(k)` becomes `#<number>`;
- in the mother, the **Issues** section becomes `- [ ] #<number> title — what it delivers`.

Every rewrite follows the usual rule: **re-read the body from the server**, replace, check that
the file is not empty, send it back up (`TRACKER.md` §4). At the end, a `grep -n '#([0-9]\+)'` on
every re-read body must find no placeholders left.

### 9. Delivery

In a few lines: the mother's link, the list of children with number, title and link in
execution order, what you found in reconnaissance that the request did not foresee, the decisions
taken on your own with their reasons, and what was left out. Close with how to start:
`/issue-flow:implement <mother>`, which takes the first open child on its own, or
`/issue-flow:big-implement <mother>`, which carries them all forward in sequence. Do not paste the
issues in the reply.

## How to proceed in the project

Not with this skill. The children are executed **one at a time, in order**, with the normal round:

```
/issue-flow:implement <child>            # or <mother>: takes the first child not yet merged
/issue-flow:close <child>                # opens the child's MR/PR
/issue-flow:close <child> --merged       # once merged: closes the child and ticks it on the mother
```

and then the next child, which starts from the target branch with the work of the previous ones
in it. The mother's box is ticked **when the child is merged**, not when it is implemented:
`/issue-flow:close --merged` does it, and it closes the mother too when the last box is
ticked. The 1.x spellings of the renamed arguments are still accepted (`TRACKER.md` §6).

Or all at once with `/issue-flow:big-implement <mother>`: the same round, one child at a time,
on the mother branch — each child is born from there and goes back in with its MR/PR, which
`close` merges on its own after the usual checks. At the end the mother's MR/PR carries
everything into the target branch, and the user merges it; then `/issue-flow:close <mother> --merged`.

If during execution a child discovers that the roadmap no longer holds — a decision of the
mother turns out to be wrong, a later child has to be redone — the remedy is to fix the issues
before the code: `/issue-flow:plan revise <n>` for the child, and the mother rewritten by hand
with the usual rule.
