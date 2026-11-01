# Northfield Employment Agency — jeu de rangement calme pour Roblox

Jeu solo (PC et mobile, **en anglais**), ton sérieux et ambiance de bureau réaliste :
le joueur range une agence pour l'emploi fictive. Dossiers, piles de papiers, chaises,
cartons, tasses et plantes traînent partout. Il faut les ramasser et les remettre à leur place. Un compteur indique
combien d'objets il reste, et un message s'affiche quand l'agence est en ordre.

L'agence entière (bâtiment, mobilier, lumières, objets) est **construite par les
scripts au lancement du jeu**. Il n'y a rien à poser à la main dans Studio.

## Méthode 1 : ouvrir le fichier prêt à jouer (le plus simple)

1. Téléchargez **`AgencePourLEmploi.rbxl`**.
2. Double-cliquez dessus, ou dans Roblox Studio : **File > Open from File…**
3. Cliquez sur **Play**.

> En mode édition, l'agence n'est pas visible : elle est construite seulement
> quand le jeu tourne. C'est normal.

## Méthode 2 : créer les scripts à la main

Partez d'un nouveau jeu avec le modèle **Baseplate**, créez les 4 scripts
(clic droit sur le dossier > **Insert Object**), renommez-les **exactement**,
effacez le texte par défaut et collez le contenu du fichier.

| Où le mettre dans Studio             | Type         | Nom             | Fichier                                            |
|--------------------------------------|--------------|-----------------|----------------------------------------------------|
| ReplicatedStorage                    | ModuleScript | `TidyConfig`    | `src/ReplicatedStorage/TidyConfig.lua`             |
| ServerScriptService                  | ModuleScript | `AgencyBuilder` | `src/ServerScriptService/AgencyBuilder.lua`        |
| ServerScriptService                  | Script       | `TidyManager`   | `src/ServerScriptService/TidyManager.server.lua`   |
| StarterPlayer > StarterPlayerScripts | LocalScript  | `TidyUI`        | `src/StarterPlayerScripts/TidyUI.client.lua`       |

(Les terminaisons `.server` et `.client` servent seulement à fabriquer le fichier
`.rbxl` : dans Studio, les noms sont bien `TidyManager` et `TidyUI`.)

## Comment on joue

Un jeu de rangement **calme et satisfaisant**, en vue à la première personne : chaque objet a sa place,
on range à son rythme une grande agence de **10 pièces** (organisation inspirée d'une agence publique
pour l'emploi : accueil, espace libre-service, bureaux des conseillers, box d'entretien, ateliers,
centre de ressources, courrier...). Environ **800 objets** par journée de travail.

### Zone d'accueil (lobby)
En arrivant, le joueur est dans le **Staff Lobby** :
- **Play here** : ranger l'agence de ce serveur, avec les autres joueurs présents ;
- **Create private room** : crée un salon privé et y envoie le joueur ; le **code du salon** s'affiche en haut à gauche ;
- **Join** : rejoindre le salon d'un ami avec son code à 6 caractères.

Les salons privés ne fonctionnent que dans le **jeu publié** (pas dans Studio). Dans Studio, utilisez **Play here**.

### Commandes
- **Viseur** au centre : visez un objet (« Click to pick up ») et cliquez ; visez sa place (« Click to put away ») et cliquez.
  Sur mobile, appuyez sur l'objet ou le meuble.
- **Molette** (ou **E**, ou boutons < >) : changer d'objet en main. **Q** (A sur AZERTY) : lâcher.
- **Y** : libérer la souris. **G** : améliorations. **1, 2, 3** : main, aimant, loupe. **M** : musique.
- **Livres** et **colis** se rangent sur le meuble de **la même couleur** (étiquette au-dessus du meuble).

### Progression (sauvegardée)
- Points, améliorations, pièces ouvertes et nombre total d'objets rangés sont **sauvegardés** (jeu publié).
- **Rangs** selon le total d'objets rangés : Intern → Office Assistant → Filing Clerk → Records Officer →
  Job Advisor → Senior Advisor → Office Manager → Agency Director.
- **Bonus quotidien** : 50 points par jour de suite (jusqu'à 350 points au 7e jour).
- **100 points bonus** par pièce entièrement rangée. Nouvelle journée (**Play again**) quand tout est rangé.

| Pièce (nom dans le jeu)          | Prix     | Objets à ranger                                   |
|----------------------------------|----------|---------------------------------------------------|
| Accueil (Reception)              | ouverte  | 12 piles de papiers, 18 chaises                   |
| Espace libre-service (Self-Service Area) | ouverte | 12 chaises, 6 piles de papiers, 12 plantes |
| Bureaux (Advisor Offices)        | 200      | 36 piles de papiers, 12 plantes                   |
| Salle de pause (Break Room)      | 400      | 72 tasses, 16 chaises                             |
| Archives (Archives)              | 600      | 144 dossiers                                      |
| Réserve (Storage)                | 800      | 54 cartons                                        |
| Ateliers (Workshop Room)         | 1000     | 20 chaises, 6 piles de papiers, 6 plantes         |
| Box d'entretien (Interview Booths) | 1200   | 16 chaises, 24 piles de papiers                   |
| Centre de ressources (Resource Library) | 1500 | 192 livres, à trier par couleur              |
| Courrier (Mail Room)             | 1800     | 144 colis, à trier par couleur                    |

Total : **802 objets** par journée.

## Musique d'ambiance (originale, libre de droits)

Le fichier **`assets/chill_loop.mp3`** est une musique calme **composée pour ce jeu** (générée par
`tools/compose_music.py`) : vous pouvez l'utiliser librement. Pour l'activer :
1. Sur le site Roblox : **Create > Creator Hub > Development Items > Audio > Import**, choisissez `chill_loop.mp3`.
2. Copiez l'identifiant de l'audio (un nombre).
3. Dans le script `TidyConfig`, remplacez `TidyConfig.MusicSoundId = ""` par
   `TidyConfig.MusicSoundId = "rbxassetid://VOTRE_NOMBRE"`.

## Plan (vue de dessus)

![Plan](docs/plan_vue_dessus.png)

Exemple de partie. En rouge : les objets qui traînent (placés au hasard). En vert : les places de rangement.

## Réglages simples (script `TidyConfig`)

- `AgencyName` : nom de l'agence affiché sur les panneaux et l'interface.
- `ItemTypes` : noms affichés et consignes pour chaque type d'objet.
- `Rooms` : les pièces, leur prix d'ouverture et le nombre d'objets de chaque type.
- `Categories` : les couleurs des livres et des colis.
- `Ranks`, `DailyBonusPerDay` : rangs et bonus quotidien.
- `MusicSoundId`, `MusicVolume` : musique d'ambiance.
- `RoomBonus` : points bonus pour une pièce entièrement rangée.
- `ReachDistance` : distance à laquelle on peut ramasser / ranger.
- `BaseCapacity`, `BaseWalkSpeed` : sac et vitesse de départ.
- `Upgrades` : prix et niveaux des améliorations.

Les objets sont placés au hasard à chaque partie, en évitant les meubles.

## Refabriquer le fichier `.rbxl` (pour le développeur)

```
rojo build default.project.json -o AgencePourLEmploi.rbxl
```
