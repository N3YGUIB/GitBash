#!/bin/bash

base="$HOME/gitbash"
projets=()
for d in "$base"/*/; do
  [[ -d "$d/.git" ]] && projets+=("$(basename "$d")" "")
done

if (( ${#projets[@]} == 0 )); then
  echo "Aucun projet local trouvé." >&2
  exit 2
fi

logo=$(printf '%-30s%24s' "Mettre à jour un dépôt" "LaPlateforme_")

projet=$(dialog --no-shadow --no-collapse \
  --ok-label "Suivant" --cancel-label "Précédent" \
  --menu "$logo" 20 60 10 \
  "${projets[@]}" \
  3>&1 1>&2 2>&3)
code=$?
clear
case "$code" in
  0) ;;
  1) exit 2 ;;
  *) echo "Erreur de dialog (code $code)" >&2; exit 1 ;;
esac

if [[ ! "$projet" =~ ^[A-Za-z0-9._-]{1,100}$ ]]; then
  echo "Nom de projet invalide." >&2
  exit 1
fi

cd "$base/$projet" || exit 1
changements=$(git status --short)

if [[ -z "$changements" ]]; then
  echo "Rien à envoyer : aucun changement." >&2
  exit 2
fi

logo=$(printf '%-30s%24s' "Message du commit" "LaPlateforme_")


message=$(dialog --no-shadow --no-collapse \
  --ok-label "Envoyer" --cancel-label "Précédent" \
  --inputbox "Message du commit :" 10 60 "Initial Commit" \
  3>&1 1>&2 2>&3)
code=$?
clear
case "$code" in
  0) ;;
  1) exit 2 ;;
  *) echo "Erreur de dialog (code $code)" >&2; exit 1 ;;
esac

if [[ -z "$message" ]] || (( ${#message} > 100 )) || [[ "$message" =~ [[:cntrl:]] ]]; then
  echo "Message invalide (1 à 100 caractères)." >&2
  exit 1
fi

git add -A || exit 1
git commit -q -m "$message" || exit 1
git push -q || { echo "Échec du push." >&2; exit 1; }

echo "Projet $projet mis à jour sur GitHub."
