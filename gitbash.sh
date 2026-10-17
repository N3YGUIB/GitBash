#!/bin/bash

#---------------------------- Verif outils -------------------------------------------

for outil in curl git dialog jq ssh; do
  if command -v "$outil" > /dev/null; then
    :
  else
    echo "$outil : absent, installation..."
    paquet="$outil"
    [[ "$outil" == "ssh" ]] && paquet="openssh-client"
    if ! sudo apt-get install -y "$paquet"; then
      echo "Échec de l'installation de $outil" >&2
      exit 1
    fi
  fi
done

#----------------------------- Dossier scripts ---------------------------------------

dir="$(dirname "$0")"

#------------------------------ Theme et logo -----------------------------------------

theme="$dir/gitbash.dialogrc"
[[ -f "$theme" ]] && export DIALOGRC="$theme"

logo=$(printf '%-30s%24s' "Menu principal" "LaPlateforme_")

#------------------------------ Formulaire Dialog -------------------------------------

while true; do

  choix=$(dialog --no-shadow --no-collapse \
    --ok-label "Valider" --cancel-label "Quitter" \
    --menu "$logo" 16 60 3 \
    1 "Créer un dépôt" \
    2 "Supprimer des dépôts" \
    3 "Mettre à jour un dépôt" \
    3>&1 1>&2 2>&3)
  code=$?
  clear

  case "$choix" in
    1) "$dir/gitbash_crea.sh";  retour=$? ;;
    2) "$dir/gitbash_suppr.sh"; retour=$? ;;
    3) "$dir/gitbash_maj.sh"; retour=$? ;;
    *) echo "Choix invalide." >&2; retour=1 ;;
  esac

  case "$retour" in
    2) continue ;;
    *) exit "$retour" ;;
  esac
done
