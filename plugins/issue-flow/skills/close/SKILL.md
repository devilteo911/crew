---
name: close
description: "Porta in merge request — pull request su GitHub — il lavoro di una issue già implementata: controlla che la roadmap sia davvero tutta spuntata, rifà la verifica sull'albero finale, pusha il branch e apre la MR/PR con Closes #numero. A merge avvenuto chiude la issue e, se è figlia di un /issue-flow:big-plan, la spunta sulla madre. La figlia di un progetto che ha il branch della madre — quello di /issue-flow:big-implement — va in MR/PR verso quel branch e la unisce da sola; la madre va in MR/PR verso il branch di destinazione, che unisce l'utente. Trigger: /issue-flow:close, «apri la merge request della issue N», «chiudi la issue N»."
argument-hint: "<numero> [--chiudi]"
---

# /issue-flow:close

`/issue-flow:implement` lascia un branch con un commit per fase e la roadmap spuntata. Questa
skill lo porta davanti a chi deve leggerlo: una merge request — una pull request, se il
tracker è GitHub — con il corpo che dice cosa cambia e come è stato verificato. Qui sotto
«MR/PR» sta per quella delle due che vale in questo repo; all'utente dici la parola giusta,
non la barra.

**Verso il branch di destinazione la MR/PR si apre e non si merga.** Il merge lo chiede
l'utente, sempre: verso `${user_config.default_branch}` questa skill non esegue `glab mr merge`
né `gh pr merge` in nessun caso, nemmeno se le pipeline sono verdi.

L'unica eccezione è la figlia di un progetto che ha il **branch della madre** — quello che
apre `/issue-flow:big-implement`: la sua MR/PR punta al branch della madre, che è il cantiere
del progetto e non il prodotto, e questa skill la unisce da sola dopo gli stessi controlli di
sempre. Il lavoro arriva al branch di destinazione solo con la MR/PR della madre, e quella la
unisce l'utente.

## Usage

```
/issue-flow:close <numero>            # apre la MR/PR della issue
/issue-flow:close <figlia>            # col branch della madre: MR/PR verso quello, unita e chiusa qui
/issue-flow:close <madre>             # a figlie tutte unite: MR/PR del branch della madre
/issue-flow:close <numero> --chiudi   # a merge avvenuto: chiude la issue e allinea lo Stato
/issue-flow:close                     # deduce il numero dal branch corrente
```

## 0. Quale tracker, e risponde

GitLab (`glab`) o GitHub (`gh`) secondo `git remote get-url origin`; la corrispondenza dei
comandi è in `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` — il file `TRACKER.md` nella cartella di
questo plugin — da leggere prima del primo comando.

```bash
glab auth status && glab issue view <numero>          # GitLab
gh   auth status && gh   issue view <numero>          # GitHub
```

Sul 404, o su «could not determine base repo», vale il rimedio di `TRACKER.md` §2: il remote
è un alias SSH che il CLI non riconosce. Se non sei autenticato, fermati e chiedi all'utente
`glab auth login --hostname gitlab.com` o `gh auth login --hostname github.com`: è
interattivo.

## 0 bis. Quale caso

Rileggi la issue dal server e guarda la testa del corpo. Il caso decide la **base** — il branch
a cui punta la MR/PR — e chi la unisce:

| caso | come lo riconosci | base | merge |
|---|---|---|---|
| **issue** | niente `**Tipo:**` né `**Roadmap:**` | branch di destinazione | l'utente |
| **figlia** | `**Roadmap:** #<madre>`, e il branch della madre **non** è su `origin` | branch di destinazione | l'utente |
| **figlia sul branch della madre** | `**Roadmap:** #<madre>`, e il branch della madre è su `origin` | branch della madre | questa skill, al passo 3 bis |
| **madre** | `**Tipo:** roadmap`, e il branch della madre è su `origin` | branch di destinazione | l'utente |

Il branch di destinazione è `${user_config.default_branch}`, o quello che restituisce
`git symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##'`. Il branch della madre
è `${user_config.branch_prefix}<madre>`, e c'è se:

```bash
git ls-remote --exit-code --heads origin <branch-madre>   # exit 0: c'è
```

Una madre **senza** il suo branch non ha niente da portare in MR/PR: le figlie sono andate una
per una nel branch di destinazione, e la madre si chiude da sola con il `--chiudi` dell'ultima.
Dillo e fermati.

Di' all'utente quale caso hai riconosciuto, prima di proseguire.

## 1. Il lavoro è davvero finito?

Tre controlli, prima di toccare qualsiasi cosa. Se uno fallisce **ti fermi e lo riporti**:
una MR/PR aperta su lavoro incompleto costa più di una non aperta.

