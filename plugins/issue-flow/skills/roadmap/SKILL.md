---
name: roadmap
description: "Propone la roadmap dei prossimi passi di un progetto leggendo la sua documentazione — i registri di research-flow se il repo li ha, altrimenti README, CLAUDE.md, docs, una ROADMAP.md precedente — più le issue aperte sul tracker e lo stato del codice. Ogni passo ha la sua fonte, il suo ordine e le sue dipendenze, ed è dimensionato come una issue. Approvata, la salva come ROADMAP.md nella radice del repo oppure la passa a /issue-flow:big-plan, che ne crea tutte le issue. Trigger: /issue-flow:roadmap, «quali sono i prossimi passi?», «proponi una roadmap», «cosa facciamo adesso?», «da dove ripartiamo?»."
argument-hint: "[focus facoltativo: un'area, un obiettivo, un traguardo]"
---

# /issue-flow:roadmap

`/issue-flow:plan` e `/issue-flow:big-plan` partono da una richiesta: qualcuno sa già cosa vuole
fare. Questa skill viene prima, quando la domanda è **cosa facciamo adesso**. Legge quello che il
progetto sa di sé — la documentazione, le issue aperte, il codice — e propone i prossimi passi in
ordine, ognuno con il motivo per cui sta lì e la fonte da cui viene.

La roadmap approvata ha due uscite, a scelta dell'utente:

- **un file**, `ROADMAP.md` nella radice del repo, da tenere e rileggere;
- **le issue**: la skill passa la roadmap a `/issue-flow:big-plan`, che ne fa una issue madre e
  una figlia per passo, ognuna scritta completa.

Leggi `${CLAUDE_PLUGIN_ROOT}/skills/plan/SKILL.md` — la skill `plan` di questo plugin — per
come si scrive e per la dimensione di una issue, e `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` per i
comandi delle due piattaforme. **Leggili prima del primo comando.**

## Usage

```
/issue-flow:roadmap                      # i prossimi passi del progetto, da tutta la documentazione
/issue-flow:roadmap <focus>              # solo un'area o un traguardo: «il frontend», «andare live»
```

## Il principio

**Ogni passo della roadmap ha una fonte che si può ricontrollare.** Un ID di un registro, una
sezione di un documento con il suo percorso, una issue, un `file:riga`. Quello che proponi di
tuo — un rischio che la documentazione non vede, un passo che manca fra due che ci sono — si può
proporre, ma si dichiara come **proposta nostra**, con il motivo: l'utente deve poter distinguere
quello che il progetto dice di sé da quello che ne deduci tu.

La conseguenza pratica: una roadmap non si scrive a memoria di quello che si è visto nella
conversazione. Si scrive dopo aver letto le fonti di questa sessione.

## Processo

### 0. Quale tracker, e risponde

Identico al passo 0 di `plan`. Qui però il tracker non è indispensabile: serve per sapere cosa è
già aperto, e per l'uscita «issue». Se non risponde e l'autenticazione è il problema, chiedi
all'utente di farla; se l'utente preferisce andare avanti senza, prosegui, dichiara nella
roadmap che le issue aperte non sono state guardate, e l'uscita «issue» non si offre.

### 1. Lavora come in plan mode, senza entrarci

Le stesse regole del passo 1 di `plan`: **mai `EnterPlanMode` né `ExitPlanMode`**, sola lettura
fino all'approvazione, bivi chiesti mano a mano con `AskUserQuestion`, l'approvazione con
`AskUserQuestion`, e **mai offrire di implementare**.

### 2. Le fonti

Si leggono in quest'ordine, e ognuna dice cosa si trova e dove.

#### a. research-flow, se il repo lo usa

Il segnale è il file `.research-flow.json` nella radice del repo. **Se non c'è, salta questa
sezione**: il plugin research-flow non è un requisito, e senza i suoi registri la roadmap si fa
con le fonti b–d.

Se c'è, la configurazione dice la cartella (`dir`), i nomi dei cinque registri e del documento
ufficiale (`ufficiale`). Sono la fonte principale, perché sono scritti apposta per dire cosa
sappiamo, cosa manca e cosa è da provare. Da ognuno serve una parte sola:

