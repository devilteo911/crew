# crew

Opens a Claude Code session for every profile in `prompts/`, each in its own
terminal window, all in the same working directory.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/devilteo911/crew/main/install.sh | sh
```

Clones the repo into `~/.local/share/crew` (or updates it, if it's already
there) and creates the symlinks. Run the same command again to update. From a
local clone just run `./install.sh`, which uses the clone where it is.

The two symlinks:

- `~/.local/bin/crew` → `bin/crew` (must be on the PATH)
- `~/.claude/crew` → `prompts/`

It also asks — once, and only if VS Code is installed — whether to bind
`cmd+shift+c` (macOS) or `meta+shift+c` (Linux/Windows: Super/Win) to open the
crew in **split integrated terminals** instead of external windows. It writes
the binding only if `keybindings.json` is empty; otherwise it prints the entry
for you to paste. The binding is generated from the profiles present at the
time, so rerun the installer after adding one.

## Usage

```sh
crew           # opens the crew in the current directory
crew ~/project # ...in another directory
```

## Profiles

One `prompts/<name>.md` file = one session. The file name becomes the session
name (`claude -n <name>`, visible in `/resume` and in `ListAgents`), the
contents are appended to the system prompt (`--append-system-prompt-file`).

Adding a member means adding a `.md`: nothing to touch in the script.

An optional `prompts/<name>.model` sets that session's model (`claude --model`):
`sottoposto` runs on `opus`, `ciurma` on `sonnet`. No file, or an empty one,
means Claude's default. A keybinding already in `keybindings.json` is static
text: re-run `install.sh` and paste the entry it prints, or edit it by hand, to
get the model flag.

`CREW_DIR` overrides the profiles directory, if you need to try another one.

The two profiles that ship with it: `sottoposto` leads and reviews, `ciurma`
writes the code. The crew talks to itself in English; the sottoposto answers
the user in the user's own language.

The profiles expect the [issue-flow](plugins/issue-flow/)
plugin: the sottoposto plans the issue, the ciurma implements it, the
sottoposto reviews, and the user decides when to open the PR. It needs a
GitHub or GitLab remote with `gh`/`glab` authenticated. If the plugin is
missing the sottoposto offers to install it; if the user declines, or the repo
has no such tracker, it falls back to a plain plan session.

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

Upstream changes come in with
`git subtree pull --prefix=plugins/issue-flow https://github.com/MatteoSid/Issues-Master-Skills.git main`,
merged with a merge commit, never squashed.

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
