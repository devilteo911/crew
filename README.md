# crew

Apre una sessione Claude Code per ogni profilo in `prompts/`, ognuna in una
finestra di terminale, tutte nella stessa directory di lavoro.

## Installazione

```sh
./install.sh
```

Crea due symlink:

- `~/.local/bin/crew` → `bin/crew` (deve essere nel PATH)
- `~/.claude/crew` → `prompts/`

## Uso

```sh
crew            # apre la ciurma nella directory corrente
crew ~/progetto # ...in un'altra directory
```

## Profili

Un file `prompts/<nome>.md` = una sessione. Il nome del file diventa il nome
della sessione (`claude -n <nome>`, visibile in `/resume` e in `ListAgents`),
il contenuto viene appeso al system prompt (`--append-system-prompt-file`).

Aggiungere un membro significa aggiungere un `.md`: niente da toccare nello
script.

`CREW_DIR` sovrascrive la cartella dei profili, se serve provarne un'altra.

## Piattaforme

macOS usa `osascript` con Terminal.app. Su Linux lo script prova `$TERMINAL`,
poi x-terminal-emulator, gnome-terminal, konsole, kitty, wezterm, alacritty,
xterm. Windows non è supportato.
