# Issue Flow

Dalla richiesta alla merge request passando per una issue che contiene il piano **e** la
roadmap che lo esegue. Sei skill che si passano il lavoro, su **GitLab** (`glab`) o **GitHub**
(`gh`) indifferentemente: la piattaforma si deduce dal remote.

Il principio che tiene insieme tutto: *la issue deve essere eseguibile da un agente che non ha
assistito alla conversazione.* Da lì discendono i riferimenti `file.ts:42` verificati, i numeri
misurati e non stimati, le decisioni scritte con la loro motivazione, il fuori perimetro
esplicito.

| skill | cosa fa |
|---|---|
| `/issue-flow:roadmap` | **cosa facciamo adesso**: legge la documentazione del progetto — i registri di [research-flow](https://github.com/MatteoSid/Research-Master-Skills) se ci sono, se no README, CLAUDE.md, docs — più le issue aperte e il codice, e propone i prossimi passi con le loro fonti; approvata, la salva in `ROADMAP.md` o ne crea le issue con `big-plan` |
| `/issue-flow:plan` | **una feature**: ricognizione nel codice, bivi chiesti all'utente, poi apre la issue con dentro piano e roadmap a checkbox |
| `/issue-flow:big-plan` | **uno sviluppo grosso**: definisce la roadmap del progetto in una issue madre e la divide in issue figlie, ognuna scritta completa da un subagent |
| `/issue-flow:implement` | esegue la roadmap una fase per subagent, spunta le caselle mano a mano, un commit per fase; lavora come un `/goal` e non si ferma finché la roadmap non è completa; sulla madre prende la prima figlia aperta |
| `/issue-flow:big-implement` | porta avanti tutte le figlie di una madre in una volta sul branch della madre: una alla volta, in ordine, ognuna affidata a un subagent che fa il giro di `implement` e di `close`, che la unisce da sola nel branch della madre; alla fine apre la MR/PR della madre, che unisci tu |
| `/issue-flow:close` | verifica l'albero finale, apre la MR/PR, e a merge avvenuto chiude la issue e la spunta sulla madre; la figlia di un progetto con il branch della madre la unisce lì da sola |

Più tre subagent: `issue-flow:issue-phase`, che esegue una singola fase e non può committare né
toccare la issue — quello lo fa l'orchestratore, dopo aver verificato l'output vero —;
`issue-flow:issue-runner`, che per `big-implement` porta una figlia dal branch al merge nel
branch della madre, orchestrandone le fasi con un `issue-phase` ciascuna, così il contesto della
sessione principale resta quello del progetto e non si riempie delle fasi di tutte le figlie; e
`issue-flow:issue-writer`, che scrive il corpo di una issue figlia di `big-plan` in un file e non
può creare issue: le crea l'orchestratore, in ordine, dopo averle controllate.

## Installazione

```
/plugin marketplace add devilteo911/crew
/plugin install issue-flow@crew
```

Il `marketplace add` clona con le credenziali git della macchina, quindi va bene anche l'SSH:
`git@github.com:devilteo911/crew.git`. Da un clone locale è
`claude plugin marketplace add <percorso del clone>`.

Serve `glab` o `gh` installato e autenticato — le skill lo controllano al passo 0 e si fermano
con il comando da lanciare se manca. Il login è interattivo e Claude non può farlo. Serve
anche `jq`, che usa l'hook di `implement`.

## Configurazione

Tutte le opzioni sono facoltative: senza, le skill ricavano quello che serve dal repo. Si
impostano quando abiliti il plugin, o con `claude plugin install --config chiave=valore`.

| opzione | default | a cosa serve |
|---|---|---|
| `default_branch` | dal repo | il branch in cui vengono unite le MR/PR |
| `branch_prefix` | `issue-` | il branch di lavoro è `<prefisso><numero della issue>` |
| `verify_commands` | dal progetto | i comandi che devono passare prima di chiudere una fase |
| `docs_paths` | dal progetto | la documentazione che la fase di chiusura rilegge |
| `figma_file` | vuoto | l'id del file Figma da allineare prima del codice; vuoto = nessuna fase Figma |

Quando `verify_commands` e `docs_paths` non sono impostati, `/issue-flow:plan` li ricava in
ricognizione — script di `package.json`, target del `Makefile`, `pyproject.toml`, job della CI
— e li **scrive nella issue**, così la fase di verifica ha comandi veri invece di un generico
«esegui i test». Se il progetto ha un `CLAUDE.md`, di solito li dice già.

## Come si lavora

Per sapere da dove ripartire:

```
/issue-flow:roadmap                  →  propone i prossimi passi, ognuno con la sua fonte
                                        approvata: ROADMAP.md nella radice, oppure
                                        big-plan ne fa la madre e una figlia per passo
/issue-flow:roadmap il frontend      →  solo i passi di un'area o di un traguardo
```

`roadmap` legge i registri di research-flow quando il repo ha `.research-flow.json` — lo stato
del progetto, i TODO aperti, gli esperimenti proposti, le ipotesi da verificare — ma research-flow
non è un requisito: senza, si basa su `ROADMAP.md` precedente, `CLAUDE.md`, `README.md`, i
`docs_paths` e le issue aperte. Ogni passo cita la fonte da cui viene; quello che la
documentazione non dice e `roadmap` propone di suo è segnato come tale. L'orizzonte si ferma al
primo bivio che dipende da un esito non ancora noto: oltre, i due rami in una riga.

Per una feature:

```
/issue-flow:plan aggiungere il filtro per data alla lista        →  apre la issue #12
/issue-flow:implement 12                                         →  branch issue-12, un commit per fase
/issue-flow:close 12                                             →  apre la MR/PR
/issue-flow:close 12 --chiudi                                    →  a merge avvenuto, chiude la issue
```

Per uno sviluppo che non sta in una issue:

```
/issue-flow:big-plan sistema di notifiche con preferenze utente  →  madre #20, figlie #21 #22 #23
/issue-flow:implement 20                                         →  prende la prima figlia aperta, #21
/issue-flow:close 21                                             →  apre la MR/PR di #21
/issue-flow:close 21 --chiudi                                    →  chiude #21 e la spunta su #20
/issue-flow:implement 20                                         →  ora tocca a #22, e così via
```

Le figlie si eseguono una alla volta, ognuna con il suo branch e la sua MR/PR, e ognuna parte
dal branch di destinazione con dentro le precedenti già unite. Oppure tutte in una volta, senza
aspettare i merge:

```
/issue-flow:big-implement 20      →  branch issue-20 da main; #21, #22, #23 nascono da issue-20
                                     e ci rientrano da sole; poi la MR/PR issue-20 → main
/issue-flow:close 20 --chiudi     →  dopo che hai unito la MR/PR della madre: chiude #20
```

Ogni figlia passa per `close` come sempre — verifica sull'albero finale, documentazione, MR/PR —
ma verso il branch della madre, e lì il plugin la unisce da solo: è il cantiere del progetto,
non il prodotto. Al branch di destinazione arriva solo la MR/PR della madre, e quella non la
unisce mai il plugin: la approvi e la unisci tu. Non serve sapere in anticipo quale
delle due usare: `/issue-flow:plan` controlla sempre se la richiesta sta in una issue, e quando
non ci sta si ferma, avvisa con i numeri misurati e una bozza di divisione, e propone come
proseguire — passare a `big-plan` (che riparte dalla ricognizione già fatta), aprire solo la
prima issue, restringere il perimetro, o tenere comunque una issue sola.

Ognuna riparte da sola dopo un `/clear`: lo stato sta nelle checkbox della issue, non nella
conversazione. `/issue-flow:implement` senza numero lo deduce dal branch corrente.

`/issue-flow:implement` e `/issue-flow:big-implement` non hanno bisogno di `/goal`: portano con
sé un hook `Stop` (`scripts/goal-stop.sh`) che a ogni fine turno rilegge la issue dal tracker e rimanda al
lavoro finché nel Piano resta una casella aperta o l'ultima fase non è committata. Si ferma
prima solo per una decisione esplicita — una fase fallita due volte, una scelta che la issue
non ha preso — e lo dice. Con `big-implement` il goal copre tutte le figlie del progetto e la madre, fino all'ultimo
merge nel branch della madre. Lo
stato del goal sta in `.git/issue-flow/`, fuori dai commit.

## Le tre regole che il plugin non negozia

**Si spunta mano a mano.** Alla fine di ogni fase, nello stesso commit che la porta — non a
lavoro finito. Una roadmap che non dice il proprio stato non serve a niente, e una che mente
è peggio di nessuna roadmap: se una decisione cambia, si riscrive la riga invece di spuntarla.

**Il corpo si rilegge dal server prima di riscriverlo.** L'update sostituisce l'intero campo e
non fa merge: partire da una copia tenuta in conversazione cancella le caselle che qualcuno ha
spuntato dalla pagina nel frattempo.

**La MR/PR si apre e non si merga.** Il merge lo chiede l'utente, sempre — nemmeno con le
pipeline verdi.

## GitLab e GitHub

`TRACKER.md`, nella cartella del plugin, ha la corrispondenza completa dei comandi e le
differenze che mordono: il campo del corpo che si chiama `description` di qua e `body` di là,
il `--limit` di `gh issue list` fermo a 30, `task_completion_status` che esiste solo su GitLab,
i CRLF nei corpi scritti dalla web di GitHub, `gh pr create` che non ha `--related-issue`.

## Licenza

MIT.
