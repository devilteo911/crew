# TEMPLATE — il file ROADMAP.md

Il file che `/issue-flow:roadmap` scrive nella radice del repo quando l'utente sceglie di
salvare la roadmap invece di aprire le issue. Si riscrive per intero ogni volta: descrive i
prossimi passi di oggi, e le versioni precedenti stanno nella storia di git.

Le sezioni sono queste, in quest'ordine. Il testo fra parentesi quadre è istruzione per chi
scrive e non va copiato. Le sezioni segnate facoltative si omettono se sono vuote.

---

# Roadmap

**Aggiornata al GG-MM-AAAA** da `/issue-flow:roadmap`[ — focus: <focus>, se c'era].

## Dove siamo

[Tre o quattro righe: cosa c'è oggi, cosa si sta facendo, qual è il prossimo traguardo.
Ogni affermazione con la sua fonte.]

**Fonti lette:** [l'elenco: i documenti con il percorso — per research-flow l'ufficiale con la
sua data e i registri —, la ROADMAP.md precedente se c'era, le issue aperte guardate (o «tracker
non consultato»).]

## Prossimi passi

[In ordine di esecuzione. Ogni passo ha la dimensione di una issue, e si può aprire con
`/issue-flow:plan` copiando il suo titolo e la sua descrizione.]

### 1. [titolo: cosa cambia per chi usa il prodotto]

- **Consegna:** [cosa esiste a passo finito, in una o due righe]
- **Perché adesso:** [il motivo della posizione, con le fonti: `TODO-012`, `ESP-031`,
  `README.md` §Roadmap, `#45`, `percorso/file.py:88`. **Proposta nostra** se non viene da una
  fonte]
- **Dopo sappiamo:** [facoltativa: cosa si saprà — l'ipotesi che regge o cade, il criterio di
  successo che si misura]
- **Dipende da:** [il passo, un'attesa, una issue già aperta, oppure «niente»]

### 2. [titolo]

[…]

## Già aperto

[Facoltativa. Le issue e le madri già sul tracker su cui questa roadmap si appoggia, con il
numero e cosa manca per chiuderle.]

## Attese

[Facoltativa. Quello che non è lavoro nostro ma blocca o condiziona dei passi: domande alle
fonti, dati da accumulare, decisioni di qualcun altro. Una riga ciascuna, con i passi che ne
dipendono.]

## Dopo

[Facoltativa. Quello che viene oltre l'orizzonte, una riga per voce. Dopo un bivio, i due rami:
«se ESP-031 è positivo → …; se è negativo → …».]

## Lasciato fuori

[Quello che le fonti danno da fare e questa roadmap non contiene, con il motivo: già fatto (e la
fonte da correggere), superato, fuori focus, priorità bassa.]

## Incongruenze trovate

[Facoltativa. Fonti che non corrispondono al codice o al tracker: voci aperte già fatte, issue
dimenticate, documenti più vecchi dei registri. Ognuna con chi deve correggerla.]