**La roadmap è tutta spuntata.** Rileggi la issue dal server e conta. Il conteggio nel corpo
è l'unico che vale su entrambe le piattaforme — `task_completion_status` esiste solo su
GitLab:

```bash
# GitLab
glab issue view <numero> --output json --jq '.description' > "$SCRATCH/roadmap.md"

# GitHub
gh issue view <numero> --json body --jq '.body' > "$SCRATCH/roadmap.md"
sed -i 's/\r$//' "$SCRATCH/roadmap.md"

grep -c '^[[:space:]]*- \[[ xX]\]' "$SCRATCH/roadmap.md"   # totale
grep -c '^[[:space:]]*- \[[xX]\]'  "$SCRATCH/roadmap.md"   # spuntate
grep -n  '^[[:space:]]*- \[ \]'    "$SCRATCH/roadmap.md"   # quelle che restano
```

Per la **madre** le caselle sono quelle della sezione **Issue**, una per figlia, e contano
come le altre: tutte spuntate vuol dire tutte le figlie unite nel branch della madre. Guarda
anche che ogni figlia sia chiusa sul tracker; una casella spuntata su una figlia aperta, o il
contrario, è una madre rimasta indietro da sistemare prima.

Se restano caselle vuote, elencale all'utente e chiedi: o manca lavoro — e allora si torna a
`/issue-flow:implement <numero>` — oppure sono cadute e la riga va riscritta per dire il vero.
Non spuntarle tu per far quadrare il conto.

**Il branch è quello giusto e non ha roba sospesa.** Il branch di lavoro è
`${user_config.branch_prefix}<numero>` — per la madre, il branch della madre stesso; la base è
quella del passo 0 bis.

```bash
git fetch origin
git branch --show-current             # deve essere il branch della issue
git status --porcelain                # deve essere vuoto
git log --oneline origin/<base>..HEAD # i commit delle fasi, uno per fase — per la madre, i
                                      # merge delle figlie con i loro commit
git merge-base --is-ancestor origin/<base> HEAD   # exit 0: il branch contiene la base
```

Se il branch non contiene la base — il branch di destinazione è andato avanti mentre il
progetto era sul branch della madre, o il branch della madre è andato avanti mentre la figlia
lavorava — unisci la base nel branch (`git merge origin/<base>`) e rifai i controlli. Se il
merge ha conflitti, `git merge --abort` e fermati: come risolverli è una decisione, non un
refuso.

Se la working tree è sporca, fermati: quel lavoro non è in nessun commit e non finirebbe
nella MR/PR.

**La verifica passa sull'albero finale.** I singoli commit erano verdi uno per uno; qui conta
il risultato di tutti insieme. Esegui i comandi che la issue elenca nella sua fase di verifica
— o `${user_config.verify_commands}` — e guarda l'output vero, non il riassunto.

Per la **madre** la verifica è quella di tutto il progetto: l'unione dei comandi delle fasi
di verifica delle figlie, o `${user_config.verify_commands}`, eseguiti sull'albero del branch
della madre — è la prima volta che girano tutti insieme.

Poi la prova a mano su ciò che la issue prometteva si dovesse vedere. Se qualcosa è rosso non
apri la MR/PR: lo sistemi con un commit sul branch, oppure ti fermi e lo riporti.

## 2. La documentazione

Prima della MR/PR, non dopo: la documentazione deve descrivere il comportamento nuovo, non
quello vecchio. Rileggi i file che la fase di chiusura della issue nominava — o quelli in
`${user_config.docs_paths}` — e controllali contro il codice che c'è adesso. Se ne manca uno,
aggiornalo e committalo prima di proseguire.

## 3. Apri la MR/PR

```bash
git push -u origin <branch>

# GitLab
glab mr create \
  --related-issue <numero> \
  --source-branch <branch> \
  --target-branch <base> \
  --title "<lo stesso titolo della issue>" \
  --description-file "$SCRATCH/mr.md" \
  --remove-source-branch \
  --yes

# GitHub — niente `--related-issue` né `--remove-source-branch`: il collegamento lo fa il
# `Closes #<numero>` in testa al corpo, e il branch si cancella dopo il merge
gh pr create \
  --head <branch> \
  --base <base> \
  --title "<lo stesso titolo della issue>" \
  --body-file "$SCRATCH/mr.md"
```

Il numero della MR/PR è quello che il comando stampa nell'URL: leggilo da lì. Su GitHub non
sarà quello della issue — issue e pull request condividono la stessa sequenza di numeri.

Per la **figlia sul branch della madre**, `<base>` è il branch della madre: su entrambe le
piattaforme il `Closes #<numero>` agisce solo sul branch di default, quindi la figlia la chiudi
tu al passo 3 bis. Il corpo è lo stesso, con una riga sotto il `Closes`:
`Parte di #<madre> — si unisce in <branch-madre>.`

