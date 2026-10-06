---
name: big-implement
description: "Porta avanti in una sola esecuzione tutte le issue figlie di una issue madre di /issue-flow:big-plan — GitLab o GitHub — sul branch della madre: una figlia alla volta, nell'ordine della madre, ognuna affidata a un subagent issue-runner che fa il giro di /issue-flow:implement (una fase per subagent, checkbox spuntate, un commit per fase) e quello di /issue-flow:close, che verifica, apre la merge request — pull request su GitHub — verso il branch della madre e la unisce da solo. Alla fine apre la MR/PR della madre verso il branch di destinazione, che unisce solo l'utente. Trigger: /issue-flow:big-implement, «implementa tutto il progetto N», «porta avanti tutta la roadmap N», «esegui tutte le figlie di N»."
argument-hint: "<madre>"
hooks:
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/goal-stop.sh"
---

# /issue-flow:big-implement

`/issue-flow:implement <madre>` esegue **una** figlia e si ferma: la successiva parte solo
dopo il merge della precedente, che fa l'utente. Questa skill porta avanti **tutto il
progetto** in una volta, senza aspettare nessuno fino alla fine:

```
main ──────────────────────────────────────────────── ◀── MR/PR issue-20 (la unisce l'utente)
  └─ issue-20 ──●──────────●──────────●─────────
                ▲          ▲          ▲
            issue-21   issue-22   issue-23     (ognuna nasce da issue-20 e ci torna da sola)
```

- la madre ha il suo branch, `${user_config.branch_prefix}<madre>`, nato dal branch di
  destinazione;
- ogni figlia nasce dal branch della madre aggiornato, si implementa, e poi passa per `close`:
  verifica sull'albero finale, documentazione, MR/PR **verso il branch della madre** — che qui
  `close` **unisce da solo**, perché il branch della madre non è il prodotto: è il cantiere del
  progetto, e la revisione vera arriva alla fine;
- quando l'ultima figlia è unita, la MR/PR della madre verso il branch di destinazione si apre
  come sempre e **non si unisce**: quella l'approva e la unisce l'utente.

Le regole di esecuzione sono quelle di `implement` e `close` e non si ripetono qui:
`${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md` per le fasi, la verifica, le spunte, i commit
e la modalità goal; `${CLAUDE_PLUGIN_ROOT}/skills/close/SKILL.md` per la verifica finale, la
documentazione, la MR/PR, il merge nel branch della madre e la chiusura;
`${CLAUDE_PLUGIN_ROOT}/TRACKER.md` per i comandi delle due piattaforme. **Leggili tutti e tre
prima del primo comando.** Qui sotto c'è solo quello che cambia.

## Usage

```
/issue-flow:big-implement <madre>   # esegue in sequenza tutte le figlie non ancora unite
```

## Tu sei l'orchestratore, di tutto il progetto

Non implementi le figlie e non ne orchestri le fasi: ogni figlia la affidi a un subagent
`issue-flow:issue-runner`, che fa per lei il giro di `implement` e di `close` fino al merge nel
branch della madre, e a sua volta affida ogni fase a un subagent `issue-flow:issue-phase`:

```
tu (big-implement)                  il progetto: catena, branch della madre, goal, MR/PR della madre
 └─ issue-runner, uno per figlia     la figlia: fasi, verifiche, spunte, commit, close, merge
     └─ issue-phase, uno per fase    la fase: il codice
```

Il motivo è il contesto, come in `implement` ma un livello più su: le fasi di tutte le figlie
nel tuo contesto lo riempirebbero a metà progetto. Tu tieni la visione del progetto — quale
figlia è in corso, con quale MR/PR, quante sono già nel branch della madre, cosa hanno cambiato
in corsa — e controlli l'esito di ogni figlia sul tracker e su git, non sul racconto del runner.

La catena usa tutta la profondità che Claude Code concede: sotto la sessione principale i
subagent possono lanciarne altri per due livelli, e il terzo non ha più il tool `Agent`. Per
questo `issue-phase` non delega, e il runner non deve mai essere lanciato da un altro subagent.

**Mai due figlie insieme.** Né in parallelo né intrecciate: la figlia N+1 nasce dal branch della
madre **dopo** che la N ci è stata unita, e parte dal codice che la N ha lasciato.

