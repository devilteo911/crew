---
name: plan
description: "Trasforma la richiesta di una singola feature in una issue sul tracker del repo — GitLab o GitHub, secondo il remote — con dentro il piano e la sua roadmap: ricognizione nel codice, bivi di progettazione chiesti all'utente, fasi con checkbox atomiche che il tracker rende spuntabili, e le istruzioni per spuntarle mano a mano. Se il lavoro richiede più issue se ne accorge, avvisa e propone come proseguire, incluso il passaggio a /issue-flow:big-plan. Trigger: /issue-flow:plan, «apri una issue per…», «scrivi il piano di…», «spunta la roadmap della issue N»."
argument-hint: "<descrizione della modifica>"
---

# /issue-flow:plan

Non si implementa niente che non sia scritto in una issue. La issue non è un promemoria: è
**l'istruzione di lavoro**, e contiene sia il piano sia la roadmap che lo esegue. Chi
implementa legge quella e basta.

Questa skill è per **una singola feature**: una issue, da 5 a 8 fasi, una merge request. Se la
richiesta è uno sviluppo che non ci sta — più incrementi che si uniscono ognuno per conto suo —
la porta giusta è `/issue-flow:big-plan`, che definisce la roadmap del progetto e la divide in
issue. Non tocca all'utente accorgersene: il passo 2 bis lo controlla sempre, e se la richiesta
non sta in una issue ti fermi, avvisi e proponi come proseguire.

Il tracker è **GitLab** (`glab`) o **GitHub** (`gh`) a seconda del remote, e la differenza è
solo di comando: `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` — il file `TRACKER.md` nella cartella di
questo plugin — dice quale si usa qui e come si traduce ogni comando dall'uno all'altro.
Leggilo prima di lanciare il primo comando della sessione: i comandi qui sotto sono nelle due
varianti, ma le trappole (il campo del corpo che cambia nome, il `--limit` di
`gh issue list`, i CRLF) stanno lì.

## Usage

```
/issue-flow:plan <descrizione della modifica>   # il caso normale: dalla richiesta alla issue
/issue-flow:plan                                # usa un piano già approvato in questa conversazione
/issue-flow:plan spunta <n>                     # rileggi la roadmap e aggiorna le spunte
/issue-flow:plan rivedi <n>                     # riapri il piano di una issue e riscrivilo
```

## Il principio che decide tutto il resto

**La issue deve essere eseguibile da un agente che non ha assistito alla conversazione.**

Nel dubbio se scrivere qualcosa o darlo per scontato, applica questo test: un altro modello,
aperto il repo e letta solo la issue, saprebbe quali file toccare, cosa scriverci dentro e
come capire se ha funzionato? Se no, manca qualcosa.

Da qui discende tutto il resto: i riferimenti `file.ts:42` verificati, i numeri **misurati** e
non stimati, le decisioni scritte con la loro motivazione, il fuori perimetro esplicito.

## Il progetto ospite

Questo plugin non sa niente del progetto su cui gira, e non deve inventarselo. Le tre cose che
gli servono si ricavano così, in quest'ordine:

**Il branch di destinazione.** `${user_config.default_branch}` se l'utente l'ha configurato,
altrimenti dal repo:

```bash
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' \
  || git branch --show-current
```

**I comandi di verifica.** `${user_config.verify_commands}` se configurati. Se non lo sono, li
ricavi dal progetto in ricognizione e li **scrivi nella issue**, così la fase di verifica ha
comandi veri e non un generico «esegui i test»: gli script di `package.json`, i target del
`Makefile`, `pyproject.toml`/`tox.ini`, i job della CI in `.gitlab-ci.yml` o
`.github/workflows/`. Il `CLAUDE.md` del progetto, se c'è, li dice quasi sempre già.

**Cosa va tenuto allineato alla fine.** `${user_config.docs_paths}` se configurati, altrimenti
i file di documentazione che il progetto ha davvero — `README.md`, `docs/`, un changelog — e
che la modifica renderebbe falsi.

Se una di queste non si ricava e serve, chiedila all'utente: è una domanda sola, e vale per
tutte le issue che verranno.

## Processo

