---
name: big-plan
description: "Trasforma uno sviluppo grosso — più di quanto stia in una issue — in una roadmap di progetto sul tracker del repo, GitLab o GitHub: una issue madre con obiettivo, architettura e decisioni, e le issue figlie che la eseguono in sequenza, ognuna completa di piano e checkbox e scritta da un subagent dedicato. Trigger: /issue-flow:big-plan, «pianifica il progetto…», «dividi in issue…», «fai la roadmap di…»."
argument-hint: "<descrizione dello sviluppo>"
---

# /issue-flow:big-plan

`/issue-flow:plan` è per **una** feature: una issue, da 5 a 8 fasi, una merge request. Quando
lo sviluppo non ci sta — un sottosistema nuovo, una migrazione in più tappe, una funzionalità
che attraversa backend, dati e interfaccia — questa skill ne fa un **progetto**: una issue
madre che tiene la roadmap complessiva, e le issue figlie che la eseguono una alla volta, ognuna
con il suo branch e la sua MR/PR.

Tutto quello che `plan` dice vale anche qui, e non si ripete: `${CLAUDE_PLUGIN_ROOT}/skills/plan/SKILL.md`
— la skill `plan` di questo plugin — per il principio («la issue deve essere eseguibile da un
agente che non ha assistito alla conversazione»), il progetto ospite, la ricognizione, le fasi,
le checkbox, come si spunta e come si scrive. `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` per i comandi
delle due piattaforme e le loro trappole. **Leggili entrambi prima del primo comando.**

## Usage

```
/issue-flow:big-plan <descrizione dello sviluppo>   # dalla richiesta alla madre e alle figlie
/issue-flow:big-plan                                # usa una roadmap già approvata in conversazione
```

### Quando arrivi da `/issue-flow:plan`

`plan` controlla sempre se la richiesta sta in una issue, e quando non ci sta avvisa l'utente e
gli propone di passare qui. Se l'utente accetta, questa skill viene caricata nella stessa
conversazione, e c'è già del lavoro fatto: il tracker verificato, la ricognizione fino al punto
in cui `plan` si è fermato, una bozza di divisione in issue che l'utente ha visto.

Non rifarlo. Salta il passo 0, **completa** la ricognizione del passo 2 solo dove non basta
per una roadmap — tipicamente l'architettura d'insieme e i vincoli trasversali, perché `plan`
guardava da vicino il primo pezzo — e al passo 3 parti dalla bozza di `plan` invece che da zero:
correggila dove la ricognizione completa lo richiede, e nel riassunto del passo 4 di' cosa è
cambiato rispetto alla bozza che l'utente aveva visto.

### Quando arrivi da `/issue-flow:roadmap`

`roadmap` propone i prossimi passi del progetto leggendone la documentazione, e quando l'utente
sceglie «Crea le issue» carica questa skill nella stessa conversazione. Anche qui c'è lavoro
fatto: il tracker verificato, le fonti lette, una roadmap **approvata** dall'utente, con un passo
per figlia, le fonti di ognuno e le dipendenze.

Salta il passo 0. La ricognizione del passo 2 invece va fatta: `roadmap` ha guardato **cosa**
fare, non **come** — l'architettura toccata e i vincoli trasversali fra i passi mancano. Al
passo 3 i passi della roadmap sono le figlie: l'obiettivo della roadmap diventa l'**Obiettivo**
della madre, le sue **Attese**, il **Dopo** e il **Lasciato fuori** vanno nel **Contesto** e nel
**Fuori perimetro**, e le fonti di ogni passo (ID dei registri, sezioni di documenti, issue)
passano al writer della sua figlia, che le cita nel Contesto.

Se la ricognizione non cambia la divisione, la roadmap è già approvata: salta il riassunto e la
domanda del passo 4 e vai al passo 5. Se la cambia — un passo va diviso, due vanno uniti, una
dipendenza non regge — il passo 4 si fa, e il riassunto dice cosa è cambiato rispetto alla
roadmap approvata e perché.

Nella consegna del passo 9, se la roadmap veniva dai registri di research-flow, aggiungi la
corrispondenza fra figlie e voci (`#21 ← TODO-012, ESP-031`) e proponi
`/research-flow:annota` per segnarle `in corso` con la loro issue: i registri li scrive
research-flow, non questa skill.

## Tu sei l'orchestratore

Definisci la roadmap, prendi le decisioni con l'utente, apri la madre, **deleghi** la scrittura
di ogni figlia a un subagent e poi controlli e crei tutto sul tracker. Non scrivi tu i corpi
delle figlie.

Il motivo è lo stesso di `/issue-flow:implement`: ogni figlia richiede la sua ricognizione nel
codice — file letti davvero, righe verificate, numeri misurati — e fatte tutte qui dentro
riempirebbero il contesto fino a perdere la visione d'insieme, che è l'unica cosa che solo tu
hai. Il subagent parte pulito, legge solo quello che serve alla sua issue, e ti consegna un
corpo da controllare.

## Processo

### 0. Quale tracker, e risponde

