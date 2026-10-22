# crew

Opens a Claude Code session for every profile in `prompts/`, each in its own
terminal window, all in the same working directory; a profile with a `.worktree`
file works in its own git worktree of it.

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
turns the update off. When a pull changes the crew plugin's version, `crew`
runs `claude plugin marketplace update crew` and `claude plugin update
crew@crew`; sessions already open need a restart to load it. The first launch
after the plugin's update to 3.0.0 also replaces `issue-flow@crew` with
`crew@crew`, once and on its own; that launch can print one `could not refresh
issue-flow` warning, from the launcher being replaced. A clone older than 0.4.0
has no self-update: run the curl command once more.

The two symlinks:

- `~/.local/bin/crew` → `bin/crew` (must be on the PATH)
- `~/.claude/crew` → `prompts/`

Next it offers the plugins the sessions use, in one menu with all three
selected:

```
crew: plugins for the crew sessions, all selected:
  1) [x] crew         plan and implement through issues    (marketplace crew, this clone)
  2) [x] ponytail     the laziest code that works          (DietrichGebert/ponytail)
  3) [x] caveman      terse prose, fewer tokens            (JuliusBrussee/caveman)
crew: Enter installs the selected; type the numbers to leave out (e.g. "3"):
```

Enter installs all three; `3`, `2 3` or `23` leaves those rows out. Plugins
already installed show `[=]` and `— installed` and are left alone. An old
`issue-flow@issue-flow` is replaced by `crew@crew`, and the `issue-flow`
marketplace is removed so the skills don't show up twice. An installed
`issue-flow@crew` is replaced by `crew@crew` without asking, with or without a
terminal. The menu needs `claude` on the PATH and a terminal, the replacement
only `claude`: rerun the installer once you have them. Open Claude Code
sessions need a restart to load what was installed.

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
means Claude's default. `crew run` reads `<name>.md`, `<name>.model` and
`<name>.worktree` at every start, so terminals and the keybinding pick up a
change at the next launch.

An optional `prompts/<name>.worktree`, an empty file whose contents are ignored,
starts that session in its own git worktree: `.claude/worktrees/<name>` in the
main checkout. It is the folder of `claude --worktree`, where Claude Code does
not ask before each edit, as it does under `.git/`. The first launch fetches for
5 s at most and creates the worktree detached at `origin/HEAD` (at `HEAD` when
there is none), and adds `/.claude/worktrees/` to `.git/info/exclude`. Later
launches reuse it as it is, branch and uncommitted changes included, and a
launch from a subdirectory starts in the same subdirectory of it. Outside a git
repo, or after the one `crew:` warning, the session starts in the current
directory. The worktree has none of the git-ignored files: `/crew:implement`
runs the project's setup there. A branch lives in one checkout at a time, so to
resume in the worktree a branch the main checkout has checked out, switch the
main checkout back to the target branch first. To remove the worktree, run
`git worktree remove .claude/worktrees/<name>` from the main checkout, with
`--force` to drop uncommitted changes; the next launch creates a fresh one. No
shipped profile has the file yet. To try it, point `CREW_DIR` at a copy of
`prompts/` with the file added: an untracked file in the managed clone's
`prompts/` makes its self-update fail once a later version ships the same path.

`CREW_DIR` overrides the profiles directory, if you need to try another one.

The two profiles that ship with it: `sottoposto` leads and reviews, `ciurma`
writes the code. The crew talks to itself in English; the sottoposto answers
the user in the user's own language.

The profiles expect [the crew plugin](plugins/crew/): the sottoposto plans the
issue, the ciurma implements it, the sottoposto reviews, and the user decides
when to open the PR. It needs a
GitHub or GitLab remote with `gh`/`glab` authenticated. The plugin ships in
this repo (`plugins/crew/`, marketplace `crew`, registered from the
clone). If it is missing the sottoposto asks, installs it with `claude plugin`
and asks for a restart; the ciurma does the same for ponytail and caveman. If
the user declines, or the repo has no such tracker, it falls back to a plain
plan session.

## The crew plugin

The plugin lives in `plugins/crew/`. The repo is a Claude Code marketplace
named `crew` (`.claude-plugin/marketplace.json`), so one clone carries the
launcher, the profiles and the plugin.

It is a fork of [Issues-Master-Skills](https://github.com/MatteoSid/Issues-Master-Skills),
imported with its history at upstream commit `2305db3` (`40b9aba`), translated
to English in 2.0.0 and renamed `crew` in 3.0.0. Upstream goes on on its own
(2.2.0, with a different design) and is not tracked: no upstream commit is
merged, and an idea worth having is ported by hand in its own issue.

To install it by hand:

```sh
claude plugin marketplace add ~/.local/share/crew   # or the path of a clone
claude plugin install crew@crew
```

From `issue-flow` to `crew`, what a machine has to do:

```sh
claude plugin marketplace update crew && claude plugin install crew@crew && claude plugin uninstall issue-flow@crew
claude plugin marketplace remove issue-flow   # only if upstream's issue-flow@issue-flow is installed
```

then restart the crew sessions: the commands are now `/crew:*`. A
curl-installed clone replaces `issue-flow@crew` by itself at its next launch;
upstream's `issue-flow@issue-flow` goes only with `./install.sh` or the second
command. A development clone pulls, then runs `./install.sh` or the commands
above. Issues still written with the 1.x markers are no longer read: finish
them before updating.
Options set with `/plugin configure` on `issue-flow@crew` do not move:
`claude plugin configure issue-flow@crew` shows them before the update, and
they are set again on `crew@crew`.

A marketplace registered from a directory, which is what `install.sh` does with
a clone, loads the plugin live from that working tree: `claude plugin list
--json` shows it as `readFromFolder`. A development clone therefore runs the
plugin it is changing, Stop hook included. To work on the plugin, register the
marketplace from GitHub (`claude plugin marketplace add
https://github.com/devilteo911/crew.git`), which changes only with `claude
plugin marketplace update crew`.

A plugin change reaches users only with a version bump in both
`plugins/crew/.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json`.

## Platforms

macOS uses `osascript` with Terminal.app. On Linux the script tries
`$TERMINAL`, then x-terminal-emulator, gnome-terminal, konsole, kitty,
wezterm, alacritty, xterm. Windows is not supported.

## Releases

A release ships by bumping `VERSION` on the branch: merging it to `main` tags
`v<VERSION>` and publishes the GitHub Release. A merge without a bump creates
nothing.

Every push and pull request runs `.github/workflows/check.yml` (shellcheck,
`tests/e2e.sh`, `tests/plugin.sh` and `claude plugin validate --strict`); it must stay green.
