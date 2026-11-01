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

- Approchez-vous d'un objet mal rangé : **E** au clavier, ou appuyez sur le bouton « Ramasser » sur mobile.
- Pendant que vous portez un objet, ses emplacements libres **brillent en vert**.
- Approchez-vous d'un emplacement vert et faites **E** / appuyez sur « Ranger ».
- On ne porte qu'un objet à la fois. Si le personnage meurt, l'objet retourne à sa place de départ.

| Objet           | Nombre | Où le ranger                                        |
|-----------------|--------|-----------------------------------------------------|
| Dossier         | 6      | Étagère « DOSSIERS » contre le mur du fond          |
| Pile de papiers | 6      | Bacs à documents (4 bureaux + 2 sur l'accueil)      |
| Chaise          | 6      | Salle d'attente, face à l'écran « NUMÉRO APPELÉ »   |
| Carton          | 4      | Étagères de la salle « RÉSERVE »                    |

## Plan (vue de dessus)

![Plan](docs/plan_vue_dessus.png)

En rouge : les objets mal rangés au départ. En vert : les emplacements où ils vont.

## Réglages simples (script `TidyConfig`)

- `AgencyName` : nom de l'agence affiché sur les panneaux et l'interface.
- `ItemTypes` : noms affichés et consignes pour chaque type d'objet.
- `PickupText` / `PutAwayText` : textes des boutons « Ramasser » / « Ranger ».
- `MaxDistance` : distance à laquelle on peut ramasser / ranger.

Les positions de départ des objets se trouvent dans `AgencyBuilder`, dans la liste
`MISPLACED_ITEMS`.

## Refabriquer le fichier `.rbxl` (pour le développeur)

```
rojo build default.project.json -o AgencePourLEmploi.rbxl
```
