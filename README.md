# Northfield Employment Agency — jeu de rangement Roblox

Jeu solo (PC et mobile, en anglais) : le joueur range une agence pour l'emploi
fictive. Des dossiers, des piles de papiers, des chaises et des cartons traînent
partout. Il faut les ramasser et les remettre à leur place. Un compteur indique
combien d'objets il reste, et un message s'affiche quand l'agence est en ordre.

L'agence entière (bâtiment, mobilier, lumières, objets) est **construite par les
scripts au lancement du jeu**. Il n'y a rien à poser à la main dans Studio.

## Installation dans Roblox Studio

1. Créez un nouveau jeu avec le modèle **Baseplate**.
2. Créez les 4 scripts ci-dessous (clic droit sur le dossier > **Insert Object**).
   Renommez-les **exactement** comme indiqué, effacez le texte par défaut
   (`print("Hello world!")`), puis collez le contenu du fichier.

| Où le mettre dans Studio                  | Type         | Nom             | Fichier                                         |
|-------------------------------------------|--------------|-----------------|-------------------------------------------------|
| ReplicatedStorage                         | ModuleScript | `TidyConfig`    | `src/ReplicatedStorage/TidyConfig.lua`          |
| ServerScriptService                       | ModuleScript | `AgencyBuilder` | `src/ServerScriptService/AgencyBuilder.lua`     |
| ServerScriptService                       | Script       | `TidyManager`   | `src/ServerScriptService/TidyManager.lua`       |
| StarterPlayer > StarterPlayerScripts      | LocalScript  | `TidyUI`        | `src/StarterPlayerScripts/TidyUI.lua`           |

3. Cliquez sur **Play**. L'agence apparaît et le joueur arrive dans le hall d'entrée.

> En mode édition, l'agence n'est pas visible : elle est construite seulement
> quand le jeu tourne. C'est normal.

## Comment on joue

- Approchez-vous d'un objet mal rangé : **E** au clavier, ou appuyez sur le bouton à l'écran sur mobile.
- Pendant que vous portez un objet, ses emplacements libres **brillent en vert**.
- Approchez-vous d'un emplacement vert et faites **E** / appuyez pour ranger l'objet.
- On ne porte qu'un objet à la fois. Si le personnage meurt, l'objet retourne à sa place de départ.

| Objet           | Nombre | Où le ranger                                      |
|-----------------|--------|---------------------------------------------------|
| Case Folder     | 6      | Étagère « CASE FILES » contre le mur du fond      |
| Stack of Papers | 6      | Bacs à documents (4 bureaux + 2 sur l'accueil)    |
| Chair           | 6      | Salle d'attente, face à l'écran « NOW SERVING »   |
| Cardboard Box   | 4      | Étagères de la salle « STORAGE »                  |

## Plan (vue de dessus)

![Plan](docs/plan_vue_dessus.png)

En rouge : les objets mal rangés au départ. En vert : les emplacements où ils vont.

## Réglages simples (fichier `TidyConfig`)

- `AgencyName` : nom de l'agence affiché sur les panneaux et l'interface.
- `ItemTypes` : noms affichés et consignes pour chaque type d'objet.
- `MaxDistance` : distance à laquelle on peut ramasser / ranger.

Les positions de départ des objets se trouvent dans `AgencyBuilder`, dans la liste
`MISPLACED_ITEMS`.
