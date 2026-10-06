---
name: implement
description: "Prende una issue dal tracker del repo — GitLab o GitHub — e ne implementa la roadmap: una fase per subagent, le checkbox spuntate sulla issue mano a mano che il lavoro si chiude, un commit per fase. Si ferma al commit dell'ultima fase: la merge request la apre /issue-flow:close. Con il numero di una issue madre di /issue-flow:big-plan esegue la prima figlia non ancora unita. Trigger: /issue-flow:implement, «implementa la issue N», «porta a termine la issue N», «lavora la issue N»."
argument-hint: "<numero> [--da N]"
hooks:
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/goal-stop.sh"
---

# /issue-flow:implement

`/issue-flow:plan` scrive l'istruzione di lavoro, questa la esegue. Tutto quello che serve sta
nella issue: piano, contesto, roadmap. Non si aggiunge lavoro che la issue non prevede e non
si salta lavoro che prevede.

## Usage

```
/issue-flow:implement <numero>         # esegue la issue dalla prima fase non spuntata
/issue-flow:implement <madre>          # issue madre di big-plan: esegue la prima figlia aperta
/issue-flow:implement <numero> --da 3  # riparte dalla fase 3, ignorando le checkbox
/issue-flow:implement                  # deduce il numero dal branch corrente
```

## Tu sei l'orchestratore e resti tale

Non implementi le fasi: le assegni, ne verifichi l'esito, spunti le caselle e committi.

Il motivo è il contesto. Ogni fase parte da un subagent pulito che legge solo i file che le
servono, mentre tu tieni la visione dell'insieme — a che punto è la roadmap, cosa ha deciso
la fase precedente, cosa manca — senza riempirti dei dettagli di ogni singolo file.

Con `/issue-flow:big-implement` questo stesso ciclo scende di un livello: lo esegue per ogni
figlia un subagent `issue-flow:issue-runner`, che legge questa skill come riferimento e lascia
il goal alla sessione principale.

## Lavori in modalità goal

Questa skill si comporta come un `/goal` con la condizione già scritta: **non si ferma finché
la roadmap non è completa**. Lo fa un hook `Stop` del plugin (`scripts/goal-stop.sh`) che a
ogni fine turno rilegge la issue dal tracker: finché nel Piano c'è una `- [ ]`, o l'ultima
fase non è committata, ti rimanda al lavoro dicendoti da quale fase ripartire.

L'hook legge lo stato da una cartella dentro `.git`, che non finisce mai in un commit:

```bash
GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow)
```

- `$GOAL_DIR/goal` — il numero della issue in lavorazione. Lo scrivi al passo 2; a roadmap
  completa lo cancella l'hook. Finché c'è, il turno non si chiude.
- `$GOAL_DIR/in-volo` — c'è un subagent di fase al lavoro. Lo crei subito prima di delegare
  e lo cancelli appena torna: in mezzo puoi chiudere il turno, perché ti risveglia la sua
  notifica.

Per fermarti prima della fine — i casi di «Quando fermarsi davvero», o una checkbox che resta
vuota — **cancelli tu `$GOAL_DIR/goal`** e dici all'utente perché. È voluto: lo stop è una
decisione esplicita, non un turno che finisce per caso a metà roadmap. Se ti fermi prima del
passo 2, il file non esiste ancora e non c'è niente da cancellare.

## 0. Quale tracker, e risponde

Il tracker è GitLab (`glab`) o GitHub (`gh`) secondo il remote: `git remote get-url origin`.
La corrispondenza completa dei comandi sta in `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` — il file
`TRACKER.md` nella cartella di questo plugin — da leggere prima del primo comando, perché il
campo del corpo cambia nome fra le due piattaforme e sbagliarlo svuota la issue.

```bash
glab auth status && glab issue view <numero>          # GitLab
gh   auth status && gh   issue view <numero>          # GitHub
```

Deve mostrare la issue, non un 404. Se dà 404 o «could not determine base repo» il remote è
un alias SSH e il rimedio è in `TRACKER.md` §2. Se non sei autenticato, fermati e chiedi
all'utente `glab auth login --hostname gitlab.com` o `gh auth login --hostname github.com`:
è interattivo, non puoi farlo tu.