## 0. Quale tracker, e risponde

Identico al passo 0 di `implement`.

## 1. Leggi la madre e ricava la catena

Leggi la madre dal server come al passo 1 di `implement`. Se in testa al corpo non c'è
`**Tipo:** roadmap`, non è una madre: dillo e proponi `/issue-flow:implement <numero>`.

Dalla sezione **Issue**, nell'ordine, prendi le righe `- [ ] #<n>`: sono le figlie da portare
avanti. Quelle `- [x]` sono già unite — nel branch della madre o, da un giro fatto a mano, nel
branch di destinazione — e non si toccano. Per ogni figlia da fare guarda sul tracker:

- **lo stato**: se è già chiusa ma la casella è vuota, la madre è rimasta indietro —
  segnalalo, non rieseguirla, e trattala come unita;
- **le dipendenze** — `· dipende da #<k>` nella madre, `**Dipende da:**` nella figlia: ognuna
  deve essere unita (casella spuntata o issue chiusa) **oppure** una figlia che questa
  esecuzione porta avanti **prima** di lei. Una dipendenza fuori da entrambi i casi — una issue
  esterna aperta, una sorella che viene dopo nell'ordine — è una roadmap che non regge:
  fermati e dillo;
- **se è già iniziata** da un giro precedente: il branch `${user_config.branch_prefix}<n>`
  esiste, ha checkbox spuntate, ha già una MR/PR (`glab mr list --source-branch <branch>`,
  `gh pr list --head <branch>`). Riprendi da dove è rimasta invece di ripartire: dalla prima
  fase non spuntata, dalla MR/PR se le fasi sono tutte fatte, dal merge se la MR/PR è aperta.

Guarda anche la **madre**: se ha già una MR/PR aperta verso il branch di destinazione
(`glab mr list --source-branch <branch-madre>`, `gh pr list --head <branch-madre>`), il
progetto è già consegnato — dillo e non ripartire.

Poi presenta all'utente la catena e parti senza chiedere conferma:

```
issue-20  branch della madre, nasce da main
#21  issue-21  nasce da issue-20   MR/PR → issue-20, unita da close
#22  issue-22  nasce da issue-20   MR/PR → issue-20, unita da close
#23  issue-23  nasce da issue-20   MR/PR → issue-20, unita da close
issue-20  MR/PR → main, la unisce l'utente
```

Se non c'è nessuna figlia da fare ma la madre non ha ancora la sua MR/PR, salta al passo 5.

## 2. Il branch della madre

Il branch della madre è `${user_config.branch_prefix}<madre>` — con il default `issue-`, la
madre #20 ha `issue-20`. Nasce dal branch di destinazione aggiornato, e va **subito sul
remote**: le MR/PR delle figlie ci puntano, e `close` riconosce il flusso di big-implement
proprio dalla sua esistenza su `origin`.

```bash
git status --porcelain                 # deve essere vuoto
git fetch origin
git switch <branch-madre> 2>/dev/null \
  || git switch -c <branch-madre> --track origin/<branch-madre> 2>/dev/null \
  || { git switch <destinazione> && git pull --ff-only && git switch -c <branch-madre>; }
git push -u origin <branch-madre>
```

Se il branch esisteva già da un giro precedente, allinealo a `origin` con `git pull --ff-only`.
Se il branch di destinazione è andato avanti nel frattempo, **non** lo rincorri: il branch della
madre si riallinea una volta sola, al passo 5 — in `close` sulla madre —, dove un conflitto è
una decisione dell'utente.

Porta la riga **Stato:** della madre a `in corso — k di M issue unite in <branch-madre>`.

## 3. Il goal copre tutto il progetto

La modalità goal è quella di `implement`, con una differenza: `$GOAL_DIR/goal` contiene **tutte**
le figlie da portare avanti e **la madre**, un numero per riga. L'hook `Stop` rilegge ognuna dal
tracker e non lascia chiudere il turno finché una qualsiasi ha una `- [ ]`: nel Piano per le
figlie, nella sezione **Issue** per la madre — che si spunta solo quando una figlia è unita nel
suo branch. Così il goal regge fino all'ultimo merge, non solo fino all'ultima fase.

