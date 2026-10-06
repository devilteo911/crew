# TEMPLATE — the body of the mother issue

The mother is not implemented: it holds the project's roadmap and the list of the children that
carry it out. The plan with the phases and the working checkboxes lives in the children, which
follow `skills/plan/TEMPLATE.md`.

The title sits outside the body: a short sentence in lowercase that says what the product gains
when the project is finished.

The sections are these, in this order, all mandatory except where stated. The text in square
brackets is an instruction for the writer and must not be copied. Where the template gives two
variants — GitLab and GitHub — you copy only one, the repo's, and use its word (merge request
or pull request) with no slashes.

---

- **Type:** roadmap
- **Status:** to do

## Goal

[Two or three paragraphs. What happens today and why it is not enough, with the reference to the
code that produces that behaviour; what will be true when the last child is merged. It is the
sentence that every child must be able to trace back to itself.]

## Architecture

[How the pieces fit together when the project is finished: the modules touched, the boundaries
between them, the data that passes through. An ASCII diagram if it helps. Name the entry files
with verified `path/file.ts:42`, and the files that will be created with the name they will
have.]

## Decisions

[One entry per decision taken — with the user or on your own — with its reasoning. These are the
choices the children must not reopen: the writer of each child receives them and respects them.]

## Context

[The facts discovered in reconnaissance that hold for several children, one paragraph each with a
**bold title**, as in the `plan` template: the measured numbers, saying where, and the
cross-cutting constraints — data schema, mirrored fields, caches, compatibility with data and
clients already out there — with the why.]

## Issues

[The children in execution order. When the mother is created, the placeholder `#(k)` stands in
place of the number; it becomes `#<number>` when the children are open.]

- [ ] #13 [title] — [what it delivers, in one line]
- [ ] #14 [title] — [what it delivers] · depends on #13
- [ ] #15 [title] — [what it delivers] · depends on #14

## How to proceed

[Mandatory section, copied as is.]

The children are executed **one at a time, in the order above**, each with its own branch and its
own merge request — pull request on GitHub:

```
/issue-flow:implement <child>         # or the number of this issue: takes the first open child
/issue-flow:close <child>             # opens the child's merge request
/issue-flow:close <child> --merged    # once merged: closes the child and ticks it here
```

Or all at once, without waiting for the merges, with `/issue-flow:big-implement <this
issue>`: this issue has its own branch, each child is born from there and goes back in with a
merge request that is merged automatically after the checks of `/issue-flow:close`; at the end
the merge request of this issue carries the whole project into the target branch, and only
whoever approves it merges it. Once merged, `/issue-flow:close <this issue> --merged`.

A box of this issue is ticked **when the child is merged** — into the target branch, or into
this issue's branch — not when it is implemented. The next child starts from there, with the work
of the previous ones in it.

When the last work reaches the target branch — with the last child, or with the merge request of
this issue — this issue is closed, and the **Status:** becomes
`closed — completed on DD/MM/YYYY`. Until then it is `in progress — k of M issues merged`.

If during execution the roadmap stops holding — a decision turns out to be wrong, a child has to
be split or redone — the issues are fixed before the code: this one, re-reading it from the
server before rewriting it, and the children touched with `/issue-flow:plan revise <number>`.

## Out of scope

[Bulleted list of what the project **does not** do, with the why: the natural extensions that
someone might add on their own initiative in one of the children.]