## 1. Leggi la issue, per intero, dal server

```bash
# GitLab
glab issue view <numero> --output json > "$SCRATCH/issue.json"
jq -r '.title'       "$SCRATCH/issue.json"
jq -r '.description' "$SCRATCH/issue.json" > "$SCRATCH/roadmap.md"

# GitHub
gh issue view <numero> --json title,body > "$SCRATCH/issue.json"
jq -r '.title' "$SCRATCH/issue.json"
jq -r '.body'  "$SCRATCH/issue.json" | sed 's/\r$//' > "$SCRATCH/roadmap.md"
```

Controlla che `roadmap.md` non sia vuoto prima di andare avanti: se lo è, hai pescato il
campo dell'altra piattaforma.

Se in testa al corpo c'è `**Tipo:** roadmap`, è la madre di un `/issue-flow:big-plan` e non
si implementa: vai al passo 1 bis. Se c'è `**Roadmap:** #<madre>`, è una figlia: vale tutto
quello che segue, più il passo 1 ter prima del branch.

Leggila tutta, non solo il Piano: **Obiettivo**, **Contesto** e **Fuori perimetro** sono ciò
che impedisce ai subagent di reinventare le decisioni già prese, e vanno passati loro.

Poi ricava, e dillo all'utente prima di partire:

- il branch di lavoro, `${user_config.branch_prefix}<numero>` — con il default `issue-`, la
  issue #12 si lavora su `issue-12`;
- l'elenco delle fasi (`###` dentro `## Piano`) con quante checkbox hanno e quante sono già
  spuntate, e da quale fase riparti;
- se la issue non ha fasi con checkbox, **fermati**: non è una issue eseguibile. Riportalo e
  proponi `/issue-flow:plan rivedi <numero>`.

## 1 bis. La madre: quale figlia tocca

Le figlie si eseguono **una alla volta, in ordine**. Nella sezione **Issue** della madre, la
prima riga `- [ ] #<n>` non spuntata è la figlia da eseguire:

```bash
grep -n '^[[:space:]]*- \[ \] #[0-9]' "$SCRATCH/roadmap.md" | head -1
```

Prima di prenderla, guarda che le figlie da cui dipende — la riga `· dipende da #<k>` nella
madre, `**Dipende da:**` nella figlia — siano **chiuse** sul tracker
(`glab issue view <k> --output json --jq '.state'` → `closed`, `gh issue view <k> --json state
--jq '.state'` → `CLOSED`). Una figlia con una dipendenza ancora aperta non si comincia: dillo
all'utente e indica quale va chiusa prima — di solito è una MR/PR in attesa di merge.

Se tutte le caselle della madre sono spuntate, il progetto è finito: dillo, e se la madre è
ancora aperta proponi di chiuderla. Se una casella è vuota ma la figlia è già chiusa sul
tracker, la madre è rimasta indietro: segnalalo invece di rieseguire la figlia.

Poi dì all'utente «procedo con #<n> — <titolo>» e ricomincia dal passo 1 con il numero della
figlia. **Mai due figlie nella stessa esecuzione**: ognuna ha il suo branch e la sua MR/PR, e la
successiva parte dal codice che questa avrà unito.

Per portare avanti tutte le figlie in una volta sola, senza aspettare i merge, c'è
`/issue-flow:big-implement <madre>`: stessa esecuzione, una figlia alla volta, sul branch della
madre — ogni figlia ci entra da sola, e al branch di destinazione arriva solo la MR/PR della
madre.

## 1 ter. La figlia regge ancora?

Una figlia è stata scritta prima che le sorelle da cui dipende fossero implementate: i suoi
`file:riga` e i punti d'aggancio marcati «nasce con #<k>» descrivevano un codice che adesso è
diverso. Prima di delegare la prima fase, controlla:

- le dipendenze sono **chiuse** sul tracker e il loro lavoro è **nella base** del passo 2
  (`git log --oneline <base> | grep '#<k>'`, o i file che dovevano far nascere esistono);
- i punti d'aggancio «nasce con #<k>» esistono davvero, con il nome che la figlia si aspetta;
- i `file:riga` della prima fase puntano ancora a quello che la issue descrive.

