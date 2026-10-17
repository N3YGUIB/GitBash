#!/bin/bash

#---------------------------------- Token github -----------------------------------

TOKEN=$(cat ~/gitbash/token_github)

#------------------------------- Recupere les infos Github ------------------------

profil=$(curl -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user)

owner=$(jq -r '.login // empty' <<< "$profil")
gh_nom=$(jq -r '.name // empty' <<< "$profil")
gh_id=$(jq -r '.id // empty' <<< "$profil")

if [[ -z "$owner" ]]; then
  echo "Token invalide : impossible de récupérer le login." >&2
  exit 1
fi

git_nom=$(git config --get user.name || true)
git_mail=$(git config --get user.email || true)
git_nom="${git_nom:-${gh_nom:-$owner}}"
git_mail="${git_mail:-${gh_id}+${owner}@users.noreply.github.com}"

#--------------------------- Sugestion formulaire ----------------------------

nom="gitbash"
jobs=8
collabs="thierry-rami"
descript="Readme"

# ----------------------------- Formulaire avec dialog ------------------------------------

theme="$(dirname "$0")/gitbash.dialogrc"
[[ -f "$theme" ]] && export DIALOGRC="$theme"

logo=$(printf '%-30s%24s' "Créer un dépôt github" "LaPlateforme_")

#boucle while pour pouvoir utiliser le boutton précédent
while true; do
reponse=$(dialog --no-shadow --no-collapse \
  --ok-label "Créer" --cancel-label "Précédent" \
  --form "$logo" 28 60 13 \
  "Nom du projet :"   1 1 "$nom" 1 20 25 100 \
  "Nombre de jobs :"  3 1 "$jobs" 3 20 25 3 \
  "Collaborateur 1 :" 5 1 "" 5 20 25 39 \
  "Collaborateur 2 :" 7 1 "" 7 20 25 39 \
  "Collaborateur 3 :" 9 1 "" 9 20 25 39 \
  "Collaborateur 4 :" 11 1 "$collabs" 11 20 25 39 \
  "Description :" 13 1 "$descript" 13 20 25 200 \
  3>&1 1>&2 2>&3)
code=$?
clear
case "$code" in
  0)   ;;
  1)   exit 2 ;;
  *)   echo "Erreur de dialog (code $code) : $reponse" >&2; exit 1 ;;
esac

mapfile -t champs <<< "$reponse"
nom="${champs[0]}"
nb="${champs[1]}"
collabs=("${champs[@]:2:4}")
description="${champs[6]}"

logo=$(printf '%-30s%24s' "Visibilité du dépôt" "LaPlateforme_")

visibilite=$(dialog --no-shadow --no-collapse \
  --extra-button --extra-label "Précédent" \
  --ok-label "Valider" --cancel-label "Quitter" \
  --radiolist "$logo" 12 60 2 \
  private ""  on \
  public  "" off \
  3>&1 1>&2 2>&3)
code=$?
clear
case "$code" in
0) break ;;
3) continue ;;
1) echo "Annulé." >&2; exit 1 ;;
*) echo "Erreur de dialog (code $code)" >&2; exit 1 ;;
  esac
done


#---------------------------------- Validations des entrer  -------------------------------

if [[ ! "$nom" =~ ^[A-Za-z0-9._-]{1,100}$ ]]; then
  echo "Nom de projet invalide." >&2
  exit 1
fi

if [[ ! "$nb" =~ ^[0-9]+$ ]]; then
  echo "Le nombre de jobs doit être un entier." >&2
  exit 1
