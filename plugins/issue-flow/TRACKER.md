# TRACKER — GitLab o GitHub, e cosa cambia

Le skill di questo plugin — `/issue-flow:roadmap`, `/issue-flow:plan`, `/issue-flow:big-plan`,
`/issue-flow:implement`, `/issue-flow:big-implement`, `/issue-flow:close` — lavorano su un tracker che può essere **GitLab** (`glab`) o **GitHub**
(`gh`). Il piano, la roadmap, le regole di scrittura e il modo di spuntare le caselle non
cambiano: cambiano il comando e due parole. Questo file è il riferimento unico, e le
skill lo citano invece di ripetersi.

## 1. Quale tracker — si deduce, non si chiede

```bash
git remote get-url origin
```

`github` nell'URL → `gh`; `gitlab` → `glab`. Il match sulla stringa regge anche quando il
remote punta a un alias SSH (`git@github.com-lavoro:owner/repo.git`), che è il caso in cui il
CLI da solo non capisce dove si trova.

```bash
case "$(git remote get-url origin)" in
  *github*) TRACKER=gh   ;;
  *gitlab*) TRACKER=glab ;;
  *)        TRACKER=     ;;   # né l'uno né l'altro: fermati e chiedi
esac
command -v "$TRACKER"          # se manca il CLI, fermati: non è installabile in silenzio
```

Due casi in cui **ti fermi e chiedi** invece di indovinare: il remote non è né GitHub né
GitLab (self-hosted con dominio proprio, o nessun remote), e il CLI che servirebbe non è
installato. In quel secondo caso dillo con il rimedio: `gh` si installa da
<https://cli.github.com>, `glab` da <https://gitlab.com/gitlab-org/cli>, poi `auth login`.

Se ci sono più remote e `origin` non è quello del tracker, vale il remote che l'utente indica:
è un caso da chiedere, non da dedurre.

## 2. Il tracker risponde — passo 0 di tutte le skill

| | GitLab | GitHub |
|---|---|---|
| autenticazione | `glab auth status` → «Logged in to gitlab.com» | `gh auth status` → «Logged in to github.com» |
| il repo si risolve | `glab issue list --all` non dà 404 | `gh issue list --state all` non dà errore |
| login (interattivo, **non puoi farlo tu**) | `glab auth login --hostname gitlab.com` | `gh auth login --hostname github.com` |

**Quando il repo non si risolve** è quasi sempre l'alias SSH del remote, che il CLI non
riconosce come host:

- GitLab: `glab config set host gitlab.com` dentro il repo, che scrive in
  `.git/glab-cli/config.yml`;
- GitHub: `gh repo set-default OWNER/REPO` dentro il repo, che scrive `gh-resolved` in
  `.git/config`. In alternativa, per un singolo comando, `GH_REPO=OWNER/REPO gh ...`.

## 3. Il lessico

| concetto | GitLab | GitHub |
|---|---|---|
| il numero della issue | `iid` | `number` |
| ciò che si apre a fine lavoro | merge request (MR) | pull request (PR) |
| come la si cita | `!<numero>` | `#<numero>` |

Nelle skill «MR/PR» sta per «quella delle due che vale qui». Quando scrivi nella issue, sulla
pagina o all'utente, usa **la parola della piattaforma su cui stai lavorando** — non la barra.

Su GitHub issue e pull request **condividono la stessa sequenza di numeri**: la PR aperta per
la issue #12 sarà la #13 o la #40, mai la #12. Non dare per scontato che coincidano e non
costruire il numero della PR: leggilo dall'output di `gh pr create`.

## 4. La corrispondenza dei comandi

Il corpo di una issue passa **sempre da un file**, mai dentro le virgolette della shell.