Se qualcosa non regge in modo sostanziale — un file che non esiste, un'interfaccia nata con
un'altra forma, una decisione che la sorella ha cambiato in corsa — **fermati** e proponi
`/issue-flow:plan rivedi <numero>`. Le righe solo spostate di qualche posizione non sono un
motivo per fermarsi: il subagent le riverifica comunque. Il rimedio giusto è correggere la
issue prima del codice.

## 2. Il branch

Il lavoro non tocca mai il branch di destinazione — `${user_config.default_branch}`, o quello
che restituisce `git symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##'`.

```bash
git status --porcelain                # deve essere vuoto: un commit per fase ha senso
                                      # solo se il commit contiene la fase e nient'altro
git switch <branch> 2>/dev/null \
  || { git switch <base> && git pull --ff-only && git switch -c <branch>; }
```

Se ci sono modifiche non committate, fermati e chiedi cosa farne.

Sul branch giusto, attiva il goal — con il numero della issue che stai eseguendo, che per una
madre è quello della figlia:

```bash
mkdir -p "$GOAL_DIR" && echo <numero> > "$GOAL_DIR/goal" && rm -f "$GOAL_DIR/in-volo"
```

Il `rm` toglie un `in-volo` rimasto da una sessione interrotta, che altrimenti lascerebbe il
goal sempre spento.

Per una figlia di un big-plan il branch nasce **sempre** dal branch in cui stanno le sorelle
già unite, appena aggiornato — il `git pull --ff-only` qui sopra:

- il **branch della madre**, `${user_config.branch_prefix}<madre>`, se esiste su `origin`
  (`git ls-remote --exit-code --heads origin <branch-madre>`): il progetto è portato avanti da
  `/issue-flow:big-implement`, e le sorelle si uniscono lì;
- il branch di destinazione altrimenti.

Mai dal branch di una sorella non ancora unita.

## 3. Il ciclo, una fase alla volta

Per ogni fase non completata, in ordine. Quattro passi, sempre gli stessi.

### Delega

Un'invocazione del tool `Agent` con `subagent_type: "issue-flow:issue-phase"`. Il subagent non
ha visto la conversazione e non ha letto la issue: **quello che non gli scrivi non esiste**.
Nel prompt vanno, integrali e non riassunti:

- numero e titolo della issue, e branch su cui si sta lavorando;
- le sezioni **Obiettivo**, **Contesto** e **Fuori perimetro** della issue;
- il numero della fase e il suo **testo integrale**: cappello, elenco dei file, tutte le
  checkbox con i frammenti di codice sotto, la riga «Fatto quando»;
- cosa hanno lasciato le fasi precedenti, se hanno deviato dal piano scritto.

Subito prima dell'invocazione `touch "$GOAL_DIR/in-volo"`, e appena il subagent torna
`rm -f "$GOAL_DIR/in-volo"`, prima della verifica.

Regole non negoziabili:

- **un subagent nuovo per ogni fase.** Mai riusarne uno con `SendMessage` per la fase dopo,
  mai passargliene due insieme, mai due fasi in parallelo: la fase N+1 parte dal codice che
  la fase N ha lasciato, e in parallelo si pestano i piedi sugli stessi file;
- se la roadmap ha una fase Figma, è una fase come le altre e va al suo subagent, che userà la
  skill `figma:figma-use` e il tool `use_figma` sul file `${user_config.figma_file}`. Va
  **prima** del codice, sempre, perché il codice si adegua al Figma e non viceversa;
- la fase di chiusura — documentazione e commit — la tieni tu: è coordinamento, non
  implementazione.

### Verifica

Al ritorno del subagent esegui **tu** i comandi della fase e guarda l'output vero. Il report
di un subagent è un racconto, non una prova.

Se la fase non porta comandi propri, valgono quelli del progetto per la parte toccata: quelli
che la issue elenca nella fase di verifica, o `${user_config.verify_commands}`.

Se la verifica fallisce: una seconda passata con un subagent **nuovo**, a cui dai l'output
dell'errore e cosa era stato tentato. Se fallisce di nuovo, fermati e riporta — due
fallimenti sulla stessa fase dicono che è sbagliata la issue, non il subagent.

