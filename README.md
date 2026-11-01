# Agence pour l'emploi de Valmont — jeu de rangement Roblox

Jeu solo (PC et mobile, en français) : le joueur range une agence pour l'emploi
fictive. Des dossiers, des piles de papiers, des chaises et des cartons traînent
partout. Il faut les ramasser et les remettre à leur place. Un compteur indique
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

- **Ramasser :** cliquez sur un objet qui traîne (ou appuyez dessus sur mobile). Il va dans votre **sac**.
- **Ranger :** cliquez sur l'endroit où il se range : étagère, bureau, comptoir ou tapis bleu.
  Les places libres brillent en vert, et les meubles concernés sont entourés.
- **Sac :** 3 objets au départ. La touche **E** ou les boutons < > changent l'objet en main,
  la touche **Q** (A sur un clavier AZERTY) ou le bouton « Lâcher » le pose par terre.
- **Points :** chaque objet rangé rapporte des points (dossier et papiers 10, carton 15, chaise 20).
- **Améliorations (touche G) :** sac plus grand, chaussures de course, aimant, loupe.
- **Outils (touches 1, 2, 3) :**
  - **Main** : ramasser et ranger ;
  - **Aimant** : un clic attire dans le sac les objets proches ;
  - **Loupe** : un rayon doré montre l'objet le plus proche, ou la place où ranger.
- **Chronomètre** en haut, **compteurs par catégorie** en haut à droite, **zone actuelle** en bas.
- **Fin :** message « L'agence est en ordre. » avec votre temps et votre record, puis **Rejouer**.
  Une nouvelle partie éparpille de nouveaux objets ; les points et les améliorations sont conservés.

| Objet           | Nombre | Où le ranger                                        |
|-----------------|--------|-----------------------------------------------------|
| Dossier         | 36     | 2 étagères « DOSSIERS » contre le mur du fond       |
| Pile de papiers | 24     | Bacs à documents (4 bureaux + 4 sur l'accueil)      |
| Chaise          | 18     | Tapis bleu de la salle d'attente                    |
| Carton          | 18     | 3 étagères de la réserve                            |

## Plan (vue de dessus)

![Plan](docs/plan_vue_dessus.png)

Exemple de partie. En rouge : les objets qui traînent (placés au hasard). En vert : les places de rangement.

## Réglages simples (script `TidyConfig`)

- `AgencyName` : nom de l'agence affiché sur les panneaux et l'interface.
- `ItemTypes` : noms affichés et consignes pour chaque type d'objet.
- `ItemCounts` : nombre d'objets de chaque type par partie.
- `ReachDistance` : distance à laquelle on peut ramasser / ranger.
- `BaseCapacity`, `BaseWalkSpeed` : sac et vitesse de départ.
- `Upgrades` : prix et niveaux des améliorations.

Les objets sont placés au hasard à chaque partie, en évitant les meubles.

## Refabriquer le fichier `.rbxl` (pour le développeur)

```
rojo build default.project.json -o AgencePourLEmploi.rbxl
```