```bash
GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow)
mkdir -p "$GOAL_DIR" && printf '%s\n' 21 22 23 20 > "$GOAL_DIR/goal" && rm -f "$GOAL_DIR/in-volo"
```

Lo scrivi dopo il passo 2, prima della prima figlia. `in-volo` funziona come in `implement`, ma
segnala il **runner** al lavoro: lo crei subito prima di delegare la figlia e lo cancelli appena
il runner torna. Un solo runner alla volta. Il runner non tocca `.git/issue-flow/`: il goal e
`in-volo` sono solo tuoi.

Quando l'ultima figlia è unita l'hook ti lascia fermare anche se la MR/PR della madre non è
ancora aperta. Non fermarti lì: la consegna arriva dopo il passo 5.

Per fermarti prima della fine **cancelli tu `$GOAL_DIR/goal`** e dici all'utente perché.

## 4. Il giro, una figlia alla volta

Per ogni figlia della catena, in ordine: la deleghi a un runner (4.1), il runner fa il giro
della figlia (4.2), tu controlli come è finita (4.3). Poi la figlia successiva.

### 4.1 Delega la figlia

Un'invocazione del tool `Agent` con `subagent_type: "issue-flow:issue-runner"`. Il runner non
ha visto la conversazione: **quello che non gli scrivi non esiste**. Nel prompt:

- il numero e il titolo della figlia, il numero della madre, il branch della madre e il branch
  di destinazione;
- i percorsi assoluti delle istruzioni che deve leggere:
  `${CLAUDE_PLUGIN_ROOT}/skills/big-implement/SKILL.md` — per il passo 4.2, il suo giro —,
  `${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md`, `${CLAUDE_PLUGIN_ROOT}/skills/close/SKILL.md`
  e `${CLAUDE_PLUGIN_ROOT}/TRACKER.md`;
- i valori della configurazione: `${user_config.branch_prefix}`, `${user_config.default_branch}`,
  `${user_config.verify_commands}`, `${user_config.docs_paths}`, `${user_config.figma_file}` —
  vuoti compresi, detti come vuoti;
- da dove riprendere, se il passo 1 ha trovato la figlia già iniziata: la prima fase non
  spuntata, la MR/PR già aperta, il merge;
- cosa hanno lasciato le sorelle già unite in questa esecuzione, se hanno deviato dalla loro
  issue — il writer della figlia le conosceva solo come piano. È il campo «deviazioni» dei
  report dei runner precedenti.

Subito prima dell'invocazione `touch "$GOAL_DIR/in-volo"`, e appena il runner torna
`rm -f "$GOAL_DIR/in-volo"`, prima del controllo.

Regole non negoziabili: **un runner nuovo per ogni figlia**, mai riusarne uno con `SendMessage`
per la figlia dopo, mai due figlie in parallelo. Mentre il runner lavora non tocchi la working
tree né il tracker: siete sulla stessa cartella e sulle stesse issue.

### 4.2 Il giro della figlia

Questo lo fa il runner, e sta qui perché è il suo riferimento. Tre passi.

#### Il branch, dalla madre

La base di ogni figlia è il branch della madre aggiornato, **dopo** il merge della sorella
precedente:

```bash
git status --porcelain                 # deve essere vuoto
git switch <branch> 2>/dev/null \
  || { git switch <branch-madre> && git pull --ff-only && git switch -c <branch>; }
```

È la regola del passo 2 di `implement` con il branch della madre al posto di quello di
destinazione: è lì che stanno le sorelle già unite. Il controllo del passo **1 ter** di
`implement` si fa contro il branch della madre: le dipendenze sono chiuse e il loro lavoro è lì
(`git log --oneline <branch-madre> | grep '#<k>'`), e i punti d'aggancio «nasce con #<k>»
esistono lì. Se non reggono, ti fermi come dice `implement`.

#### Le fasi

Il passo 3 di `implement`, con una sola variante: niente `in-volo` né `goal`, che sono di
`big-implement`. Un subagent `issue-flow:issue-phase` **nuovo** per ogni fase con il contesto
integrale della figlia, verifica eseguita dal runner, spunta sulla issue rileggendola dal
server, un commit per fase con `(#<figlia>)` nel messaggio. A fine fasi, la riga **Stato:**
della figlia come al passo 4 di `implement`.

