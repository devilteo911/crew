# crew

Opens a Claude Code session for every profile in `prompts/`, each in its own
terminal window, all in the same working directory.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/devilteo911/crew/main/install.sh | sh
```

Clones the repo into `~/.local/share/crew` (or updates it, if it's already
there) and creates the symlinks. From a local clone just run `./install.sh`,
which uses the clone where it is.

`crew` keeps that clone up to date: at every launch it fetches and
fast-forwards it (offline, diverged or locally changed means one warning and
the launch goes on). Development clones are never touched. `CREW_NO_UPDATE=1`
turns the update off. When a pull changes the issue-flow version, `crew` runs
`claude plugin marketplace update crew` and `claude plugin update
issue-flow@crew`; sessions already open need a restart to load it. A clone
older than 0.4.0 has no self-update: run the curl command once more.

The two symlinks:

- `~/.local/bin/crew` → `bin/crew` (must be on the PATH)
- `~/.claude/crew` → `prompts/`

Next it offers the plugins the sessions use, in one menu with all three
selected:

```
crew: plugins for the crew sessions, all selected:
  1) [x] issue-flow   plan and implement through issues    (marketplace crew, this clone)
  2) [x] ponytail     the laziest code that works          (DietrichGebert/ponytail)
  3) [x] caveman      terse prose, fewer tokens            (JuliusBrussee/caveman)
crew: Enter installs the selected; type the numbers to leave out (e.g. "3"):
```

Enter installs all three; `3`, `2 3` or `23` leaves those rows out. Plugins
already installed show `[=]` and `— installed` and are left alone. An old
`issue-flow@issue-flow` is replaced by `issue-flow@crew`, and the `issue-flow`
marketplace is removed so the skills don't show up twice. The menu is skipped
without `claude` on the PATH or without a terminal: rerun the installer once
you have them. Open Claude Code sessions need a restart to load what was
installed.

It also asks — once, and only if VS Code is installed — whether to bind
`cmd+shift+c` (macOS) or `meta+shift+c` (Linux/Windows: Super/Win) to open the
crew in **split integrated terminals** instead of external windows. The binding
sends `crew run <name>` to each split terminal. The installer writes it into an
empty `keybindings.json` and rewrites an existing crew entry in place, without
asking and keeping its key. It prints the entry when the file has other
bindings and no crew entry, or when the crew entry is not on one line. Adding a
profile still means rerunning the installer.

## Usage

```sh
crew                 # opens the crew in the current directory
crew ~/project       # ...in another directory
crew run sottoposto  # starts one profile in the current directory
```

`run` as the first argument is the subcommand; to open the crew in a directory
named `run`, use `crew ./run`.

## Profiles

One `prompts/<name>.md` file = one session. The file name becomes the session
name (`claude -n <name>`, visible in `/resume` and in `ListAgents`), the
contents are appended to the system prompt (`--append-system-prompt-file`).

Adding a member means adding a `.md`: nothing to touch in the script.

An optional `prompts/<name>.model` sets that session's model (`claude --model`):
`sottoposto` runs on `opus`, `ciurma` on `sonnet`. No file, or an empty one,
means Claude's default. `crew run` reads `<name>.md` and `<name>.model` at
every start, so terminals and the keybinding pick up a change at the next
launch.

`CREW_DIR` overrides the profiles directory, if you need to try another one.

The two profiles that ship with it: `sottoposto` leads and reviews, `ciurma`
writes the code. The crew talks to itself in English; the sottoposto answers
the user in the user's own language.

The profiles expect the [issue-flow](plugins/issue-flow/)
plugin: the sottoposto plans the issue, the ciurma implements it, the
sottoposto reviews, and the user decides when to open the PR. It needs a
GitHub or GitLab remote with `gh`/`glab` authenticated. The plugin ships in
this repo (`plugins/issue-flow/`, marketplace `crew`, registered from the
clone). If it is missing the sottoposto asks, installs it with `claude plugin`
and asks for a restart; the ciurma does the same for ponytail and caveman. If
the user declines, or the repo has no such tracker, it falls back to a plain
plan session.

## issue-flow

issue-flow lives in `plugins/issue-flow/`, imported with its history from
https://github.com/MatteoSid/Issues-Master-Skills. The repo is a Claude Code
marketplace named `crew` (`.claude-plugin/marketplace.json`), so one clone
carries the launcher, the profiles and the plugin.

To install it by hand:

```sh
claude plugin uninstall issue-flow@issue-flow   # only if the old marketplace's copy is installed
claude plugin marketplace add ~/.local/share/crew   # or the path of a clone
claude plugin install issue-flow@crew
```

The uninstall keeps the skills from appearing twice.

A plugin change reaches users only with a version bump in both
`plugins/issue-flow/.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json`.

Upstream [Issues-Master-Skills](https://github.com/MatteoSid/Issues-Master-Skills)
is frozen at the imported commit, and crew is issue-flow's only home from 2.0.0
on: the tree is translated, so Italian upstream commits would conflict on every
file and no longer come in.

## Platforms

macOS uses `osascript` with Terminal.app. On Linux the script tries
`$TERMINAL`, then x-terminal-emulator, gnome-terminal, konsole, kitty,
wezterm, alacritty, xterm. Windows is not supported.

## Releases

A release ships by bumping `VERSION` on the branch: merging it to `main` tags
`v<VERSION>` and publishes the GitHub Release. A merge without a bump creates
nothing.

Every push and pull request runs `.github/workflows/check.yml` (shellcheck and
`claude plugin validate --strict`); it must stay green.
