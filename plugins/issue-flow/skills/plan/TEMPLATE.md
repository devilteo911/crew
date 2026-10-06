# TEMPLATE — il corpo di una issue

Il titolo sta fuori dal corpo: una frase breve in minuscolo che dice cosa cambia per chi usa
il prodotto.

Le sezioni sono queste, in quest'ordine, tutte obbligatorie tranne dove detto. Il testo
fra parentesi quadre è istruzione per chi scrive e non va copiato.

La issue vive su **una** piattaforma: dove il template dà due varianti — GitLab e GitHub —
ne copi una sola, quella del repo, e usi la sua parola (merge request o pull request) senza
barre. Quale sia lo dice `TRACKER.md`.

---

- **Stato:** da fare
- **Branch previsto:** `issue-<numero>`
- **Roadmap:** #<numero della madre>   [solo per le figlie di `/issue-flow:big-plan`]
- **Dipende da:** #<numero>            [solo per le figlie, una riga per sorella da cui dipende]

## Obiettivo

[Due o tre paragrafi. Il primo dice cosa succede oggi e perché non basta — concreto, con il
riferimento al codice che produce quel comportamento. L'ultimo dice, in una frase sola, cosa
succederà dopo. Niente elenco di file: quello viene dopo.]

## Contesto

[La parte che rende la issue eseguibile da chi non ha assistito alla conversazione. Sono
paragrafi con un **titolo in grassetto** ciascuno, uno per fatto scoperto in ricognizione.
Ci vanno, quando esistono:]

**Quanto materiale c'è.** [I numeri misurati, con detto dove: «847 righe in `src/store.ts`»,
«la funzione ha 23 chiamanti», «copertura sui record esistenti: 886 su 886».]

**Cosa c'è già e non stiamo usando.** [Campi che arrivano fino all'interfaccia e non vengono
mostrati, dati calcolati e poi buttati via. È quasi sempre la parte che riduce il lavoro.]

**Il vincolo tecnico non ovvio.** [Il tipo che una serializzazione non digerisce, la cache che
si invaliderebbe, l'import che creerebbe un ciclo, il campo speculare fra backend e frontend
che va cambiato insieme. Con il perché, non solo il cosa.]

**Compatibilità con quello che esiste già.** [Quali dati, risposte in cache o client vecchi
devono continuare a funzionare, e cosa mostreranno.]

**Cosa resta com'è, e perché.** [Il codice adiacente che si è tentati di sistemare e che
questa issue non tocca — con il motivo per cui non lo tocca.]

## Piano

[Le fasi. Ognuna è un `###`, con un titolo che dice cosa fa, e sotto: una riga che nomina i
file toccati, poi le checkbox. Le fasi obbligate — verifica in penultima, chiusura per ultima,
e il Figma per primo se il progetto ne ha uno configurato — sono descritte in `SKILL.md`.]

### Fase 1 — [titolo]

`percorso/del/file.ts`.

- [ ] [checkbox atomiche, imperative, che nominano file e riga]

**Fatto quando:** [l'osservazione che prova che la fase è finita.]

[...le altre fasi...]

### Fase N-1 — Verifica

- [ ] [i test nuovi, detti per quello che devono provare, non per come si chiamano]
- [ ] [i comandi di verifica del progetto, uno per checkbox, con detto quale esito ci si
      aspetta: «`npm test` verde, i 214 test di prima continuano a passare»]
- [ ] [la prova a mano: cosa si apre, cosa si fa, cosa si deve vedere — in concreto]
- [ ] [se tocca l'interfaccia: da tastiera, a 390 di larghezza, accessibilità pulita]
- [ ] [se ci sono dati o client vecchi: uno di quelli si rilegge senza errori]

### Fase N — Chiusura

- [ ] `<file di documentazione>`: [cosa va riscritto, non «aggiornare la doc»]
- [ ] commit sul branch della issue

[La MR/PR non va messa fra le checkbox: la apre `/issue-flow:close <numero>` dopo l'ultima
fase, e non la si merga — il merge lo chiede l'utente.]

## Come si aggiorna questa roadmap

[Sezione obbligatoria, si copia com'è.]

Le caselle qui sopra sono spuntabili: il tracker le conta e mostra l'avanzamento in testa
alla issue. **Vanno spuntate mano a mano**, alla fine di ogni pezzo di lavoro e non a lavoro
finito, nello stesso commit che porta quel pezzo. Chi riprende in mano la issue deve poter
capire dallo stato delle caselle a che punto è, senza chiedere a nessuno.

Se durante l'implementazione una decisione cambia, si riscrive la riga della roadmap invece
di spuntarla e basta: una roadmap che mente è peggio di nessuna roadmap.

Da riga di comando, rileggendo sempre la versione sul server prima di riscriverla — l'update
sostituisce l'intero corpo e non fa merge:

[Copia solo il blocco della piattaforma di questo repo.]

```bash
# GitLab
glab issue view <numero> --output json --jq '.description' > roadmap.md
glab issue update <numero> --description-file roadmap.md
```

```bash
# GitHub
gh issue view <numero> --json body --jq '.body' > roadmap.md
sed -i 's/\r$//' roadmap.md
gh issue edit <numero> --body-file roadmap.md
```

A lavoro finito: tutte le caselle spuntate, poi `/issue-flow:close <numero>` apre la merge
request — la pull request su GitHub — e porta lo **Stato:** a `in revisione — !<numero MR>` su
GitLab, `in revisione — #<numero PR>` su GitHub. A merge avvenuto,
`glab issue close <numero>` o `gh issue close <numero>`, e lo **Stato:** diventa
`chiusa — unita il GG/MM/AAAA`. Su GitHub la issue può essersi già chiusa da sola: la PR porta
`Closes #<numero>` e il merge la chiude.

## Fuori perimetro

[Elenco puntato di quello che questa issue **non** fa, con il perché. Ci vanno soprattutto le
cose che sarebbero poco lavoro e che qualcuno potrebbe aggiungere di sua iniziativa: dirle
qui è il modo per non farsele trovare implementate.]