Nel prompt di ogni fase va anche cosa hanno lasciato le sorelle già unite, se hanno deviato
dalla loro issue.

#### Close, fino al merge nel branch della madre

Tutto `close` sulla figlia, nel suo ramo «figlia con il branch della madre»: i controlli del
passo 1, la documentazione del passo 2, la MR/PR del passo 3 **verso il branch della madre**,
poi il merge e la chiusura del passo 3 bis, che non aspettano l'utente. Alla fine:

- la MR/PR della figlia è unita nel branch della madre, e il branch della figlia è cancellato;
- la figlia è chiusa, con **Stato:** `chiusa — unita in <branch-madre> il GG/MM/AAAA`;
- la sua casella sulla madre è spuntata, e lo **Stato:** della madre dice `k di M`;
- sei sul branch della madre, aggiornato: la figlia successiva nasce da qui.

Se `close` si ferma — una casella vuota, una verifica rossa, una pipeline fallita, una MR/PR che
il server non unisce — il runner si ferma e lo scrive nel report.

### 4.3 Controlla come è finita

Il report del runner è un racconto, non una prova. Prima di passare alla figlia successiva
controlli tu, sul server e su git:

```bash
# la MR/PR della figlia è unita nel branch della madre
glab mr list --source-branch <branch> --target-branch <branch-madre> --merged   # GitLab
gh   pr list --head <branch> --base <branch-madre> --state merged               # GitHub

# la figlia è chiusa, con tutte le caselle del Piano spuntate
glab issue view <figlia> --output json --jq '.state'    # "closed"
gh   issue view <figlia> --json state --jq '.state'     # "CLOSED"

# la sua casella è spuntata sulla madre: rileggi la madre dal server

# sei sul branch della madre, pulito e aggiornato, con dentro i commit della figlia
git branch --show-current && git status --porcelain
git fetch origin && git status -sb | head -1              # niente «behind»
git log --oneline <branch-madre> | grep '(#<figlia>)'
```

Se il runner si è fermato, o uno di questi controlli non torna, il progetto si ferma: vedi
«Quando fermarsi davvero». Un runner che dice «unita» quando il server dice altro non si
riprova: la figlia va guardata.

Tieni le deviazioni del report: vanno nel prompt del runner della figlia successiva e nella
consegna.

Poi passa alla figlia successiva.

## 5. La MR/PR della madre

Quando tutte le caselle della sezione **Issue** della madre sono spuntate, `close` sulla madre,
nel suo ramo «madre»: rifà la verifica sull'albero finale del branch della madre, allinea la
documentazione, pusha e apre la MR/PR `branch della madre → branch di destinazione` con
`Closes #<madre>`. **Mai il merge**: questa l'approva e la unisce l'utente, come ogni MR/PR
verso il branch di destinazione.

## 6. Consegna

Il link della MR/PR della madre, in cima: è l'unica cosa che l'utente deve fare. Poi una
tabella, nell'ordine in cui le figlie sono entrate nel branch della madre:

```
figlia  MR/PR  fasi  unita in
#21     !40    6/6   issue-20
#22     !41    7/7   issue-20
#23     !42    5/5   issue-20
```

Poi le checkbox rimaste vuote con il motivo, le deviazioni scritte nelle roadmap, i problemi
che i subagent hanno visto fuori dal loro perimetro. E come si prosegue: a merge avvenuto della
MR/PR della madre, `/issue-flow:close <madre> --chiudi`, che chiude la madre e cancella il suo
branch.

Non incollare le issue né il diff.

## Quando fermarsi davvero

Tutti i casi di «Quando fermarsi davvero» di `implement` e di `close` — che per una figlia li
incontra il runner, e te li riporta —, più uno: **se una figlia si ferma, il progetto si ferma
con lei.** La successiva nascerebbe da un branch della madre
senza il suo lavoro, quindi non si salta avanti. Nella consegna di' quale figlia si è fermata,
a che punto — fase, MR/PR, merge — perché, e che si riprende con
`/issue-flow:big-implement <madre>` una volta sistemata: il passo 1 ritrova le figlie già unite e
riparte da lì.

Prima di fermarti, `rm -f "$GOAL_DIR/goal"`: altrimenti l'hook ti rimanda al lavoro.