### 0. Quale tracker, e risponde

Prima cosa, la piattaforma: `git remote get-url origin` — `github` nell'URL vuol dire `gh`,
`gitlab` vuol dire `glab`. Poi che risponda davvero:

```bash
glab auth status && glab issue list --all              # GitLab
gh   auth status && gh   issue list --state all        # GitHub
```

L'autenticazione è interattiva e **non puoi farla tu**: se manca, fermati e chiedi all'utente
`glab auth login --hostname gitlab.com` o `gh auth login --hostname github.com`. Se invece il
comando dà 404 o «could not determine base repo» il remote è un alias SSH, e il rimedio è in
`TRACKER.md` §2 — una riga per piattaforma. Se il remote non è né GitHub né GitLab, o il CLI
che servirebbe non è installato, fermati e dillo: non si apre una issue a mano.

### 1. Lavora come in plan mode, senza entrarci

**Non chiamare mai `EnterPlanMode` né `ExitPlanMode`.** `ExitPlanMode` chiude con la
proposta di implementare il piano, e qui il piano non si implementa: si scrive nella issue,
e a implementarlo sarà `/issue-flow:implement`. Il modo di lavorare però è lo stesso del plan
mode, e vale da qui fino alla creazione della issue:

- **solo lettura.** Fino al passo 5 non modifichi niente nel repo: niente `Edit` o `Write`
  sui file del progetto, niente comandi che cambiano lo stato. Leggi, cerchi, misuri. L'unico
  file che scrivi è il corpo della issue, nello scratchpad;
- **le domande le fai mano a mano.** I bivi di progettazione del passo 3 si chiedono con
  `AskUserQuestion` appena la ricognizione li fa emergere, come farebbe il plan mode: non
  accumularli per farne una sola raffica alla fine, e non lasciarli impliciti;