| documento | cosa ne prendi |
|---|---|
| ufficiale (`stato_progetto.md`) | §«Prossimi passi», §«Cosa manca», §«Cosa è da testare», §«Dove potremmo sbagliare», §«Cosa non abbiamo capito»; §«Strade scartate», per non riproporre quello che un esperimento ha già bocciato; la data in testa, **Aggiornato al** |
| da fare (`TODO`) | le voci aperte P0 e P1 per fase, «In corso» e le domande in «Da chiedere alle fonti» |
| esperimenti (`ESP`) | i proposti, con il loro criterio di successo |
| ipotesi (`IP`) | quelle da verificare che reggono una scelta in vigore, con l'impatto se sono sbagliate |
| dubbi (`DUB`) | gli aperti che toccano codice su cui i passi andranno a lavorare |

I registri possono essere lunghi: non leggerli per intero. Se il plugin research-flow è
installato, il suo script dà lo stato senza aprire i file:

```bash
RF=$(jq -r '.plugins["research-flow@research-flow"][0].installPath // empty' \
       ~/.claude/plugins/installed_plugins.json 2>/dev/null)
python3 "$RF/scripts/registri.py" riepilogo   # voci per registro e per stato
python3 "$RF/scripts/registri.py" check       # tra l'altro: l'ufficiale è più vecchio dei registri?
python3 "$RF/scripts/registri.py" find TODO-012   # una voce, chi la cita, il suo stato
```

Se `$RF` è vuoto o lo script manca, lavora sui file che la configurazione indica, con `grep`
sugli stati e sulle intestazioni di sezione: i registri sono markdown leggibili anche senza.

**Se l'ufficiale è più vecchio dei registri** — `check` lo segnala, o la data in testa è
anteriore alle ultime voci — i registri vincono: la roadmap parte da loro, lo dici nel
riassunto, e proponi `/research-flow:stato` per riallineare l'ufficiale. Non riscriverlo tu:
i documenti di research-flow li scrivono le skill di research-flow.

In un progetto esplorativo una parte dei prossimi passi non è codice: un esperimento, una misura,
una domanda a una fonte. Gli esperimenti e le misure che richiedono script o modifiche al codice
**sono** passi, e diventano issue come gli altri; le domande alle fonti e le attese (dati da
accumulare, una risposta che deve arrivare) no: vanno fra le **Attese**, e i passi che dipendono
da loro lo dicono.

#### b. La documentazione del progetto

Sempre, con o senza research-flow:

- `ROADMAP.md` nella radice, se c'è: è la roadmap di una volta precedente. **Confrontala con lo
  stato di oggi** — quali passi sono stati fatti (issue chiuse, codice presente), quali sono
  caduti, quali restano — e dillo nel riassunto;
- `CLAUDE.md` e `README.md`: l'obiettivo del progetto, le fasi o la roadmap se le dichiarano, i
  vincoli;
- `${user_config.docs_paths}` se configurati, altrimenti `docs/`, un `TODO.md`, un `CHANGELOG`
  se ci sono: per le cose annunciate e non ancora fatte.

#### c. Il tracker

Le issue aperte, con `--limit` alto su GitHub (`TRACKER.md` §5):

- le **madri** aperte — `**Tipo:** roadmap` in testa al corpo — con le figlie non ancora
  spuntate: è lavoro già pianificato. Non va riproposto: la roadmap lo cita come **già aperto**
  e parte da dopo, oppure ci si appoggia come dipendenza;
- le issue singole aperte: se un passo che stai per proporre ha già la sua issue, il passo la
  cita invece di duplicarla.