| cosa | GitLab | GitHub |
|---|---|---|
| elenca tutte le issue | `glab issue list --all --output json` | `gh issue list --state all --limit 500 --json number,title` |
| leggi una issue | `glab issue view <n> --output json` | `gh issue view <n> --json number,title,body,state` |
| solo il corpo | `glab issue view <n> --output json --jq '.description'` | `gh issue view <n> --json body --jq '.body'` |
| crea | `glab issue create --title T --description-file F --yes` | `gh issue create --title T --body-file F` |
| riscrivi il corpo | `glab issue update <n> --description-file F` | `gh issue edit <n> --body-file F` |
| chiudi | `glab issue close <n>` | `gh issue close <n>` |
| apri MR/PR | `glab mr create --source-branch B --target-branch <base> --title T --description-file F --yes` | `gh pr create --head B --base <base> --title T --body-file F` |
| MR/PR che puntano a un branch | `glab mr list --target-branch B` | `gh pr list --base B` |
| cambia il target di una MR/PR | `glab mr update <n> --target-branch <base>` | `gh pr edit <n> --base <base>` |
| stato della MR/PR | `glab mr view <B> --output json --jq '.state'` → `merged` | `gh pr view <B> --json state --jq '.state'` → `MERGED` |
| esito delle pipeline | `glab mr view <n> --output json --jq '.head_pipeline.status'` | `gh pr checks <n> --watch --fail-fast` |
| unisci — **solo** verso il branch della madre | `glab mr merge <n> --sha <SHA> --auto-merge=false --remove-source-branch --yes` | `gh pr merge <n> --merge --match-head-commit <SHA> --delete-branch` |

## 5. Le differenze che mordono

**Il campo del corpo si chiama diversamente.** `description` su GitLab, `body` su GitHub.
È l'errore più facile da fare quando si copia un comando da una skill all'altra: un `jq`
che pesca il campo sbagliato restituisce `null` e si finisce per riscrivere la issue con una
descrizione vuota. Guarda sempre che il file scritto non sia vuoto prima di rimandarlo su.

**`gh issue list` si ferma a 30.** Il default di `--limit` è 30. `glab` pagina a modo suo, e
`--all` lì significa «ogni stato», non «ogni pagina».

**Il conteggio delle caselle esiste solo su GitLab.** `glab issue view --output json` porta
`task_completion_status` (`{count, completed_count}`); `gh` non espone niente di equivalente.
Il metodo che vale su entrambi è contarle nel corpo, ed è quello da usare sempre:

```bash
grep -c '^[[:space:]]*- \[[ xX]\]' "$SCRATCH/roadmap.md"   # totale
grep -c '^[[:space:]]*- \[[xX]\]'  "$SCRATCH/roadmap.md"   # spuntate
grep -n  '^[[:space:]]*- \[ \]'    "$SCRATCH/roadmap.md"   # quelle che restano
```

**Un corpo scritto dalla web di GitHub torna indietro con terminatori CRLF.** I `grep` qui
sopra reggono lo stesso — il pattern non è ancorato a fine riga — ma qualunque espressione che
lo sia (`- \[ \]$`, la riga `**Stato:**`) non trova niente, e i `\r` rimasti rientrano nella
issue quando la riscrivi. Un `sed -i 's/\r$//' "$SCRATCH/roadmap.md"` appena letto il corpo
toglie il problema alla radice, ed è innocuo se i `\r` non ci sono.

**`gh pr create` non ha `--related-issue` né `--remove-source-branch`.** Il collegamento alla
issue si fa **solo** con `Closes #<numero>` come prima riga del corpo — su GitHub chiude la
issue al merge se la PR punta al branch di default del repo. Una MR/PR che punta al branch della
madre, su entrambe le piattaforme, non chiude niente: la figlia la chiude `/issue-flow:close`
subito dopo il merge. La branch, dopo il merge, si
cancella a mano (`git push origin --delete <branch>`) o dall'impostazione «Automatically
delete head branches» del repo: non è compito di queste skill.

**Lo stato della MR/PR ha maiuscole diverse.** `merged` su GitLab, `MERGED` su GitHub —
confronta senza distinzione di maiuscole, o l'esito è sempre «non ancora unita».

**Su GitHub la issue può risultare già chiusa.** Se la PR conteneva `Closes #<n>` ed è stata
unita, GitHub l'ha chiusa da solo. Prima di chiudere, guarda lo stato: se è già `CLOSED`,
resta solo da portare la riga **Stato:** nel corpo. Chiudere una issue già chiusa non è un
errore, ma dire all'utente di averla chiusa tu sì.

**Una checkbox che cita una issue la mostra viva.** Nella madre di `/issue-flow:big-plan` le
righe `- [ ] #13 titolo` sono task list come le altre — si contano con gli stessi `grep` — e in
più entrambe le piattaforme rendono `#13` come link con il titolo e lo stato della issue. Lo
stato mostrato però è quello della issue, non la spunta: la casella la gira solo
`/issue-flow:close --chiudi`, e il conteggio che vale resta quello nel corpo.

**`--yes` è di `glab`.** `gh` non lo ha e non serve: passando `--title` e `--body-file` (e
`--head` per la PR, con la branch già pushata) non chiede niente.