- **il piano si presenta prima di aprire la issue.** Chiusi i bivi, scrivi in chat un riassunto
  del piano: cosa cambia, i vincoli trovati in ricognizione, le decisioni prese da solo con
  la motivazione, le fasi con una riga ciascuna. Poi chiedi con `AskUserQuestion` — è
  questo il posto dell'approvazione, non `ExitPlanMode` — con tre opzioni: «Apri la issue»
  (Recommended), «Cambia qualcosa» (l'utente dice cosa, tu correggi il piano e richiedi),
  «Lascia stare» (non apri niente e ti fermi);
- **solo «Apri la issue» porta al passo 5.** Non offrire mai di implementare, né come opzione
  della domanda né nel messaggio di consegna.

Se il piano è già stato approvato in questa conversazione — l'utente ha usato il plan mode
per conto suo e l'ha approvato, oppure è `/issue-flow:plan` senza argomenti — salta il
riassunto e la domanda di approvazione: la ricognizione è fatta, fai il controllo del passo
2 bis e, se la richiesta sta in una issue, vai ai passi 4 e 5.

### 2. Ricognizione nel codice — non saltabile

Una richiesta è un'intenzione; la issue è un'istruzione. La differenza la fa questo passo.
**Prima di scrivere una riga di piano:**

- individua i file che la modifica toccherà e **leggili davvero**, non dedurli dai nomi;
- annota i numeri di riga che la issue dovrà citare, e verificali;
- **misura, non stimare.** Quello che il progetto ha già su disco è un dato vero: quante righe
  ha il file che stai per spezzare, quante chiamate ha la funzione che stai per cambiare,
  quanti record hanno il campo popolato, quanto pesa il bundle oggi. Un numero misurato in
  ricognizione vale dieci frasi di piano, ed è quello che rende verificabile la fase finale;
- cerca i vincoli impliciti che il piano dovrà rispettare: invarianti scritte nei commenti,
  serializzazioni che non digeriscono certi tipi, cache o file su disco che si
  invaliderebbero, migrazioni di schema, import che creerebbero un ciclo, **campi speculari**
  fra backend e frontend che vanno cambiati insieme o non compilano;
- **la compatibilità all'indietro è quasi sempre un vincolo**: i dati già scritti, le risposte
  già in cache, i client già in giro devono continuare a funzionare dopo la modifica. Ogni
  campo nuovo nasce con un default, ogni rinomina si porta dietro chi la legge.

Ogni vincolo che scopri e che la richiesta non prevedeva va scritto nella issue, non risolto
in silenzio.

### 2 bis. Ci sta in una issue? — non saltabile

Questo controllo non è facoltativo e non aspetta la fine: lo fai **durante** la ricognizione, e
appena la risposta è no ti fermi, senza completare una ricognizione di dettaglio che servirebbe
a una issue che non si aprirà. Vale anche quando il piano arriva già approvato dalla
conversazione, e in `rivedi <n>` quando la riscrittura fa crescere la issue.

La richiesta **non** ci sta in una issue se vale anche una sola di queste:

- le fasi, verifica e chiusura comprese, sarebbero più di 8;
- il lavoro si divide naturalmente in incrementi che si possono unire uno alla volta, ognuno
  lasciando il prodotto funzionante — il modello dei dati, poi l'API, poi l'interfaccia;
- tocca più aree del sistema che si rivedono separatamente — servizi, pacchetti, backend e
  frontend con un contratto nuovo fra loro;
- la merge request finale toccherebbe così tanti file da non essere più rivedibile in una
  lettura.

**Non comprimere** uno sviluppo grosso in fasi enormi per farlo stare in otto: una fase che non
si chiude in un subagent non si chiude. E non decidere da solo di dividerlo: la scelta è
dell'utente.

#### L'avviso

Prima della domanda, scrivi in chat un avviso breve e concreto:

- **che la richiesta non sta in una issue**, detto in apertura e senza giri di parole;
- **perché**: i segnali qui sopra che valgono, con i numeri misurati in ricognizione — quante
  aree, quanti file, quante fasi verrebbero — e non impressioni;
- **la divisione che proponi**: le issue che ne verrebbero, in ordine di esecuzione, una riga
  ciascuna con cosa consegna e da quale dipende. È una bozza, non la roadmap: serve all'utente
  per capire di che dimensioni si parla e per scegliere.

#### La domanda

Poi `AskUserQuestion`, con queste opzioni — nella descrizione di ognuna scrivi in concreto cosa
succede dopo, con i numeri della bozza:

- **«Passa a /issue-flow:big-plan»** (Recommended): issue madre con la roadmap e le N figlie
  della bozza, eseguite una alla volta;
- **«Apri solo la prima issue»**: questa skill prosegue con il primo incremento della bozza; il
  resto va nel **Fuori perimetro** della issue, un punto per ciascuna delle issue successive,
  così non si perde;
- **«Restringi il perimetro»**: l'utente dice cosa entra; si riparte dal controllo con il
  perimetro nuovo;
- **«Tieni una issue sola»**: l'utente se ne prende la responsabilità. Si prosegue anche oltre
  le 8 fasi, e nel **Contesto** della issue va scritto che la dimensione è una scelta
  dichiarata, con i numeri che l'avrebbero fatta dividere.

#### Come si prosegue

- con **big-plan**: carica subito la skill `issue-flow:big-plan` con il tool `Skill`, nella
  stessa conversazione, passandole la richiesta originale. La ricognizione fatta fin qui non si
  butta: `big-plan` la riprende da dove sei arrivato e parte dalla bozza di divisione. Da quel
  momento vale `big-plan`, non questa skill;
- con **solo la prima issue** o **restringi**: torna alla ricognizione per il perimetro nuovo —
  i `file:riga` e i numeri della issue devono riguardare quello che la issue fa davvero — e
  prosegui dal passo 3;
- con **una issue sola**: prosegui dal passo 3.

### 3. Chiedi solo i bivi veri

Usa `AskUserQuestion` quando due letture della richiesta porterebbero a lavoro diverso —
l'impaginazione di una tabella, quali colonne, se una cosa entra o resta fuori. Non per
scelte che hanno un default ovvio: quelle le prendi tu e le **dichiari** nel messaggio
finale, con la motivazione, così l'utente può ribaltarle.

Per le scelte di impaginazione metti un `preview` con un bozzetto ASCII: si confrontano a
colpo d'occhio e l'utente risponde in due secondi.

### 4. Titolo e branch

Il titolo dice **cosa cambia per chi usa il prodotto**, non quale file si tocca: una frase
breve in minuscolo, senza punto finale. Il numero è quello che assegna il tracker, e si legge
dall'URL che il comando di creazione stampa.

Il branch di lavoro è `${user_config.branch_prefix}<numero della issue>` — con il default
`issue-`, la issue #12 si lavora su `issue-12`.

### 5. Scrivi la issue

Segui `TEMPLATE.md`, il file accanto a questo, che ne descrive le sezioni una per una. Scrivi
il corpo in un file temporaneo e crea la issue da lì:

```bash
glab issue create --title "<titolo>" --description-file <file> --yes   # GitLab
gh   issue create --title "<titolo>" --body-file        <file>         # GitHub
```

Il file evita di far passare un corpo lungo dentro le virgolette della shell. Il numero
assegnato è quello che il comando stampa nell'URL: leggilo da lì, non dedurlo.

### 6. Consegna

In poche righe: il link, cosa hai trovato in ricognizione che la richiesta non prevedeva, le
decisioni che hai preso da solo con la loro motivazione, e cosa hai lasciato fuori perimetro.
Non incollare la issue nella risposta: è una pagina, l'utente la apre.

## La roadmap

È il motivo per cui la issue esiste, e sta **dentro la issue**, nella sezione Piano, come
fasi con checkbox. Le riconoscono come task list e le rendono cliccabili sia GitLab, che
mostra «0 di N attività completate» e le conta in `task_completion_status`, sia GitHub, che
mostra «0 of N tasks» in testa alla issue. Il conteggio via API però esiste solo su GitLab:
il modo che vale su entrambi è contare le righe nel corpo, ed è quello che usano
`/issue-flow:implement` e `/issue-flow:close` (`TRACKER.md` §5).

### Le fasi

Una fase è **un pezzo di lavoro che si chiude**: lascia il repo in uno stato coerente e
verificabile. Non una giornata, non un'area tematica. Da 5 a 8 fasi è l'intervallo normale.

Due fasi sono obbligate e vanno sempre in fondo, in quest'ordine:

- **la penultima è la verifica**, e comprende i comandi del progetto — quelli configurati in
  `${user_config.verify_commands}` o quelli che hai ricavato in ricognizione — più una prova a
  mano su ciò che la issue prometteva si dovesse vedere. Se la modifica tocca l'interfaccia,
  anche il controllo da tastiera, il responsive e l'accessibilità;
- **l'ultima è la chiusura**: i file di documentazione che vanno riscritti, nominati uno per
  uno, e il commit sul branch della issue. La MR/PR **non è una checkbox della roadmap**: la
  apre `/issue-flow:close <numero>` quando tutte le fasi sono chiuse.

Una terza è condizionale: se `${user_config.figma_file}` è configurato e la modifica tocca il
frontend, **la prima fase è il Figma**. Si lavora con la skill `figma:figma-use` e il tool
`use_figma`; il Figma si allinea **prima** del codice, non dopo, perché il codice si adegua al
Figma e non viceversa; i componenti esistenti si ristrutturano in posto e non si ricreano, se
no le istanze si staccano. Se la configurazione è vuota, questa fase non esiste: non
inventarla.

### Le checkbox

- **Copertura totale.** Ogni pezzo di lavoro ha la sua: codice, modelli, tipi speculari fra
  backend e frontend, stringhe di interfaccia, righe di documentazione, verifiche. Il lavoro
  che non ha una checkbox è lavoro che verrà dimenticato.
- **Atomica.** Una checkbox = una cosa che si spunta senza riserve. Se per spuntarla devi
  dire «sì, ma a metà», andava divisa in due.
- **Verificabile dall'esterno.** `- [ ] ogni campo nuovo ha default ""` si controlla;
  `- [ ] capire come funziona il filtro` no: non è una checkbox, è un pensiero.
- **Imperativa e concreta.** Nomina il file, la funzione, la riga: meglio
  `- [ ] src/api/user.ts:104, UserOut guadagna i cinque campi con default ""` che
  `- [ ] aggiornare l'API`.
- **Autonoma.** Non deve dipendere da qualcosa detto solo in chat.

Quando la decisione è già presa e il come è già stabilito, mettici sotto il frammento di
codice che la definisce: una checkbox seguita da tre righe vale un paragrafo.

## Come si spunta — e perché va scritto nella issue

Ogni issue prodotta da questa skill **deve contenere la sezione «Come si aggiorna questa
roadmap»** del template. Non è cerimonia: la roadmap serve a chi riprende il lavoro dopo un
`/clear`, e una roadmap che non dice il proprio stato non serve a niente.

La regola, che vale sia per l'utente sia per te:

- si spunta **mano a mano**, alla fine di ogni pezzo, non a lavoro finito;
- si spunta **nello stesso momento** in cui il lavoro è fatto e verificato, e la spunta entra
  nel commit di quella fase;
- se durante l'implementazione una decisione cambia, si **riscrive la riga** della roadmap:
  una roadmap che mente è peggio di nessuna roadmap.

Il giro per aggiornarla, che è anche cosa fa `/issue-flow:plan spunta <n>`:

```bash
# GitLab — il campo del corpo si chiama `description`
glab issue view <n> --output json --jq '.description' > "$SCRATCH/roadmap.md"

# GitHub — si chiama `body`, e arriva spesso con terminatori CRLF
gh issue view <n> --json body --jq '.body' > "$SCRATCH/roadmap.md"
sed -i 's/\r$//' "$SCRATCH/roadmap.md"

# giri le `- [ ]` fatte in `- [x]`, tocchi la riga «Stato:» se la fase è chiusa

glab issue update <n> --description-file "$SCRATCH/roadmap.md"    # GitLab
gh   issue edit   <n> --body-file        "$SCRATCH/roadmap.md"    # GitHub
```

**Rileggi sempre il corpo dal server prima di riscriverlo**, mai da una copia tenuta in
conversazione. L'update sostituisce l'intero campo e non fa merge: se l'utente ha spuntato
una casella dalla pagina mentre lavoravi, riscrivere una versione vecchia gliela cancella.
Per lo stesso motivo, controlla che il file appena scritto non sia vuoto: un `jq` sul campo
sbagliato dà `null`, e rimandarlo su svuota la issue.

Quando tutte le checkbox di una issue sono spuntate e il lavoro è unito, la si chiude —
`glab issue close <n>` o `gh issue close <n>` — e si porta la riga «Stato:» a
`chiusa — unita il GG/MM/AAAA`. Su GitHub può essersi già chiusa da sola, se la PR portava
`Closes #<n>`: guarda lo stato prima di dire di averla chiusa tu.

## Chi esegue la issue

Non questa skill: `/issue-flow:implement <n>` la prende, manda una fase per subagent e spunta
le caselle mano a mano; poi `/issue-flow:close <n>` verifica l'albero finale, apre la MR/PR e,
a merge avvenuto, chiude la issue. Scrivi la roadmap sapendo che a leggerla sarà un agente che
non ha assistito a niente — è la ragione per cui le fasi devono essere autonome.

Le stesse regole valgono per le issue figlie di `/issue-flow:big-plan`: le scrive il subagent
`issue-flow:issue-writer` seguendo questa skill e `TEMPLATE.md`, con in più in testa le righe
**Roadmap** e **Dipende da**. `/issue-flow:plan rivedi <n>` funziona anche su di loro: se la
figlia ha la riga **Roadmap**, rileggi la madre prima di riscriverla e non contraddirne le
decisioni.

## Come si scrive

Prosa densa, italiano, termini tecnici e identificatori in originale. Frasi che portano
informazione: il *perché* di una scelta, non la sua parafrasi.

- niente stime in ore o giorni, niente story point, niente percentuali;
- niente `TBD`, `da definire`, `valutare se`: se una decisione non è presa, prendila ora o
  scrivila come domanda aperta con chi deve rispondere;
- i riferimenti al codice sempre come `percorso/file.ts:42`, verificati in ricognizione;
- i numeri sempre misurati, con detto **dove** sono stati misurati;
- grassetto solo dove cambia una decisione, non a caso.