- **le issue che le fonti citano** — «in corso (#29)», «resta da unire #48» — si controllano
  sul tracker una per una: una fonte che dà in corso una issue già chiusa è un'incongruenza da
  segnalare, e il passo che ne dipendeva forse è già sbloccato. `registri.py check` non lo vede:
  controlla la coerenza dei registri fra loro, non con il tracker.

#### d. Il codice e la storia

Serve a verificare, non a inventare passi:

- `git log --oneline -30` e i branch aperti: su cosa si sta lavorando adesso;
- per ogni passo candidato, **controlla nel codice che non sia già fatto.** Un TODO rimasto
  aperto nel registro, una riga del README mai aggiornata, una issue dimenticata aperta sono il
  caso normale, non l'eccezione. Un passo che risulta già fatto non entra in roadmap: lo segnali
  nel riassunto, perché la fonte che lo dava da fare va corretta.

Non serve qui la ricognizione per `file:riga` di ogni fase: quella la fanno `big-plan` e i suoi
writer, se la roadmap diventa issue.

### 3. Il focus, se c'è

Con un argomento, la roadmap copre solo quell'area o quel traguardo. Le fonti si leggono lo
stesso tutte — un passo fuori focus può essere una dipendenza di uno dentro — ma in roadmap
entrano solo i passi del focus e le loro dipendenze dichiarate come tali.

Senza argomento, se le fonti indicano più direzioni che non stanno in una roadmap sola — due fasi
del progetto aperte insieme, due aree che non si toccano — chiedi con `AskUserQuestion` su quale
concentrarsi, con una riga per direzione e le fonti che la sostengono.

### 4. Costruisci la roadmap

Le regole:

- **un passo è una issue.** Ogni passo ha la dimensione di una issue di `plan`: un incremento
  che si unisce da solo, da 5 a 8 fasi. Se un passo è più grande, dividilo; se due sono piccoli e
  toccano la stessa cosa, uniscili. È la condizione perché `big-plan` possa farne una figlia per
  passo;
- **prima quello che toglie incertezza.** I P0, le ipotesi con impatto alto su cui altri passi
  si appoggiano, gli esperimenti il cui esito decide fra due strade, il modello dei dati prima di
  chi lo usa. Poi quello che ci si costruisce sopra;
- **l'ordine è esplicito e le dipendenze sono dichiarate**: la stessa catena lineare di
  `big-plan`, perché le issue si eseguiranno in sequenza;
- **i vincoli di esercizio pesano sull'ordine.** Un test che gira e non va interrotto, un
  ambiente che non si può riavviare, un congelamento prima di un rilascio: cercali nelle fonti e
  guarda quali passi li toccano — nel codice, non dal titolo. Se un vincolo blocca metà dei passi,
  come ordinarli è un bivio da chiedere all'utente, non una scelta da prendere da solo;
- **l'orizzonte si ferma al primo bivio che non si può decidere adesso.** Se un passo dipende
  dall'esito di un esperimento o dalla risposta di una fonte, la roadmap arriva fin lì e dopo
  scrive i due rami in una riga ciascuno, sotto **Dopo**. Pianificare in dettaglio oltre un esito
  che non si conosce è indovinare;
- **da 3 a 8 passi.** Meno di 3 non è una roadmap: con un passo solo proponi `/issue-flow:plan`,
  con due valuta se sono una issue sola. Più di 8 vuol dire che l'orizzonte è troppo lungo: i
  passi oltre l'ottavo vanno sotto **Dopo**;
- **per ogni passo**: un titolo che dice cosa cambia per chi usa il prodotto — come il titolo di
  una issue —, cosa consegna, perché sta lì con le fonti (`TODO-012`, `ESP-031`, `README.md`
  §Roadmap, `#45`, `backend/app/x.py:88`), da quale passo dipende, se chiude o rende verificabile
  qualcosa (un'ipotesi, un dubbio, un criterio di successo).

Tieni da parte, per il riassunto e per il file:

- **Attese**: le domande alle fonti, i dati da accumulare, le decisioni che spettano a qualcun
  altro, con i passi che ne dipendono;
- **Dopo**: quello che viene oltre l'orizzonte, una riga per voce;
- **Lasciato fuori**: quello che le fonti danno da fare e che non hai messo in roadmap, con il
  motivo (già fatto, superato da una decisione, fuori focus, priorità bassa). È la sezione che
  permette all'utente di dire «no, questo va dentro».

### 5. Presentala e fatti approvare

Scrivi in chat un riassunto:

- **le fonti lette**: se c'era research-flow e da quale data è l'ufficiale, la `ROADMAP.md`
  precedente e cosa ne resta, le issue aperte trovate; se hai letto documenti con modifiche non
  committate, dillo (`git status`), perché la roadmap poggia su quella versione;
- **dove siamo**, in tre o quattro righe;
- **i passi**, numerati, una riga ciascuno con cosa consegna, le fonti e la dipendenza;
- le **Attese**, il **Dopo** e il **Lasciato fuori**, brevi;
- le incongruenze trovate fra fonti e codice (passi già fatti ma aperti nei registri, issue
  dimenticate), perché qualcuno le corregga.

Poi `AskUserQuestion`, con queste opzioni — nella descrizione di ognuna scrivi in concreto cosa
succede dopo, con i numeri della roadmap:

- **«Crea le issue con big-plan»**: una madre con la roadmap e una figlia per passo, scritte da
  `big-plan`;
- **«Salva in ROADMAP.md»**: il file nella radice del repo, niente sul tracker;
- **«Cambia qualcosa»**: l'utente dice cosa, tu correggi e richiedi;
- **«Lascia stare»**: non scrivi niente e ti fermi.

Il **Recommended** va a «Crea le issue» quando tutti i passi sono lavoro concreto e deciso, a
«Salva in ROADMAP.md» quando la roadmap è soprattutto esplorativa — passi che aspettano esiti,
bivi vicini — e aprire issue adesso vorrebbe dire riscriverle presto. Se l'utente chiede tutte e
due, con la risposta libera, prima salvi il file e poi passi a `big-plan`. Se manca il tracker,
«Crea le issue» non si offre.

### 6a. Salva in `ROADMAP.md`

Il file è `ROADMAP.md` nella radice del repo (`git rev-parse --show-toplevel`), e segue
`TEMPLATE.md`, il file accanto a questo.

Se esiste già, l'hai letto al passo 2: si **riscrive**, non si appende — descrive i prossimi
passi di oggi, e la versione vecchia resta nella storia di git. Nel riassunto di consegna di'
cosa è cambiato rispetto a quella.

Non committare: il file resta nell'albero di lavoro, e dillo all'utente. Se il progetto usa
research-flow e la roadmap diverge da §«Prossimi passi» dell'ufficiale, proponi
`/research-flow:stato` per allinearlo; non toccare tu i suoi documenti.

### 6b. Crea le issue con `big-plan`

Carica la skill `issue-flow:big-plan` con il tool `Skill`, nella stessa conversazione. Da quel
momento vale `big-plan`, che sa di arrivare da qui (la sua sezione «Quando arrivi da
`/issue-flow:roadmap`») e riusa quello che hai già fatto: il tracker verificato, le fonti lette,
la roadmap approvata come bozza della divisione in figlie.

Nel passaggio le devono arrivare, già scritti in conversazione nel riassunto del passo 5:

- l'obiettivo della roadmap, che diventa l'**Obiettivo** della madre;
- i passi con titolo, cosa consegna, fonti e dipendenze: una figlia per passo;
- **Attese**, **Dopo** e **Lasciato fuori**, che finiscono nel **Contesto** e nel **Fuori
  perimetro** della madre;
- se la roadmap viene da research-flow, la corrispondenza fra passi e voci dei registri
  (`passo 2 ← TODO-012, ESP-031`), perché la consegna dica quali voci segnare `in corso` con la
  loro issue.

### 7. Consegna

Per l'uscita file: il percorso del file, cosa è cambiato rispetto alla roadmap precedente, le
incongruenze trovate fra fonti e codice, e come si parte — `/issue-flow:plan` sul primo passo, o
`/issue-flow:roadmap` di nuovo con «crea le issue» quando i bivi saranno decisi.

Per l'uscita issue la consegna la fa `big-plan`.

Non incollare la roadmap nella risposta finale: l'utente l'ha già vista al passo 5, e il file o
la madre sono dove si rilegge.

## Come si scrive

Come in `plan`: prosa densa, italiano, identificatori in originale, niente stime in ore o giorni,
niente `TBD`. In più:

- le fonti si citano **sempre** con il loro riferimento preciso — ID, percorso e sezione, numero
  di issue — mai «come dice la documentazione»;
- **proposta nostra** in grassetto dove un passo o una motivazione non vengono da una fonte;
- i passi di un progetto esplorativo dicono **cosa si saprà** dopo, non solo cosa si farà: «dopo
  questo passo sappiamo se IP-014 regge» vale più di «implementare il backtest».
