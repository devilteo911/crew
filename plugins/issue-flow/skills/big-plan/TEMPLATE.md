# TEMPLATE — il corpo della issue madre

La madre non si implementa: tiene la roadmap del progetto e l'elenco delle figlie che la
eseguono. Il piano con le fasi e le checkbox di lavoro sta nelle figlie, che seguono
`skills/plan/TEMPLATE.md`.

Il titolo sta fuori dal corpo: una frase breve in minuscolo che dice cosa ottiene il prodotto a
progetto finito.

Le sezioni sono queste, in quest'ordine, tutte obbligatorie tranne dove detto. Il testo fra
parentesi quadre è istruzione per chi scrive e non va copiato. Dove il template dà due
varianti — GitLab e GitHub — ne copi una sola, quella del repo, e usi la sua parola (merge
request o pull request) senza barre.

---

- **Tipo:** roadmap
- **Stato:** da fare

## Obiettivo

[Due o tre paragrafi. Cosa succede oggi e perché non basta, con il riferimento al codice che
produce quel comportamento; cosa sarà vero quando l'ultima figlia sarà unita. È la frase che
ogni figlia deve poter ricondurre a sé.]

## Architettura

[Come si incastrano i pezzi a progetto finito: i moduli toccati, i confini fra loro, i dati che
passano. Un diagramma ASCII se aiuta. Nomina i file d'ingresso con `percorso/file.ts:42`
verificati, e i file che nasceranno con il nome che avranno.]

## Decisioni

[Una voce per decisione presa — con l'utente o da solo — con la sua motivazione. Sono le scelte
che le figlie non devono rimettere in discussione: il writer di ogni figlia le riceve e le
rispetta.]

## Contesto

[I fatti scoperti in ricognizione che valgono per più figlie, un paragrafo con un **titolo in
grassetto** ciascuno, come nel template di `plan`: i numeri misurati con detto dove, i vincoli
trasversali — schema dei dati, campi speculari, cache, compatibilità con dati e client già in
giro — con il perché.]

## Issue

[Le figlie in ordine di esecuzione. Alla creazione della madre al posto del numero c'è il
segnaposto `#(k)`; diventa `#<numero>` quando le figlie sono aperte.]

- [ ] #13 [titolo] — [cosa consegna, in una riga]
- [ ] #14 [titolo] — [cosa consegna] · dipende da #13
- [ ] #15 [titolo] — [cosa consegna] · dipende da #14

## Come si avanza

[Sezione obbligatoria, si copia com'è.]

Le figlie si eseguono **una alla volta, nell'ordine qui sopra**, ognuna con il suo branch e la
sua merge request — pull request su GitHub:

```
/issue-flow:implement <figlia>        # o il numero di questa issue: prende la prima figlia aperta
/issue-flow:close <figlia>            # apre la merge request della figlia
/issue-flow:close <figlia> --chiudi   # a merge avvenuto: chiude la figlia e la spunta qui
```

Oppure tutte in una volta, senza aspettare i merge, con `/issue-flow:big-implement <questa
issue>`: questa issue ha il suo branch, ogni figlia nasce da lì e ci rientra con una merge
request unita in automatico dopo i controlli di `/issue-flow:close`; alla fine la merge request
di questa issue porta tutto il progetto nel branch di destinazione, e la unisce solo chi la
approva. A merge avvenuto, `/issue-flow:close <questa issue> --chiudi`.

Una casella di questa issue si spunta **quando la figlia è unita** — nel branch di
destinazione, o nel branch di questa issue — non quando è implementata. La figlia successiva
parte da lì, con dentro il lavoro delle precedenti.

Quando l'ultimo lavoro arriva nel branch di destinazione — con l'ultima figlia, o con la merge
request di questa issue — questa issue si chiude, e lo **Stato:** diventa
`chiusa — completata il GG/MM/AAAA`. Fino ad allora è `in corso — k di M issue unite`.

Se durante l'esecuzione la roadmap smette di reggere — una decisione si rivela sbagliata, una
figlia va divisa o rifatta — si correggono le issue prima del codice: questa, rileggendola dal
server prima di riscriverla, e le figlie toccate con `/issue-flow:plan rivedi <numero>`.

## Fuori perimetro

[Elenco puntato di quello che il progetto **non** fa, con il perché: le estensioni naturali che
qualcuno potrebbe aggiungere di sua iniziativa in una delle figlie.]
