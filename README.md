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

`CREW_DIR` overrides the profiles directory, if you need to try another one.

The two profiles that ship with it: `sottoposto` leads and reviews, `ciurma`
writes the code. The crew talks to itself in English; the sottoposto answers
the user in the user's own language.

## Platforms

macOS uses `osascript` with Terminal.app. On Linux the script tries
`$TERMINAL`, then x-terminal-emulator, gnome-terminal, konsole, kitty,
wezterm, alacritty, xterm. Windows is not supported.
