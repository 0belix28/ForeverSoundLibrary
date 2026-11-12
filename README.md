<p align="center">
  <img src="Media/logo.png" width="128" alt="ForeverSoundLibrary">
</p>

<h1 align="center">ForeverSoundLibrary</h1>

<p align="center">
  <b>Tous les sons et toutes les musiques de World of Warcraft, dans une bibliothèque à écouter quand vous voulez.</b><br>
  <i>Every sound and every music track in World of Warcraft, in one library you can browse and play anytime.</i>
</p>

<p align="center">
  <a href="#-français">🇫🇷 Français</a> • <a href="#-english">🇬🇧 English</a>
</p>

---

## 🇫🇷 Français

**ForeverSoundLibrary** est un addon pour **WoW Forever** qui rassemble dans une seule fenêtre plus de **270 000 sons** et près de **7 000 musiques** du jeu. Parcourez-les par dossier, cherchez-les par nom ou par ID, et écoutez-les en un clic.

### ✨ Fonctionnalités

- **Deux grandes catégories** :
  - **Sons** : environ 270 000 fichiers rangés dans environ 6 200 dossiers (créatures, sorts, ambiances, objets, interface…), plus tous les sons d'interface nommés du jeu (SOUNDKIT).
  - **Musique** : environ 7 000 morceaux (musiques de zones, de villes, de chaque extension, et la musique de Forever).
- **Favoris** : marquez vos sons préférés d'un clic droit et retrouvez-les dans leur propre onglet.
- **Recherche** par nom, par dossier ou par ID.
- **Écoute en un clic** : clic gauche pour écouter, bouton **Stop**, bouton **Aléatoire**.
- **Volume de 0 à 200 %** : le volume n'est modifié que pendant l'écoute, puis votre réglage est remis automatiquement.
- **Choix du canal audio** des sons (Master, Effets, Ambiance, Dialogues).
- **Maj + clic** pour mettre l'ID d'un son dans le chat, pratique pour les macros et les autres addons.
- **Panneau dans le menu Options** (Échap > Options > Add-ons) avec la liste des commandes.
- **Ouverture facile** : `/fsl`, bouton de la minicarte (déplaçable), menu des addons de la minicarte ou raccourci clavier.
- **API pour les autres addons** : permet à un autre addon d'ouvrir la bibliothèque pour faire choisir un son au joueur.

### ⌨️ Commandes

| Commande | Effet |
|---|---|
| `/fsl` | Ouvrir / fermer la bibliothèque |
| `/fsl options` | Ouvrir le panneau d'options |
| `/fsl search <texte>` | Ouvrir la bibliothèque et rechercher |
| `/fsl stop` | Arrêter le son ou la musique en cours |
| `/fsl play <FileID>` | Jouer un son par son ID |
| `/fsl music <FileID>` | Jouer une musique par son ID |
| `/fsl vol <0-200>` | Régler le volume de la bibliothèque |
| `/fsl minimap` | Afficher / masquer le bouton de la minicarte |
| `/fsl version` | Afficher la version de l'addon |

### 🖱️ Dans la bibliothèque

- **Clic gauche** : écouter
- **Clic droit** : ajouter ou retirer des favoris
- **Maj + clic** : insérer l'ID dans le chat
- **Molette sur la barre de volume** : ±5 % • **clic droit** : retour à 100 %

### 📦 Installation

