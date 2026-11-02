# Boutique Robux : fiche à remplir une seule fois

Seul le propriétaire du jeu peut créer les articles Robux. Roblox ne permet à personne d'autre de le faire, ni à un script.
Comptez environ 2 minutes par passe, 6 passes en tout, plus 1 minute pour les serveurs privés.

## Les 6 passes

| # | Nom à mettre | Prix (Robux) | Ce que ça fait |
|---|---|---|---|
| 1 | VIP | **39** | Titre doré « 👑 VIP » au-dessus de la tête et panier doré visible par tous. |
| 2 | +5 Carry | **49** | 5 objets de plus dans le panier (10 au total). |
| 3 | +15 Carry | **129** | 15 objets de plus (cumulable). |
| 4 | +30 Carry | **200** | 30 objets de plus (cumulable). |
| 5 | Max Speed | **89** | Vitesse maximale tout de suite, pour toujours. |
| 6 | Infinite Magnet | **699** | L'aimant attire les objets de toute la carte. |

**Les passes de panier s'additionnent** : 5 objets de base, 10 avec +5, 20 avec +15, 25 avec les deux,
55 avec les trois. Seuls 5 objets restent visibles dans la pile, le compteur BASKET affiche le total.

Pourquoi ces prix :
- Le VIP à 39 et le +5 Carry à 49 sont des petites premières dépenses faciles.
- Les paniers se cumulent, donc un joueur qui achète le +5 a envie du +15, puis du +30.
- L'Infinite Magnet à 699 est l'article haut de gamme : les plus motivés le prennent, et il fait paraître les autres pas chers.
- Vous touchez environ 70 % de chaque vente (Roblox garde 30 %).

Les joueurs qui avaient acheté un ancien article (x2 Points, Big Basket…) le gardent.

## Étapes pour les passes

1. Publiez le jeu : dans Studio, **File > Publish to Roblox**.
2. Ouvrez le **Creator Hub** (create.roblox.com), puis votre expérience.
3. Pour chaque passe : **Monetization > Passes > Create a Pass**.
   - Mettez le nom du tableau et une image. Les icônes prêtes à téléverser sont dans `marketing/pass_icons`.
   - Ouvrez le passe, cochez **Item for Sale** et mettez le prix du tableau.
   - Copiez le **numéro du passe** (ID).
4. Dans Studio, ouvrez le script **`TidyConfig`** (dans ReplicatedStorage).
   Pour chaque passe, remplacez `GamePassId = 0` par le numéro copié (exemple : `GamePassId = 123456789`).
5. Publiez de nouveau.

Le jeu lit ensuite le **vrai prix** de chaque passe auprès de Roblox, donc le prix affiché est toujours juste,
même avec les prix régionaux.

Tant qu'un numéro vaut 0, le passe affiche « Coming soon » dans le jeu publié.
Dans Studio, il est offert pour tester ses effets gratuitement.

## Serveurs privés (revenu chaque mois, sans rien de plus à faire)

1. Creator Hub > votre expérience > **Monetization > Private Servers**.
2. Activez **Allow Private Servers** et choisissez un prix par mois, par exemple **50 Robux**.
3. Enregistrez.

Les joueurs peuvent alors louer un serveur pour jouer seuls ou entre amis. Le jeu fonctionne normalement dedans
(hall, plateformes, niveaux).
