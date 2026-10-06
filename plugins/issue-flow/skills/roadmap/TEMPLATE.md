# TEMPLATE — the ROADMAP.md file

The file that `/issue-flow:roadmap` writes in the repo root when the user chooses to save the
roadmap instead of opening the issues. It is rewritten in full every time: it describes today's
next steps, and the previous versions are in git's history. It is written in English, whatever
language the chat is in.

The sections are these, in this order. The text in square brackets is an instruction for whoever
writes and is not to be copied. The sections marked optional are omitted if they are empty.

---

# Roadmap

**Updated on DD-MM-YYYY** by `/issue-flow:roadmap`[ — focus: <focus>, if there was one].

## Where we are

[Three or four lines: what exists today, what is being done, what the next milestone is.
Every claim with its source.]

**Sources read:** [the list: the documents with their path — for research-flow the official one
with its date, and the registers —, the previous ROADMAP.md if there was one, the open issues
looked at (or "tracker not consulted").]

## Next steps

[In execution order. Each step has the size of an issue, and can be opened with
`/issue-flow:plan` by copying its title and its description.]

### 1. [title: what changes for whoever uses the product]

- **Delivers:** [what exists when the step is done, in one or two lines]
- **Why now:** [the reason for the position, with the sources: `TODO-012`, `ESP-031`,
  `README.md` §Roadmap, `#45`, `path/file.py:88`. **Our proposal** if it does not come from a
  source]
- **After this we know:** [optional: what will be known — the hypothesis that holds or falls,
  the success criterion that gets measured]
- **Depends on:** [the step, a wait, an issue already open, or "nothing"]

### 2. [title]

[…]

## Already open

[Optional. The issues and the mothers already on the tracker that this roadmap leans on, with
the number and what is missing to close them.]

## Waiting on

[Optional. What is not our work but blocks or conditions steps: questions to the sources, data
to accumulate, decisions of someone else. One line each, with the steps that depend on them.]

## After

[Optional. What comes beyond the horizon, one line per entry. After a fork, the two branches:
"if ESP-031 is positive → …; if it is negative → …".]

## Left out

[What the sources list as to do and this roadmap does not contain, with the reason: already
done (and the source to correct), superseded, out of focus, low priority.]

## Inconsistencies found

[Optional. Sources that do not match the code or the tracker: open entries already done,
forgotten issues, documents older than the registers. Each with who has to correct it.]
