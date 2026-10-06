# TEMPLATE — the body of an issue

The title sits outside the body: a short sentence in lowercase that says what changes for
whoever uses the product.

The sections are these, in this order, all mandatory except where stated. The text
in square brackets is an instruction for the writer and must not be copied.

The issue lives on **one** platform: where the template gives two variants — GitLab and GitHub —
you copy only one, the repo's, and use its word (merge request or pull request) with no
slashes. Which one it is, `TRACKER.md` says.

---

- **Status:** to do
- **Planned branch:** `issue-<number>`
- **Roadmap:** #<mother>   [only for children of `/issue-flow:big-plan`]
- **Depends on:** #<number>            [only for children, one line per sibling it depends on]

## Goal

[Two or three paragraphs. The first says what happens today and why it is not enough — concrete,
with the reference to the code that produces that behaviour. The last says, in a single sentence,
what will happen afterwards. No list of files: that comes later.]

## Context

[The part that makes the issue executable by someone who did not attend the conversation. These are
paragraphs, each with a **bold title**, one per fact discovered in reconnaissance.
These go in, when they exist:]

**How much material there is.** [The measured numbers, saying where: "847 lines in `src/store.ts`",
"the function has 23 callers", "coverage on existing records: 886 of 886".]

**What is already there and we are not using.** [Fields that reach the interface and are not
shown, data computed and then thrown away. It is almost always the part that reduces the work.]

**The non-obvious technical constraint.** [The type a serialization does not digest, the cache that
would be invalidated, the import that would create a cycle, the mirrored field between backend and frontend
that must be changed together. With the why, not just the what.]

**Compatibility with what already exists.** [Which data, cached responses or old clients
must keep working, and what they will show.]

**What stays as it is, and why.** [The adjacent code one is tempted to fix and that
this issue does not touch — with the reason it does not touch it.]

## Plan

[The phases. Each one is a `###`, with a title that says what it does, and under it: a line naming the
touched files, then the checkboxes. The mandatory phases — verification second to last, closing last,
and the Figma first if the project has one configured — are described in `SKILL.md`.]

### Phase 1 — [title]

`path/to/file.ts`.

- [ ] [atomic, imperative checkboxes that name file and line]

**Done when:** [the observation that proves the phase is finished.]

[...the other phases...]

### Phase N-1 — Verification

- [ ] [the new tests, described by what they must prove, not by what they are called]
- [ ] [the project's verification commands, one per checkbox, saying which outcome is
      expected: "`npm test` green, the 214 tests from before still pass"]
- [ ] [the manual check: what to open, what to do, what must be seen — concretely]
- [ ] [if it touches the interface: from the keyboard, at 390 width, clean accessibility]
- [ ] [if there is old data or clients: one of them is re-read without errors]

### Phase N — Closing

- [ ] `<documentation file>`: [what must be rewritten, not "update the docs"]
- [ ] commit on the issue's branch

[The MR/PR does not go among the checkboxes: `/issue-flow:close <number>` opens it after the last
phase, and it is not merged — the user asks for the merge.]

## How to update this roadmap

[Mandatory section, copied as is.]

The boxes above can be ticked: the tracker counts them and shows the progress at the top
of the issue. **Tick them as you go**, at the end of each piece of work and not when everything
is done, in the same commit that carries that piece. Whoever picks the issue up must be able to
tell from the state of the boxes where it stands, without asking anyone.

If a decision changes during implementation, rewrite the roadmap line instead
of just ticking it: a roadmap that lies is worse than no roadmap.

From the command line, always re-reading the version on the server before rewriting it — the update
replaces the whole body and does not merge:

[Copy only the block for this repo's platform.]

```bash
# GitLab
glab issue view <number> --output json --jq '.description' > roadmap.md
glab issue update <number> --description-file roadmap.md
```

```bash
# GitHub
gh issue view <number> --json body --jq '.body' > roadmap.md
sed -i 's/\r$//' roadmap.md
gh issue edit <number> --body-file roadmap.md
```

When the work is done: all the boxes ticked, then `/issue-flow:close <number>` opens the merge
request — the pull request on GitHub — and sets **Status:** to `in review — !<MR number>` on
GitLab, `in review — #<PR number>` on GitHub. After the merge,
`glab issue close <number>` or `gh issue close <number>`, and **Status:** becomes
`closed — merged on DD/MM/YYYY`. On GitHub the issue may have already closed by itself: the PR carries
`Closes #<number>` and the merge closes it.

## Out of scope

[Bulleted list of what this issue **does not** do, with the why. It especially includes the
things that would be little work and that someone might add on their own initiative: saying them
here is the way not to find them implemented.]
