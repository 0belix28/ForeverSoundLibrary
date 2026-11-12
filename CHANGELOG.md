# ForeverSoundLibrary - Historique des versions

Format des versions : **0.X.Y**
- **X** : mise à jour majeure (nouvelle fonctionnalité importante)
- **Y** : mise à jour mineure (correction, petit ajout)
- Passage en **1.0.0** quand l'addon sera terminé et stable.

Le numéro de version se change à un seul endroit : la ligne `## Version:` de `ForeverSoundLibrary.toc`.

Les fichiers `Data\*.lua` sont générés automatiquement depuis le community-listfile
(github.com/wowdev/wow-listfile) : tous les fichiers `sound/` (.ogg/.mp3/.wav).

---

## 0.4.1 - Nouveau logo

- Nouveau logo (haut-parleur doré, fond transparent) dans `Media\Logo.tga`, 256×256.
- Utilisé dans le panneau Options, l'icône de la liste des addons et le bouton de la minicarte.

## 0.4.0 - Panneau dans le menu Options

- Nouveau panneau dans Échap > Options > Add-ons, avec le même style que ForeverEgo : logo, titre doré, version, bouton « Ouvrir ForeverSoundLibrary » et tableau des commandes.
- Nouvelles commandes `/fsl options` (ouvre ce panneau) et `/fsl version`.
- L'aide du chat (`/fsl help`) et le panneau utilisent la même liste de commandes.

## 0.3.0 - Mode « choix d'un son » pour les autres addons

- Nouvelle fonction `ForeverSoundLibrary_Pick(callback, label)` : un autre addon (ex. ForeverTchatBell) ouvre la bibliothèque pour faire choisir un son.
- En mode choix : le titre indique pour quoi on choisit, un clic gauche écoute et sélectionne le son, le bouton en haut à droite valide. Fermer la fenêtre (ou Échap) annule.
- Seuls les sons peuvent être choisis (pas les musiques). La fenêtre passe au-dessus du menu Options pendant le choix.

## 0.2.0 - Barre de volume

- Barre de volume de 0 à 200 % dans la barre du bas (glisser, molette par pas de 5 %, clic droit = 100 %). Réglage sauvegardé.
- Le volume du canal utilisé est modifié seulement pendant l'écoute, puis remis à la valeur du joueur (fin du son, Stop, déconnexion, /reload, ou au chargement suivant après un crash).
- Au-delà de 100 %, les sons sont joués en double pour monter jusqu'à 200 %. La musique est limitée au maximum du canal Musique.
- Commande `/fsl vol <0-200>`. `/fsl play` et `/fsl music` utilisent maintenant aussi le volume.

## 0.1.0 - Première version

- Fenêtre bibliothèque avec 3 onglets : **Sons** (~270 000 fichiers, ~6 200 dossiers + les sons d'interface SOUNDKIT), **Musique** (~7 000 morceaux) et **Favoris**.
- Liste des dossiers à gauche, fichiers à droite ; clic gauche pour écouter.
- Recherche par nom, dossier ou ID (« Tous les résultats » limité à 2 000 lignes).
- Favoris (clic droit), Maj+clic pour insérer l'ID dans le chat, bouton « Aléatoire », bouton « Stop ».
- Canal audio des sons au choix (Master par défaut). La musique remplace la musique de zone jusqu'à « Stop ».
- Ouverture : `/fsl`, bouton de minicarte (déplaçable), compartiment d'addons, raccourci clavier configurable.
- Commandes : `/fsl search <texte>`, `/fsl stop`, `/fsl play <ID>`, `/fsl music <ID>`, `/fsl minimap`.