fi
nb=$((10#$nb))
if (( nb < 0 || nb > 40 )); then
  echo "Nombre de jobs : entre 0 et 40." >&2
  exit 1
fi

for pseudo in "${collabs[@]}"; do
  [[ -z "$pseudo" ]] && continue
  if [[ ! "$pseudo" =~ ^[A-Za-z0-9](-?[A-Za-z0-9]){0,38}$ ]]; then
    echo "Pseudo invalide : $pseudo" >&2
    exit 1
  fi
done

if [[ -e "$nom" ]]; then
  echo "Le dossier $nom existe déjà." >&2
  exit 1
fi

case "$visibilite" in
  private) prive=true ;;
  public)  prive=false ;;
  *) echo "Visibilité invalide." >&2; exit 1 ;;
esac

if [[ "$nom" == "." || "$nom" == ".." ]]; then
  echo "Nom de projet invalide." >&2
  exit 1
fi

if (( ${#description} > 200 )); then
  echo "Description trop longue (200 caractères max)." >&2
  exit 1
fi
if [[ "$description" =~ [[:cntrl:]] ]]; then
  echo "Description invalide : caractères de contrôle interdits." >&2
  exit 1
fi

#----------------- recupere le login dans $owner jq -r ----------------------------------

corps=$(mktemp)
trap 'rm -f "$corps"' EXIT

code=$(jq -n --arg name "$nom" --argjson private "$prive" '{name: $name, private: $private}' \
  | curl -s -o "$corps" -w "%{http_code}" \
      -X POST https://api.github.com/user/repos \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -d @-)

#----------------- Verif via code 201 que le dépôt est bien créer--------------------------

if [[ "$code" != "201" ]]; then
  echo "Échec ($code) : $(jq -r '.message' "$corps")" >&2
  exit 1
fi
echo "Dépôt $nom créé."

#------------------------------- Ajouts des collaborateurs -------------------------------

for pseudo in "${collabs[@]}"; do
  [[ -z "$pseudo" ]] && continue
  code=$(curl -s -o "$corps" -w "%{http_code}" \
    -X PUT "https://api.github.com/repos/$owner/$nom/collaborators/$pseudo" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d '{}')
  case "$code" in
    201) echo "Invitation envoyer a $pseudo." ;;
    204) echo "$pseudo a deja acces au depôt." ;;
    *)   echo "Echec pour $pseudo ($code) : $(jq -r '.message // "pas de message"' "$corps")" >&2 ;;
  esac
done

#--------------------------------- Dossier du projet -----------------------------------

mkdir "$nom"
cd "$nom" || exit 1


#-------------------------------Sous-Dossiers job----------------------------------------

for i in $(seq 1 "$nb"); do
  dossier=$(printf "Job%02d" "$i")
  mkdir "$dossier"
  touch "$dossier/.gitkeep"
done

printf '# %s\n\n%s\n' "$nom" "$description" > README.md

#--------------------------------------SSH-----------------------------------------------

cle=~/.ssh/id_ed25519

if [[ ! -f "$cle.pub" ]]; then
  echo "Aucune clé SSH trouvée, création..."
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  ssh-keygen -t ed25519 -f "$cle" -C "$(hostname)" || exit 1
fi

corps_cle=$(mktemp)
trap 'rm -f "$corps" "$corps_cle"' EXIT

code=$(jq -n --arg title "$(hostname)" --arg key "$(cat "$cle.pub")" '{title: $title, key: $key}' \
  | curl -s -o "$corps_cle" -w "%{http_code}" \
      -X POST https://api.github.com/user/keys \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -d @-)

case "$code" in
  201) echo "Clé SSH enregistrée sur GitHub." ;;
  422) echo "Clé déjà enregistrée, on continue." ;;
  *)   echo "Échec ($code) : $(jq -r '.message' "$corps_cle")" >&2; exit 1 ;;
esac

#---------------------------------push sur github via SSH----------------------------------

git init || exit 1
git config user.name "$git_nom" || exit 1
git config user.email "$git_mail" || exit 1
git add . || exit 1
git commit -m "Initial Commit" || exit 1
git branch -M main || exit 1
git remote add origin "git@github.com:$owner/$nom.git" || exit 1
git push -u origin main || exit 1
echo "Projet $nom push sur GitHub."