### Spunta le caselle sulla issue

Appena la verifica passa, e non a lavoro finito. È il passo che rende la issue leggibile a
chi riprende dopo un `/clear`: senza, la roadmap mente.

```bash
# GitLab
glab issue view <numero> --output json --jq '.description' > "$SCRATCH/roadmap.md"

# GitHub
gh issue view <numero> --json body --jq '.body' > "$SCRATCH/roadmap.md"
sed -i 's/\r$//' "$SCRATCH/roadmap.md"

# giri in `- [x]` SOLO le checkbox della fase appena chiusa
# porti la riga «**Stato:**» a `in corso — fase N di M`

glab issue update <numero> --description-file "$SCRATCH/roadmap.md"   # GitLab
gh   issue edit   <numero> --body-file        "$SCRATCH/roadmap.md"   # GitHub
```

**Rileggi sempre il corpo dal server prima di riscriverlo**, mai da una copia tenuta in
conversazione: l'update sostituisce l'intero campo e non fa merge, quindi una versione vecchia
cancella quello che l'utente ha spuntato dalla pagina mentre lavoravi. E controlla che il file
non sia vuoto prima di rimandarlo su.

Se durante l'implementazione una decisione è cambiata, **riscrivi la riga** invece di
spuntarla: la roadmap deve dire cosa è stato fatto davvero. Se il subagent non è riuscito a
completare una checkbox, resta `- [ ]` e il motivo va detto all'utente alla fine.
Con una checkbox vuota la roadmap non risulta mai completa: a fine lavoro cancella tu
`$GOAL_DIR/goal`, sennò l'hook ti rimanda indietro.

### Committa

La fase e nient'altro:

```bash
git add -A && git commit -m "<tipo>(<ambito>): <cosa cambia per chi usa> (#<numero>)"
```

I messaggi seguono la convenzione già nel log del progetto — guardalo con
`git log --oneline -20` prima del primo commit, invece di imporne una tua. Mai committare con
la verifica fallita, mai un commit che copre due fasi.

## 4. Dove finisce questa skill

Al commit dell'ultima fase, con tutte le caselle spuntate sulla issue. **La MR/PR non la apri
qui**: la apre `/issue-flow:close <numero>`, che rifà la verifica sull'albero finale e ne
scrive il corpo. Dirlo all'utente nella consegna è parte del lavoro — sennò resta con un
branch pronto e nessuno che glielo porta a destinazione.

Porta la riga **Stato:** della issue a `implementata — in attesa di merge request` (su GitHub:
`in attesa di pull request`), così chi riapre la pagina sa a che punto è senza guardare il log
di git.

## 5. Consegna

Poche righe: le fasi chiuse con i loro commit (`git log --oneline`), le checkbox rimaste
vuote con il motivo, le deviazioni scritte nella roadmap, i problemi che i subagent hanno
visto fuori dal loro perimetro, e come si prosegue: `/issue-flow:close <numero>`. Non
incollare la issue né il diff.

Se era una figlia di un big-plan, dillo anche: quale è la figlia successiva nella madre, e che
si comincia solo dopo il merge di questa, con `/issue-flow:close <numero> --chiudi` che spunta
la casella sulla madre — oppure che `/issue-flow:big-implement <madre>` porta avanti tutte le
figlie restanti senza aspettare i merge. Se la figlia è nata dal branch della madre,
`/issue-flow:close <numero>` la unisce lì da solo, e non c'è merge da aspettare.

## Quando fermarsi davvero

Fermati e chiedi, invece di proseguire, se: la stessa fase fallisce due volte; una fase
richiede una decisione che la issue non ha preso; il lavoro tocca in modo sostanziale file
che la issue non prevedeva; una verifica non è eseguibile su questa macchina (porta, servizio
o credenziale mancanti); la issue è in contraddizione con il codice che trovi.

Prima di fermarti, `rm -f "$GOAL_DIR/goal"`: altrimenti l'hook ti rimanda al lavoro.

Il rimedio giusto è quasi sempre correggere la issue prima di correggere il codice.