Il corpo è corto e sta in piedi da solo — la issue ha il piano, la MR/PR ha l'esito. Chi
rivede non deve aprire due pagine per capire cosa sta guardando:

```markdown
Closes #<numero della issue>

## Cosa cambia
[due o tre righe su cosa succede di diverso per chi usa il prodotto, non l'elenco dei file]

## Come è stata verificata
[i comandi eseguiti e cosa hanno stampato davvero, con i numeri; la prova a mano e cosa si è
visto]

## Deviazioni dal piano
[le righe della roadmap riscritte durante l'implementazione, con il perché. «Nessuna» se non
ce ne sono.]
```

Per la **madre** il corpo porta `Closes #<madre>` e, fra «Cosa cambia» e «Come è stata
verificata», una sezione in più:

```markdown
## Figlie
- #21 <titolo> — !40        # su GitHub: — #40
- #22 <titolo> — !41
```

con le MR/PR con cui ogni figlia è entrata nel branch della madre
(`glab mr list --target-branch <branch-madre> --merged`, `gh pr list --base <branch-madre>
--state merged`). «Deviazioni dal piano» raccoglie quelle delle figlie.

I numeri qui dentro sono quelli che hai **letto** al passo 1, non quelli che ti aspettavi:
una MR/PR che dichiara test verdi mai eseguiti è il modo più veloce per far passare un errore.

Poi porta la riga **Stato:** della issue a `in revisione — !<numero MR>` su GitLab, o
`in revisione — #<numero PR>` su GitHub, rileggendo sempre il corpo dal server prima di
riscriverlo, perché l'update sostituisce l'intero campo e non fa merge:

```bash
# GitLab
glab issue view <numero> --output json --jq '.description' > "$SCRATCH/roadmap.md"
# GitHub
gh issue view <numero> --json body --jq '.body' > "$SCRATCH/roadmap.md" && sed -i 's/\r$//' "$SCRATCH/roadmap.md"

# tocchi solo la riga «**Stato:**»

glab issue update <numero> --description-file "$SCRATCH/roadmap.md"   # GitLab
gh   issue edit   <numero> --body-file        "$SCRATCH/roadmap.md"   # GitHub
```

Per la **figlia sul branch della madre** non ti fermi qui: prosegui con il passo 3 bis.
Negli altri casi la skill finisce con la MR/PR aperta, e prosegue quando l'utente torna con
`--chiudi`.

## 3 bis. Il merge nel branch della madre

Solo per la **figlia sul branch della madre**, subito dopo il passo 3, senza chiedere: i
controlli che avrebbe fatto chi rivede li hai fatti ai passi 1 e 2.

**Le pipeline, se ci sono.** Aspetta che finiscano e guarda l'esito:

```bash
# GitLab — `null` se il progetto non ha pipeline sulla MR
glab mr view <mr> --output json --jq '.head_pipeline.status'   # ripeti finché non è success/failed

# GitHub — «no checks reported» vuol dire nessun controllo, ed è verde
gh pr checks <pr> --watch --fail-fast
```

Una pipeline rossa è un «Quando fermarsi davvero», come una verifica rossa al passo 1.

**Il merge**, legato al commit che hai verificato, così non si unisce niente che non hai visto:

