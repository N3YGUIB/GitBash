# GitBash

Outil en Bash qui automatise la gestion de dépôts GitHub : création (distante + locale), mise à jour et suppression, avec des menus interactifs `dialog`. Il est conçu pour être sécurisé dès la conception.

## Fonctionnalités

| Script | Rôle |
|---|---|
| `gitbash.sh` | Lanceur : vérifie les outils et le token, affiche le menu principal |
| `gitbash_crea.sh` | Crée un dépôt GitHub, invite des collaborateurs, génère l'arborescence locale `Job01…JobNN` et pousse le tout |
| `gitbash_maj.sh` | Envoie sur GitHub les modifications d'un projet local (`add`, `commit`, `push`) |
| `gitbash_suppr.sh` | Supprime des dépôts sur GitHub, en local, ou les deux |
| `gitbash.dialogrc` | Thème de couleurs de `dialog` |

### Création
- Formulaire : nom du projet, nombre de jobs (0 à 40), jusqu'à 4 collaborateurs, description.
- Choix de la visibilité (privé par défaut).
- Dépôt créé via l'API GitHub, puis invitations des collaborateurs.
- Clé SSH générée si absente et enregistrée sur GitHub via l'API.
- Dossier local avec `Job01`, `Job02`… (un `.gitkeep` dans chacun pour que Git garde les dossiers vides), un `README.md`, puis premier commit et push en SSH.

### Mise à jour
- Liste des projets locaux (dossiers contenant un `.git`).
- Affiche les changements en attente, demande un message de commit, puis pousse.

### Suppression
- Liste des dépôts dont vous êtes propriétaire (checklist).
- Portée au choix : GitHub seulement, local seulement, ou les deux.
- Confirmation explicite avant toute action irréversible.
- Le dossier local n'est supprimé que si la suppression GitHub a réussi (`204`).

## Prérequis

- Debian / Ubuntu (le lanceur peut installer les paquets manquants avec `apt-get`)
- `curl`, `git`, `dialog`, `jq`, `ssh` (paquet `openssh-client`)
- Un compte GitHub et un **Personal Access Token**

## Installation

```bash
git clone git@github.com:<votre-pseudo>/GitBash.git
cd GitBash
chmod +x gitbash.sh gitbash_crea.sh gitbash_maj.sh gitbash_suppr.sh
```

### Token GitHub

1. GitHub > Settings > Developer settings > Personal access tokens.
2. Droits nécessaires (le strict minimum, avec une expiration courte) :
   - créer des dépôts ;
   - gérer les collaborateurs ;
   - écrire les clés SSH (classic : `write:public_key`) ;
   - supprimer des dépôts (classic : `delete_repo`), uniquement si vous utilisez la suppression.
3. Enregistrez-le dans `~/gitbash/token_github`, lisible par vous seul :
   ```bash
   chmod 600 ~/gitbash/token_github
   ```

> ⚠️ Ne versionnez **jamais** ce fichier : il figure dans le `.gitignore`.

## Utilisation

```bash
./gitbash.sh
```

Le menu propose : créer un dépôt, supprimer des dépôts, mettre à jour un dépôt. Le bouton « Précédent » de la première fenêtre d'un script ramène au menu ; dans les fenêtres suivantes, il revient à l'étape précédente.

## Sécurité

- **Token** : lu depuis un fichier en `chmod 600`, jamais écrit dans un script, jamais affiché.
- **Validation des entrées** avant tout appel réseau : nom de dépôt (regex, `.` et `..` refusés), nombre de jobs (entier, bornes), pseudos GitHub, description et message de commit (longueur, caractères de contrôle).
- **Choix fermés** (`radiolist`, `menu`) plutôt que de la saisie libre quand c'est possible.
- **JSON construit avec `jq --arg`** : les saisies sont des données, jamais du code.
- **Fichiers temporaires** avec `mktemp` et nettoyage par `trap … EXIT`.
- **Variables entre guillemets** partout, `--` avant les noms dans `rm`, `${base:?}` pour éviter un `rm -rf` sur un chemin vide.
- **Dépôt privé par défaut.**
- **Suppression locale** limitée aux dossiers sous la base, contenant un `.git`, et seulement après accord de l'utilisateur.
- **SSH** : seule la clé publique est envoyée, une clé existante n'est jamais écrasée.

## Limites connues

- Sur un dépôt **personnel**, GitHub ne permet pas d'inviter un collaborateur en lecture seule : la permission `pull` n'existe que pour les dépôts d'organisation. Le collaborateur reçoit donc lecture et écriture.
- Les chemins supposent que les projets sont créés dans `~/gitbash`.
- L'installation automatique des paquets ne fonctionne que sur les distributions basées sur `apt`.
- La suppression de dépôt exige un droit supplémentaire sur le token.

## Arborescence générée

```
mon-projet/
├── .git/
├── README.md
├── Job01/
│   └── .gitkeep
├── Job02/
│   └── .gitkeep
└── …
```

## Auteur

Projet réalisé dans le cadre de la formation à La Plateforme_.