Identico al passo 0 di `plan`: `git remote get-url origin`, poi `glab auth status` o
`gh auth status` e un `issue list` che risponda. Se manca l'autenticazione, fermati e chiedi
all'utente di farla: è interattiva.

### 1. Lavora come in plan mode, senza entrarci

Le stesse regole del passo 1 di `plan`: **mai `EnterPlanMode` né `ExitPlanMode`**, sola lettura
fino all'apertura della madre, bivi chiesti mano a mano con `AskUserQuestion`, l'approvazione
con `AskUserQuestion` e non con `ExitPlanMode`, e **mai offrire di implementare**.

### 2. Ricognizione d'insieme — non saltabile

Più larga di quella di `plan`, meno profonda: qui non servono ancora tutti i `file:riga` di
ogni fase — quelli li trova il writer di ogni figlia — ma serve sapere come è fatto il pezzo di
sistema che lo sviluppo attraversa.

- **l'architettura toccata**: quali moduli, servizi, pacchetti; dove passano i confini fra
  loro; chi chiama chi. Leggi i file d'ingresso, non dedurli dai nomi;
- **i vincoli trasversali**, quelli che valgono per più figlie e che nessuna da sola vedrebbe:
  lo schema dei dati e le sue migrazioni, i campi speculari fra backend e frontend, le cache,
  i client già in giro, la compatibilità all'indietro;
- **i numeri misurati** che dimensionano il lavoro: quante righe, quanti chiamanti, quanti
  record, quanti endpoint;
- il progetto ospite come in `plan`: branch di destinazione, comandi di verifica,
  documentazione da tenere allineata. Ricavali una volta qui e passali a tutti i writer.

### 3. La scomposizione

È il lavoro che questa skill fa e `plan` no. Le regole:

- **una issue è un incremento che si unisce da solo.** Dopo il merge di ogni figlia il prodotto
  compila, i test passano e niente di quello che funzionava si è rotto. Niente issue «metà
  backend» che lascia il branch di destinazione rotto finché non arriva la sorella: se due
  pezzi non stanno in piedi separati, sono una issue sola, oppure il primo va dietro un flag;
- **ogni figlia sta nelle 5–8 fasi di `plan`**, verifica e chiusura comprese. Se una non ci
  sta, va divisa; se due insieme ci stanno comode, vanno unite;
- **l'ordine è esplicito e le dipendenze sono dichiarate.** L'esecuzione è sequenziale, quindi
  di norma la catena è lineare: la figlia N parte dal codice che le figlie prima di lei hanno
  unito. Mettere prima quello che toglie incertezza — il modello dei dati, l'interfaccia fra
  due moduli — e dopo quello che ci si appoggia;
- **per ogni figlia**: un titolo che dice cosa cambia per chi usa il prodotto, cosa consegna,
  cosa lascia alle successive (tipi, interfacce, endpoint, file che nasceranno — con il nome
  che avranno), cosa resta fuori.

Se la scomposizione dà **una sola** issue, lo sviluppo non è grosso: dillo e proponi
`/issue-flow:plan`, invece di aprire una madre con una figlia sola.

### 4. Presenta la roadmap e fatti approvare

Chiusi i bivi, scrivi in chat un riassunto: l'obiettivo, l'architettura in poche righe, i
vincoli trasversali trovati, le decisioni prese da solo con la motivazione, e l'elenco delle
figlie — una riga ciascuna, con cosa consegna e da chi dipende. Poi `AskUserQuestion` con tre
opzioni: «Apri le issue» (Recommended), «Cambia qualcosa» (l'utente dice cosa, tu correggi e
richiedi), «Lascia stare» (non apri niente e ti fermi).

Se la roadmap è già stata approvata in questa conversazione — o è `/issue-flow:big-plan` senza
argomenti — salta il riassunto e la domanda e vai al passo 5.

### 5. Apri la madre

Segui `TEMPLATE.md`, il file accanto a questo. La sezione **Issue** a questo punto ha le righe
con un segnaposto al posto del numero — `- [ ] #(1) titolo — cosa consegna` — perché le figlie
non esistono ancora; il numero lo metti al passo 8. La madre si apre per prima perché le figlie
devono poterla citare dal primo momento.

```bash
glab issue create --title "<titolo>" --description-file "$SCRATCH/madre.md" --yes   # GitLab
gh   issue create --title "<titolo>" --body-file        "$SCRATCH/madre.md"         # GitHub
```

Il titolo della madre dice cosa ottiene il prodotto a progetto finito, come per ogni issue. Il
numero lo leggi dall'URL che il comando stampa.

### 6. Scrivi le figlie, un subagent per figlia

Un'invocazione del tool `Agent` con `subagent_type: "issue-flow:issue-writer"` **per ogni
figlia**. I writer leggono il codice e scrivono un file nello scratchpad, niente di più: non si
pestano i piedi, quindi **lanciali tutti insieme, in un solo messaggio**.

Il writer non ha visto la conversazione: **quello che non gli scrivi non esiste**. Nel prompt,
integrali e non riassunti:

- il numero della madre e le sue sezioni **Obiettivo**, **Architettura**, **Decisioni**,
  **Contesto** e **Fuori perimetro**;
- l'elenco completo delle figlie, con il segnaposto `#(k)`, il titolo e cosa consegna ognuna:
  il writer deve sapere cosa fanno le sorelle per non rifarlo e per dirlo nel suo fuori
  perimetro;
- la posizione della sua figlia — `#(3)`, terza di 5 — e **cosa troverà già fatto** quando toccherà a
  lei: i tipi, le interfacce, i file che le figlie prima avranno creato, con i nomi decisi;
- il branch di destinazione, i comandi di verifica e i file di documentazione ricavati al
  passo 2;
- se `${user_config.figma_file}` è configurato, l'id del file: la figlia che tocca il frontend
  avrà la fase Figma per prima;
- il percorso esatto del file in cui scrivere il corpo: `$SCRATCH/figlia-<k>.md`.

### 7. Controlla i corpi

Al ritorno dei writer, rileggi **ogni** file — il report di un subagent è un racconto, il file
è la prova:

- non è vuoto, e ha tutte le sezioni del template di `plan`, compresa «Come si aggiorna questa
  roadmap» nella variante della piattaforma giusta;
- in testa ha `- **Roadmap:** #<madre>` e, se ne ha, le righe `- **Dipende da:** #(k)`;
- le fasi sono da 5 a 8, con la verifica in penultima e la chiusura per ultima; le checkbox si
  contano con i `grep` di `TRACKER.md` §5;
- non fa il lavoro di una sorella, e non contraddice le decisioni della madre.

Se un writer ha segnalato un vincolo che la roadmap non prevedeva, **decidi tu** — con
l'utente, se cambia la scomposizione — e non lasciarlo risolto in silenzio dentro una figlia.
Se un corpo non regge, un writer **nuovo** con il difetto detto per esteso; mai correggere a
mano pezzi di ricognizione che non hai fatto.

### 8. Crea le figlie e allinea i riferimenti

Crea le figlie **nell'ordine della roadmap**, una alla volta, così i numeri crescono con
l'ordine di esecuzione. Il titolo è quello della roadmap; il numero lo leggi dall'URL stampato,
non lo deduci — su GitHub issue e pull request condividono la sequenza, e qualcun altro può
aprire una issue nel frattempo.

Poi i segnaposto diventano numeri:

- in ogni figlia che cita una sorella — `**Dipende da:** #(2)`, «nasce con #(2)», il fuori
  perimetro — `#(k)` diventa `#<numero>`;
- nella madre, la sezione **Issue** diventa `- [ ] #<numero> titolo — cosa consegna`.

Ogni riscrittura segue la regola di sempre: **rileggi il corpo dal server**, sostituisci,
controlla che il file non sia vuoto, rimandalo su (`TRACKER.md` §4). Alla fine, un
`grep -n '#([0-9]\+)'` su ogni corpo riletto non deve trovare segnaposto rimasti.

### 9. Consegna

In poche righe: il link della madre, l'elenco delle figlie con numero, titolo e link nell'ordine
di esecuzione, cosa hai trovato in ricognizione che la richiesta non prevedeva, le decisioni
prese da solo con la motivazione, e cosa è rimasto fuori. Chiudi con come si parte:
`/issue-flow:implement <madre>`, che prende da solo la prima figlia aperta, o
`/issue-flow:big-implement <madre>`, che le porta avanti tutte in sequenza. Non incollare le
issue nella risposta.

## Come si avanza nel progetto

Non con questa skill. Le figlie si eseguono **una alla volta, in ordine**, con il giro normale:

```
/issue-flow:implement <figlia>           # o <madre>: prende la prima figlia non ancora unita
/issue-flow:close <figlia>               # apre la MR/PR della figlia
/issue-flow:close <figlia> --chiudi      # a merge avvenuto: chiude la figlia e la spunta sulla madre
```

e poi la figlia successiva, che parte dal branch di destinazione con dentro il lavoro delle
precedenti. La casella della madre si spunta **quando la figlia è unita**, non quando è
implementata: lo fa `/issue-flow:close --chiudi`, che chiude anche la madre quando l'ultima
casella è spuntata.

Oppure tutte in una volta con `/issue-flow:big-implement <madre>`: lo stesso giro, una figlia
alla volta, sul branch della madre — ogni figlia nasce da lì e ci rientra con la sua MR/PR, che
`close` unisce da solo dopo i controlli di sempre. Alla fine la MR/PR della madre porta tutto
nel branch di destinazione, e la unisce l'utente; poi `/issue-flow:close <madre> --chiudi`.

Se durante l'esecuzione una figlia scopre che la roadmap non regge più — una decisione della
madre si rivela sbagliata, una figlia successiva va rifatta — il rimedio è correggere le issue
prima del codice: `/issue-flow:plan rivedi <n>` per la figlia, e la madre riscritta a mano con
la regola di sempre.
