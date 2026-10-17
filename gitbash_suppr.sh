#!/bin/bash

#---------------------------------- Token github -----------------------------------

TOKEN=$(cat ~/gitbash/token_github)

#-------------------------------------- login ---------------------------------

owner=$(curl -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user | jq -r '.login // empty')

if [[ -z "$owner" ]]; then
  echo "Token invalide : impossible de récupérer le login." >&2
  exit 1
fi

# ---------------------------- recupere les dêpots Github ----------------------

corps=$(mktemp)
trap 'rm -f "$corps"' EXIT

code=$(curl -s -o "$corps" -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/user/repos?per_page=100&affiliation=owner")

if [[ "$code" != "200" ]]; then
  echo "Échec ($code) : $(jq -r '.message // "pas de message"' "$corps")" >&2
  exit 1
fi

mapfile -t repos < <(jq -r '.[].name' "$corps")

if (( ${#repos[@]} == 0 )); then
  echo "Aucun dépôt trouvé." >&2
  exit 1
fi

#----------------------------- Tableau Checklist -------------------------------

OPTIONS=()
for r in "${repos[@]}"; do
  OPTIONS+=("$r" "" off)
done

#----------------------------- Theme et logo -----------------------------------

theme="$(dirname "$0")/gitbash.dialogrc"
[[ -f "$theme" ]] && export DIALOGRC="$theme"

#----------------------------Formulaire avec Dialog -----------------------------

while true; do

  logo=$(printf '%-30s%24s' "Supprimer des dépôts" "LaPlateforme_")

  reponse=$(dialog --no-shadow --no-collapse --separate-output \
    --ok-label "Suivant" --cancel-label "Précédent" \
    --checklist "$logo" 28 60 13 \
    "${OPTIONS[@]}" \
    3>&1 1>&2 2>&3)
  code=$?
  clear
  case "$code" in
    0)   ;;
    1)   exit 2 ;;
    *)   echo "Erreur de dialog (code $code)" >&2; exit 1 ;;
  esac

  if [[ -z "$reponse" ]]; then
    echo "Aucun dépôt sélectionné." >&2
    exit 1
  fi

  mapfile -t choix <<< "$reponse"

portee=$(dialog --no-shadow --no-collapse \
  --ok-label "Suivant" --cancel-label "Précédent" \
  --radiolist "$logo" 14 60 3 \
  1 "Supprimer sur GitHub seulement" off \
  2  "Supprimer en local seulement"   off \
  3  "Supprimer sur GitHub et en local" on \
  3>&1 1>&2 2>&3)
code=$?
clear
case "$code" in
  0) ;;
  1) continue ;;
  *) echo "Erreur de dialog (code $code)" >&2; exit 1 ;;
esac

  liste=$(printf '%s\\n' "${choix[@]}")
  logo=$(printf '%-30s%24s' "Confirmation" "LaPlateforme_")

  dialog --no-shadow --no-collapse \
    --ok-label "Supprimer" --cancel-label "Précédent" \
    --yesno "$logo\n\nSupprimer définitivement :\n\n$liste" 20 60
  code=$?
  clear
  case "$code" in
    0) break ;;
    1) continue ;;
    *) echo "Erreur de dialog (code $code)" >&2; exit 1 ;;
  esac
done

#-------------------------------- Verif des noms -------------------------------------

for nom in "${choix[@]}"; do
  if [[ ! "$nom" =~ ^[A-Za-z0-9._-]{1,100}$ ]] || [[ "$nom" == "." || "$nom" == ".." ]]; then
    echo "Nom invalide : $nom" >&2
    exit 1
  fi
done

# --- Portée choisie ---

case "$portee" in
  1|3) faire_github=true ;;
  *)               faire_github=false ;;
esac
case "$portee" in
  2|3)  faire_local=true ;;
  *)               faire_local=false ;;
esac

#------------------------------- Suppression -----------------------------------------

base="$(dirname "0")"
supprimes=()

for nom in "${choix[@]}"; do
  if [[ "$faire_github" == true ]]; then
    code=$(curl -s -o "$corps" -w "%{http_code}" \
      -X DELETE "https://api.github.com/repos/$owner/$nom" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json")
    case "$code" in
      204) echo "$nom supprimé sur GitHub."; supprimes+=("$nom") ;;
      403) echo "Refusé pour $nom : droit de suppression manquant." >&2 ;;
      404) echo "$nom introuvable sur GitHub." >&2 ;;
      *)   echo "Échec pour $nom ($code) : $(jq -r '.message // "pas de message"' "$corps")" >&2 ;;
    esac
  else
    supprimes+=("$nom")
  fi
done

if [[ "$faire_local" == true ]]; then
  for nom in "${supprimes[@]}"; do
    dossier="${base:?}/$nom"
    if [[ -d "$dossier/.git" && ! -L "$dossier" ]]; then
      rm -rf -- "$dossier" && echo "Dossier local $nom supprimé."
    else
      echo "Dossier local $nom absent ou pas un dépôt Git : ignoré." >&2
    fi
  done
fi
