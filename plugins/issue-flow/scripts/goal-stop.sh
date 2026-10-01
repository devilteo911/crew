#!/usr/bin/env bash
# Hook Stop di /issue-flow:implement e /issue-flow:big-implement: il «goal» della roadmap.
#
# Non lascia chiudere il turno finché una delle issue in lavorazione ha checkbox aperte nel Piano.
# Lo stato sta in <git-dir>/issue-flow/, mai committato:
#   goal     i numeri delle issue in lavorazione, uno per riga — uno solo per implement, tutte
#            le figlie del progetto e la madre per big-implement (la madre non ha Piano: contano
#            le caselle della sezione Issue, spuntate quando una figlia è unita nel suo branch);
#            senza, l'hook non fa nulla
#   in-volo  c'è un subagent al lavoro — di fase per implement, il runner della figlia per
#            big-implement — e la sua notifica risveglierà l'orchestratore
#   blocchi  quante volte di fila l'hook ha bloccato con lo stesso stato
#
# Nel dubbio lascia fermare (exit 0): un goal che non si può verificare non deve diventare
# un ciclo infinito.

MAX_BLOCCHI=5

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD
cd "$cwd" 2>/dev/null || exit 0

dir=$(git rev-parse --path-format=absolute --git-path issue-flow 2>/dev/null) || exit 0
[ -f "$dir/goal" ] || exit 0
[ -f "$dir/in-volo" ] && exit 0

avviso() { echo "issue-flow: $*" >&2; exit 0; }

numeri=$(grep -o '[0-9]\+' "$dir/goal")
[ -n "$numeri" ] || avviso "$dir/goal non contiene un numero di issue: goal ignorato"

# stessa scelta di TRACKER.md §0: il tracker lo dice il remote
remote=$(git remote get-url origin 2>/dev/null)

# somma le checkbox aperte di tutte le issue del goal; ricorda la prima che ne ha
aperte=0
prima=""
for numero in $numeri; do
  if [[ $remote == *github.com* ]]; then
    corpo=$(gh issue view "$numero" --json body --jq '.body' 2>/dev/null | sed 's/\r$//')
  else
    corpo=$(glab issue view "$numero" --output json 2>/dev/null | jq -r '.description // empty')
  fi
  [ -n "$corpo" ] || avviso "non riesco a leggere la issue #$numero dal tracker: goal non verificato"

  # solo le checkbox del Piano; senza una sezione Piano, tutto il corpo
  piano=$(awk '/^## /{dentro = ($0 ~ /^## Piano/)} dentro' <<<"$corpo")
  [ -n "$piano" ] || piano=$corpo
  n=$(grep -c '^[[:space:]]*- \[ \]' <<<"$piano")
  if [ "$n" -gt 0 ] && [ -z "$prima" ]; then
    prima=$numero
    fase=$(awk '/^### /{fase = substr($0, 5)} /^[[:space:]]*- \[ \]/{print fase; exit}' <<<"$piano")
  fi
  aperte=$((aperte + n))
done

if [ "$aperte" -eq 0 ] && [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  rm -f "$dir/goal" "$dir/blocchi"
  exit 0
fi

# contatore di sicurezza: se tra un blocco e l'altro non cambia niente, il turno sta girando
# a vuoto e continuare a bloccarlo non serve
stato="$(git rev-parse HEAD 2>/dev/null) $aperte"
volte=0
if [ -f "$dir/blocchi" ] && [ "$(head -1 "$dir/blocchi")" = "$stato" ]; then
  volte=$(sed -n 2p "$dir/blocchi")
fi
volte=$((volte + 1))
printf '%s\n%s\n' "$stato" "$volte" >"$dir/blocchi"
if [ "$volte" -gt "$MAX_BLOCCHI" ]; then
  rm -f "$dir/blocchi"
  avviso "#${prima:-$numeri} ferma da $MAX_BLOCCHI turni senza progressi: lascio fermare"
fi

if [ "$aperte" -eq 0 ]; then
  motivo="Roadmap tutta spuntata, ma ci sono modifiche non committate: committa l'ultima fase secondo /issue-flow:implement."
else
  motivo="Roadmap di #$prima non completa: $aperte checkbox aperte${fase:+, la prima in «$fase»}. Prosegui secondo /issue-flow:implement (o /issue-flow:big-implement, se stai portando avanti un progetto: il controllo della figlia che il runner ha riportato, poi un issue-runner nuovo per la successiva)."
fi
motivo+=" Se sei in uno dei casi di «Quando fermarsi davvero», o lasci una checkbox vuota per un motivo, rimuovi $dir/goal e spiega all'utente perché ti fermi."

jq -n --arg r "$motivo" '{decision: "block", reason: $r}'