1. Téléchargez la dernière version.
2. Copiez le dossier `ForeverSoundLibrary` dans `World of Warcraft\_forever_\Interface\AddOns\`.
3. Lancez le jeu et tapez `/fsl`.

### ℹ️ À savoir

- La liste des fichiers vient du WoW actuel. Certains fichiers peuvent manquer dans le client Forever : l'addon l'indique simplement dans le chat.
- WoW ne permet pas de régler le volume d'un seul son. L'addon modifie donc le volume du canal choisi pendant l'écoute, puis le remet comme avant. Au-delà de 100 %, le son est joué en double.
- La musique remplace celle de la zone jusqu'à ce que vous cliquiez sur **Stop**. Elle utilise le volume « Musique » du jeu.
- Les données font environ 10 Mo et sont chargées à la connexion.

### 🔌 Pour les développeurs

```lua
-- Ouvre la bibliothèque pour faire choisir un son au joueur.
-- label (facultatif) est affiché dans le titre de la fenêtre.
ForeverSoundLibrary_Pick(function(sound)
    -- sound = { id = nombre, kit = vrai (SoundKit) / faux (FileDataID), name, dir }
    if sound.kit then PlaySound(sound.id) else PlaySoundFile(sound.id) end
end, "Mon addon")
```

Si le joueur ferme la fenêtre, la fonction n'est pas appelée. Seuls les sons peuvent être choisis, pas les musiques.

---

## 🇬🇧 English

**ForeverSoundLibrary** is an addon for **WoW Forever** that puts more than **270,000 sounds** and nearly **7,000 music tracks** from the game into a single window. Browse them by folder, search by name or ID, and play them with one click.

### ✨ Features

- **Two main categories**:
  - **Sounds**: about 270,000 files in about 6,200 folders (creatures, spells, ambience, items, interface…), plus every named interface sound in the game (SOUNDKIT).
  - **Music**: about 7,000 tracks (zone music, city music, every expansion, and the Forever soundtrack).
- **Favorites**: right-click to star a sound and find it again in its own tab.
- **Search** by name, folder or ID.
- **One-click playback**: left-click to play, **Stop** button, **Random** button.
- **Volume from 0 to 200%**: the volume only changes while a sound plays, then your own setting comes back automatically.
- **Audio channel** for sounds: Master, Effects, Ambience or Dialog.
- **Shift + click** puts a sound's ID in the chat box, handy for macros and other addons.
- **Options panel** (Esc > Options > AddOns) with the full list of commands.
- **Easy to open**: `/fsl`, a minimap button (you can drag it), the minimap addon menu, or a key binding.
- **API for other addons**: another addon can open the library to let the player pick a sound.

### ⌨️ Commands

| Command | What it does |
|---|---|
| `/fsl` | Open / close the library |
| `/fsl options` | Open the options panel |
| `/fsl search <text>` | Open the library and search |
| `/fsl stop` | Stop the current sound or music |
| `/fsl play <FileID>` | Play a sound by its ID |
| `/fsl music <FileID>` | Play a music track by its ID |
| `/fsl vol <0-200>` | Set the library volume |
| `/fsl minimap` | Show / hide the minimap button |
| `/fsl version` | Show the addon version |

### 🖱️ In the library

- **Left-click**: play
- **Right-click**: add to or remove from favorites
- **Shift + click**: put the ID in the chat box
- **Mouse wheel on the volume bar**: ±5% • **right-click**: back to 100%

### 📦 Installation

1. Download the latest release.
2. Copy the `ForeverSoundLibrary` folder into `World of Warcraft\_forever_\Interface\AddOns\`.
3. Start the game and type `/fsl`.

### ℹ️ Good to know

- The file list comes from current retail WoW. Some files may be missing from the Forever client; the addon simply says so in the chat.
- WoW cannot change the volume of a single sound. The addon changes the volume of the chosen channel while the sound plays, then puts it back. Above 100%, the sound is played twice at the same time.
- Music replaces the zone music until you click **Stop**. It uses the game's Music volume.
- The data is about 10 MB and loads when you log in.

### 🔌 For developers

```lua
-- Opens the library so the player can pick a sound.
-- label (optional) is shown in the window title.
ForeverSoundLibrary_Pick(function(sound)
    -- sound = { id = number, kit = true (SoundKit) / false (FileDataID), name, dir }
    if sound.kit then PlaySound(sound.id) else PlaySoundFile(sound.id) end
end, "My addon")
```

If the player closes the window, the function is not called. Only sounds can be picked, not music.

---

### 🙏 Crédits / Credits

- Liste des fichiers / File list: [wowdev/wow-listfile](https://github.com/wowdev/wow-listfile) (community listfile).
- World of Warcraft, ses sons et ses musiques appartiennent à Blizzard Entertainment. Cet addon ne contient aucun fichier audio : il utilise uniquement ceux déjà présents dans le jeu.
- World of Warcraft and its sounds and music are the property of Blizzard Entertainment. This addon contains no audio files: it only plays the ones already in the game.