```bash
SHA=$(git rev-parse HEAD)

# GitLab — senza `--auto-merge=false` glab rimanda il merge a fine pipeline, e la figlia
# successiva nascerebbe da un branch della madre ancora senza questa
glab mr merge <mr> --sha "$SHA" --auto-merge=false --remove-source-branch --yes

# GitHub — `--merge` tiene i commit delle fasi, con il loro `(#<numero>)`, nella storia del
# branch della madre
gh pr merge <pr> --merge --match-head-commit "$SHA" --delete-branch
```

Poi rileggi lo stato: deve essere `merged`/`MERGED` **adesso**. Se il server l'ha messo in coda
o in auto-merge, o l'ha rifiutato — conflitti, approvazioni obbligatorie, branch protetto —
fermati e riporta cosa dice.

**La chiusura**, senza aspettare `--chiudi`: il passo 4 per intero — la issue chiusa, lo
**Stato:** della figlia a `chiusa — unita in <branch-madre> il GG/MM/AAAA`, il branch di lavoro
cancellato se il server non l'ha già fatto, e la casella spuntata sulla madre come in «La madre,
se la issue è una figlia». In locale torni sul branch della madre, aggiornato:

```bash
git switch <branch-madre> && git pull --ff-only
```

## 4. Dopo il merge — `--chiudi`

Solo quando l'utente dice che la MR/PR è stata unita — o, per la figlia sul branch della madre,
dal passo 3 bis appena il merge è confermato. Verifichi che sia vero, poi chiudi:

```bash
# GitLab — lo stato è minuscolo
glab mr view <numero-o-branch> --output json --jq '.state'    # deve dire "merged"
glab issue close <numero>

# GitHub — lo stato è maiuscolo, e la issue può essere già chiusa dal `Closes #<numero>`
gh pr view <numero-o-branch> --json state --jq '.state'       # deve dire "MERGED"
gh issue view <numero> --json state --jq '.state'             # se è già "CLOSED", non richiuderla
gh issue close <numero>
```

e porti la riga **Stato:** a `chiusa — unita il GG/MM/AAAA`, con la data di oggi — per la
madre, `chiusa — completata il GG/MM/AAAA`. In locale: `git switch <base> && git pull --ff-only`. Il branch di lavoro si cancella solo se il server
non l'ha già fatto: su GitLab lo fa `--remove-source-branch`, su GitHub l'opzione
«Automatically delete head branches» del repo, e se nessuna delle due l'ha tolto,
`git push origin --delete <branch>`.

Se lo stato della MR/PR non è `merged`/`MERGED`, non chiudere niente e dillo.

### La madre, se la issue è una figlia

Se in testa al corpo della issue c'è `**Roadmap:** #<madre>`, la figlia appena chiusa va
spuntata sulla madre: è l'unico posto dove si legge a che punto è il progetto.

```bash
# GitLab
glab issue view <madre> --output json --jq '.description' > "$SCRATCH/madre.md"
# GitHub
gh issue view <madre> --json body --jq '.body' > "$SCRATCH/madre.md" && sed -i 's/\r$//' "$SCRATCH/madre.md"

# giri in `- [x]` SOLO la riga `- [ ] #<numero>` della sezione Issue
# porti la riga «**Stato:**» della madre a `in corso — k di M issue unite`

glab issue update <madre> --description-file "$SCRATCH/madre.md"   # GitLab
gh   issue edit   <madre> --body-file        "$SCRATCH/madre.md"   # GitHub
```

Le regole di sempre: rileggi dal server, controlla che il file non sia vuoto, tocca solo quelle
due righe. La MR/PR della figlia porta `Closes #<figlia>` e **mai** il numero della madre: la
madre non si chiude al merge di una figlia.

Per la **figlia sul branch della madre** lo **Stato:** della madre diventa
`in corso — k di M issue unite in <branch-madre>`, e la madre **non si chiude** nemmeno quando
l'ultima casella è spuntata: il lavoro è nel branch della madre, non ancora nel branch di
destinazione. Nella consegna nomina la figlia successiva — o, se erano tutte, il passo dopo:
`/issue-flow:close <madre>`, che apre la MR/PR della madre.

Per la **figlia** unita direttamente nel branch di destinazione, se dopo la spunta tutte le
caselle della sezione Issue sono `- [x]`, il progetto è finito: porta lo **Stato:** della madre
a `chiusa — completata il GG/MM/AAAA` e chiudila (`glab issue close <madre>`,
`gh issue close <madre>`). Altrimenti, nella consegna, nomina la figlia successiva: la prima
`- [ ] #<n>` rimasta, da cominciare con `/issue-flow:implement <n>` — o
`/issue-flow:implement <madre>`, che la trova da solo.

### La madre

`--chiudi` sulla **madre**, a MR/PR della madre unita: il passo 4 così com'è, con il branch
della madre come branch di lavoro. Le figlie sono già chiuse e spuntate; resta da chiudere la
madre, se il `Closes #<madre>` non l'ha già fatto, e da cancellare il branch della madre.

## 5. Consegna

Il link della MR/PR, cosa hai verificato con i numeri veri, i file di documentazione che hai
dovuto aggiornare, e quello che hai trovato non a posto e hai sistemato per poterla aprire.
Dopo un `--chiudi` su una figlia — o un merge al passo 3 bis — a che punto è la madre
(`k di M issue unite`) e quale figlia viene dopo. Se
ti sei fermato, la ragione in una riga e cosa serve per sbloccare.

## Quando fermarsi davvero

Fermati e chiedi, invece di aprire la MR/PR, se: restano checkbox non spuntate; la working
tree è sporca; una verifica è rossa e la causa non è un refuso evidente; il branch è dietro
la base in modo che unirla porta conflitti da decidere; la issue è già chiusa o ha già una
MR/PR aperta — tranne, per la figlia sul branch della madre, una MR/PR aperta da un giro
interrotto, che si riprende dal passo 3 bis; una pipeline è rossa, o il server non unisce la
MR/PR della figlia nel branch della madre.
