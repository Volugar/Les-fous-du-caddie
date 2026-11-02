# Tidy Up! Workplace Chaos — jeu de rangement pour Roblox

Jeu de rangement **calme et satisfaisant**, vue à la première personne, PC et mobile, textes **en anglais**.
On range des lieux de travail en désordre : ramasser les objets par terre, suivre les panneaux,
les poser sur la bonne étagère. Seul ou jusqu'à 4 joueurs.

Tout le monde (hall d'accueil, niveaux, mobilier, objets, lumières) est **construit par les scripts
au lancement du jeu**. Il n'y a rien à poser à la main dans Studio.

## Nouveautés de la version 10 (sortie)

- **Boutique simple, uniquement des passes** : VIP 39 R$ (titre doré + panier doré), +5 Carry 49, +15 Carry 129,
  +30 Carry 200, Max Speed 89, Infinite Magnet 699. Les paniers se cumulent (5 → 55 objets). Icônes prêtes dans
  `marketing/pass_icons`. Serveurs privés à activer (voir `docs/BOUTIQUE.md`).
- **Panier** : 5 objets de base, seuls les passes l'agrandissent. Seuls 5 objets restent visibles dans la pile.
- **Chaque objet a son étagère** (catégories avec couleur et panneau), la consigne dit exactement où aller.
- **Fin de niveau** : confettis, écran « WELL DONE! » et **porte EXIT verte** près de l'entrée qui ramène au hall.
- **Touches** : **L** retour au hall (avec confirmation), **- / +** volume de la musique, **M** couper la musique.
- **Mode test** signalé par un bandeau rouge « TEST MODE » dans Studio.
- **Décors extérieurs détaillés**, hall avec vue sur la ville, éclairage recalibré, atrium des bureaux meublé.
- **Sécurité des sauvegardes** : verrou de session entre serveurs, attente des sauvegardes à la fermeture,
  achats jamais validés sans sauvegarde. Anti-spam des actions et anti-triche sur les records de temps.
- **Statistiques Roblox** (voir plus bas).

## Statistiques (Creator Hub)

Le jeu envoie automatiquement à Roblox les étapes clés des joueurs. Pour les voir :
**Creator Hub > votre expérience > Analytics** (onglets **Funnels**, **Custom Events**, **Economy**, **Progression**).
- **Funnels > Onboarding** : combien de joueurs arrivent, montent sur une plateforme, entrent dans un niveau,
  ramassent un premier objet, rangent un premier objet, finissent une pièce, finissent un niveau.
  C'est là que l'on voit où les joueurs abandonnent.
- **Progression** : niveaux commencés et terminés (Warehouse, Agency, Corporate Offices).
- **Custom Events** : pièces terminées (RoomCleared_...).
- **Economy** : points dépensés en améliorations.
Les données apparaissent quelques heures après les premières parties, une fois le jeu publié.

## Nouveautés de la version 9

- **Objets refaits un par un** : formes plus réalistes, couleurs vives, **étiquettes imprimées**
  (marques, codes-barres, titres de livres, « CONFIDENTIAL »...). Fini les petits carrés lumineux,
  les pièces qui scintillent et les objets à moitié dans le sol.
- **Ordre des niveaux** : 1. Entrepôt (2 320 objets), 2. Agence pour l'emploi (2 600 objets, rez-de-chaussée agrandi),
  3. Bureaux professionnels (3 000 objets, **en haut d'une tour** avec vue sur la ville).
  **Finir un niveau débloque le suivant** (sauvegardé).
- **Décor extérieur sérieux** vu par les fenêtres : zone industrielle, rue de ville, quartier d'affaires.
- **Éclairage** plus clair dans tous les niveaux, toujours léger (sans lag).
- **Tutoriel sur un panneau** à l'entrée de chaque niveau (plus de fenêtre qui bloque l'écran).
- **Choix du niveau simplifié** : 3 grandes cartes illustrées, nombre de joueurs, START.
- **HUD plus fin** : menu compact, consigne dans une pastille, 2 outils seulement (main et aimant), plus rien de coupé au bord de l'écran.
- **Panneaux des meubles** : petits, taille fixe, barre de progression, un seul par groupe de meubles, verts quand on porte le bon objet.
- **Boutique** : 7 articles essentiels aux prix étudiés (voir `docs/BOUTIQUE.md`), offre de départ mise en avant, cartes animées au survol.
- **Musique** : une musique libre de droits de Roblox pour le hall et pour chaque niveau.
- **Hall** : jardinières fleuries, coins salon, tableau « WHAT'S NEW ».
- Quêtes du jour supprimées. Le bonus quotidien reste.

## Nouveautés de la version 8

- **Moins de lag** : éclairage ShadowMap (plus léger que Future), les petites pièces et les milliers d'objets
  ne projettent plus d'ombre, le monde se charge autour du joueur (streaming), l'écran ne recalcule plus
  toutes les étagères en permanence. Le réglage **Low graphics** coupe en plus les ombres et les effets.
- **Nouvelle interface** : panneaux bleu nuit en verre, boutons colorés en relief, une seule famille de polices
  (Fredoka One pour les titres et les chiffres, Builder Sans pour les textes), tailles de texte régulières.
  Menu en bas à gauche (points, rang, Upgrades, Shop, Settings), compteurs en haut à droite,
  fenêtre Upgrades avec barre de niveaux, boutique en cartes, tutoriel en cartes.
- **Nouveau hall** : damier crème et lavande, murs bleu nuit et or, grande verrière à caissons, lustre, logo du jeu,
  plateformes rondes numérotées, affiches dorées des articles Robux, classements bleu nuit et or.
  L'assistant a été retiré.
- **Mode test dans Studio** : tout le jeu est ouvert pour l'essayer (voir plus bas).

## Mode test (pour analyser tout le jeu dans Studio)

Dans le script **`TidyConfig`** : `TidyConfig.TestUnlockAll = true` (réglage par défaut).
Quand vous cliquez sur **Play dans Roblox Studio** : les 3 niveaux et toutes les pièces sont ouverts et vous avez
**1 000 000 de points** (`TidyConfig.TestPoints`) pour acheter toutes les améliorations. Rien n'est sauvegardé pendant
ce mode, votre vraie progression n'est pas touchée. Le mode ne marche **jamais dans le jeu publié**.
Mettez `false` pour tester la progression normale dans Studio.

## Nouveautés de la version 7

- **Hall d'accueil intérieur** : murs rosés et soubassement en bois, verrière violette en voûte,
  fenêtres en arc, colonnes, palmiers, fontaine, **6 plateformes vertes** (« Empty / Waiting for players / PLAY »),
  borne « Join a friend ».
- **Mur des classements à l'entrée** : 4 grands panneaux surmontés d'une gemme lumineuse,
  **TOP WINS** et **temps le plus rapide** pour chaque niveau (records sauvegardés).
- **Boutique stylée** : enseigne SHOP verte, assistant sur sa plateforme, **6 affiches en arc**
  des articles Robux (cliquer = acheter directement), nouvelle fenêtre boutique en cartes
  (GAME PASSES / POINTS & BOOSTS, rubans NEW!, BEST!, DEAL!).
- **3 niveaux** :
  - **Employment Agency** : l'agence pour l'emploi, 16 pièces sur 2 étages, 1 122 objets ;
  - **Distribution Warehouse** : immense entrepôt de 9 sections, 2 320 objets (débloqué après 1 victoire) ;
  - **Corporate Headquarters** : siège social de luxe, 9 pièces, 1 714 objets (débloqué après 3 victoires).
- **Progression cumulable** : les pièces s'ouvrent toutes seules selon les points **gagnés** sur le
  niveau (on ne dépense rien pour ouvrir une pièce, rien n'est perdu). La journée en cours est
  **sauvegardée** : en revenant, les objets déjà rangés sont toujours à leur place.
- **Interface style "cartes"** : chronomètre, compteurs, offre limitée **DEAL**, boutons
  Upgrades [G], Shop [F], Settings [R], carte de l'objet en main (rayon + nom précis),
  barre d'outils à 4 cases avec cadenas, **6 cartes de tutoriel** à l'entrée d'un niveau.
- **Objets très détaillés** (ours en peluche, voitures, bidons de lessive, conserves, boîtes à chaussures,
  trophées, cadres, classeurs...) et **pile d'objets portés visible** dans les mains.
- **Boutique Robux** : 6 pass et 5 produits (voir plus bas).
- **Quêtes du jour**, victoires, rangs jusqu'à **CEO**, bonus quotidien.
- Graphismes **lumineux et chaleureux** : plafonds en lattes de bois, bandeaux lumineux, puits de lumière,
  lustres, suspensions, panneaux de rayon suspendus.

## Ouvrir le jeu

1. Téléchargez **`AgencePourLEmploi.rbxl`**.
2. Double-cliquez dessus, ou dans Roblox Studio : **File > Open from File…**
3. Cliquez sur **Play**. Vous apparaissez dans le hall : marchez sur une plateforme lumineuse,
   choisissez un niveau et le nombre de joueurs, puis **START**.

> En mode édition, le monde n'est pas visible : il est construit seulement quand le jeu tourne. C'est normal.

## Les 4 scripts

| Où le mettre dans Studio             | Type         | Nom             | Fichier                                            |
|--------------------------------------|--------------|-----------------|----------------------------------------------------|
| ReplicatedStorage                    | ModuleScript | `TidyConfig`    | `src/ReplicatedStorage/TidyConfig.lua`             |
| ServerScriptService                  | ModuleScript | `AgencyBuilder` | `src/ServerScriptService/AgencyBuilder.lua`        |
| ServerScriptService                  | Script       | `TidyManager`   | `src/ServerScriptService/TidyManager.server.lua`   |
| StarterPlayer > StarterPlayerScripts | LocalScript  | `TidyUI`        | `src/StarterPlayerScripts/TidyUI.client.lua`       |

(Les terminaisons `.server` et `.client` servent seulement à fabriquer le fichier `.rbxl` :
dans Studio, les noms sont bien `TidyManager` et `TidyUI`.)

## Comment on joue

### Hall d'accueil
- Marchez sur une des **6 plateformes lumineuses** : le premier joueur devient chef du groupe et choisit
  le **niveau** et le **nombre de joueurs (1 à 4)**. Les autres montent sur la même plateforme.
- Le départ se fait quand le groupe est complet (compte à rebours de 5 s) ou quand le chef appuie sur **START**.
- Dans le jeu publié, le groupe part dans **son propre serveur**. Un **code** s'affiche en haut à gauche :
  un ami peut le taper à la borne **JOIN A FRIEND** pour vous rejoindre.
- Le comptoir **SHOP** (et les vitrines) ouvre la boutique.

### Dans un niveau
- **Viseur** au centre : visez un objet et cliquez pour le mettre dans le panier ; visez l'étagère indiquée
  par les **panneaux suspendus** et cliquez pour le ranger. Sur mobile, touchez l'objet ou le meuble.
- Les objets portés s'**empilent** dans vos mains. **Molette** (ou **E**) : changer d'objet. **Q** (A en AZERTY) : lâcher.
- Outils : **1** main, **2** aimant (à débloquer dans les améliorations)
- **Y** : libérer la souris. **M** : couper la musique, **- / +** : volume. **G / F / R / L** : améliorations, boutique, paramètres, retour au hall.
- Livres, colis et classeurs vont sur le meuble de **la même couleur**.
- Quand tout est rangé : **victoire** (+1 win, +1 000 points), puis **Play again** ou **Back to lobby**.

### Progression (sauvegardée)
- Points, améliorations, victoires, niveaux terminés, points gagnés par niveau, réglages et **journée en cours**.
- Les pièces / sections s'ouvrent selon les **points gagnés sur ce niveau** (affiché sur les portes et clôtures).
- **Rangs** selon le total d'objets rangés : Intern → Office Assistant → Filing Clerk → Stock Keeper →
  Records Officer → Team Leader → Office Manager → Operations Director → CEO.
- **Bonus quotidien** : 100 points par jour de suite (jusqu'à 700 au 7e jour, x2 pour les VIP).

## Boutique Robux : à faire une fois le jeu publié

Tout est expliqué pas à pas dans **`docs/BOUTIQUE.md`** : les 7 articles, leur prix (et pourquoi), et où coller
leur numéro dans `TidyConfig`. Tant qu'un numéro vaut 0, l'article est « Coming soon » dans le jeu publié ;
**dans Studio, il est offert pour la session**, ce qui permet de tester tous les effets gratuitement.

## Sauvegarde dans Studio

Les sauvegardes utilisent les DataStores de Roblox. Pour les tester dans Studio : publiez le jeu, puis
**Home > Game Settings > Security > Enable Studio Access to API Services**. Sans cela, le jeu marche
normalement mais rien n'est sauvegardé entre deux tests.

## Musique d'ambiance

Le jeu utilise des musiques **libres de droits de la bibliothèque audio de Roblox** (une pour le hall, une par niveau),
réglées dans `TidyConfig.Music`. Rien à importer. Pour vérifier une musique : lancez **Play** dans Studio.
Si une musique ne se lance pas, remplacez son numéro par une autre musique de la Creator Store publiée par « Roblox ».
Le volume se règle dans **Settings [R]**, la touche **M** coupe la musique.

## Réglages simples (script `TidyConfig`)

- `GameTitle`, `AgencyName` : noms affichés.
- `Maps` : les niveaux dans l'ordre ; `Requires` = niveau à terminer pour débloquer le suivant.
- `MapImages` : images des cartes du choix de niveau (facultatif).
- `Rooms` : pièces de chaque niveau, seuil d'ouverture (`Unlock`, en points gagnés) et objets.
- `ItemTypes` : noms, rayon, noms précis (`Variants`), consignes et points de chaque objet.
- `Upgrades` : prix et niveaux des améliorations.
- `GamePasses`, `Products`, `PassEffects`, `DealDuration` : boutique.
- `Ranks`, `DailyBonusPerDay` : rangs, bonus quotidien.
- `BaseCapacity`, `BaseWalkSpeed`, `ReachDistance`, `RoomBonus`, `DayBonus`, `MaxPartySize`.
- `LightLevel` : intensité de l'éclairage (1 = normal, 0.8 = plus sombre, 1.2 = plus clair).

## Plan de l'agence

![Rez-de-chaussée](docs/plan_rez_de_chaussee.png)

![Étage](docs/plan_etage.png)

## Refabriquer le fichier `.rbxl` (pour le développeur)

```
rojo build default.project.json -o AgencePourLEmploi.rbxl
```
