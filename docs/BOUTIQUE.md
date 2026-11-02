# Boutique Robux : fiche à remplir une seule fois

Seul le propriétaire du jeu peut créer les articles Robux. Roblox ne permet à personne d'autre de le faire, ni à un script.
Comptez environ 2 minutes par article, 7 articles en tout.

## Les 7 articles et leur prix

| # | Nom à mettre | Type | Prix (Robux) | Ce que ça fait |
|---|---|---|---|---|
| 1 | Starter Deal | Developer Product | **49** | 3 000 points + 3 places de panier pour toujours. Achat unique, mis en avant tout en haut de la boutique. |
| 2 | x2 Points | Game Pass | **199** | Double tous les points gagnés. |
| 3 | Big Basket | Game Pass | **149** | 15 places de panier en plus, pour toujours. |
| 4 | Super Magnet | Game Pass | **249** | Aimant débloqué avec une portée de 60 studs. |
| 5 | VIP | Game Pass | **399** | Étiquette VIP dorée, +25 % de points, bonus quotidien x2. |
| 6 | Points Pack | Developer Product | **99** | 10 000 points (achat répétable). |
| 7 | Tidy Helper | Developer Product | **25** | Range 50 objets tout seul (achat répétable). |

## Pourquoi ces prix

- **Ce qui vous revient** : vous touchez environ 70 % de chaque vente (Roblox garde 30 %).
  Un pass à 199 R$ vous rapporte environ 139 R$.
- **Une première dépense très petite** : l'offre de départ à 49 R$ fait passer un joueur de « je ne paie jamais » à « j'ai déjà acheté ».
  Les développeurs Roblox rapportent que c'est l'étape la plus importante pour gagner de l'argent.
- **x2 Points à 199** : c'est le pass le plus vendu dans les simulateurs. Les jeux comparables le vendent entre 199 et 399 R$.
  199 est le bon prix pour un jeu qui démarre.
- **Big Basket à 149** : une entrée de gamme facile. Dans Pet Simulator 99, le pass « +15 places » coûte 375.
- **Super Magnet à 249** : c'est le confort le plus fort du jeu (ramasser de loin), donc un peu plus cher que x2 Points.
- **VIP à 399** : c'est le pass « haut de gamme » qui fait paraître les autres moins chers. Le VIP de Pet Simulator 99 coûte 400.
  399 R$ tient exactement dans le pack Robux à 4,99 € de l'application, le plus acheté par les jeunes joueurs.
- **Points Pack à 99** et **Tidy Helper à 25** : des petits achats qu'on peut refaire, pour les joueurs qui veulent avancer plus vite.
- **Prix régionaux** : Roblox baisse automatiquement les prix des pass dans les pays où le Robux coûte cher.
  C'est activé par défaut, vous n'avez rien à faire.
- J'ai retiré les doublons (+5 Carry, Max Speed, 1 000 et 30 000 points) : moins d'articles, chacun clairement utile.
  Les joueurs qui avaient déjà acheté un ancien article le gardent.

Sources : documentation officielle Roblox (monétisation, DevEx, prix régionaux), guides de prix 2025-2026,
et les prix observés dans les jeux Roblox populaires du même genre.

## Étapes

1. Publiez le jeu : dans Studio, **File > Publish to Roblox**.
2. Ouvrez le **Creator Hub** (create.roblox.com), puis votre expérience.
3. Pour les 4 pass (lignes 2 à 5) : **Monetization > Passes > Create a Pass**.
   - Mettez le nom, une image (vous pouvez prendre les miniatures du dossier `marketing`) et validez.
   - Ouvrez le pass, cochez **Item for Sale** et mettez le prix du tableau.
   - Copiez le **numéro du pass** (ID).
4. Pour les 3 produits (lignes 1, 6 et 7) : **Monetization > Developer Products > Create**.
   - Mettez le nom et le prix, puis copiez le **numéro** (ID).
5. Dans Studio, ouvrez le script **`TidyConfig`** (dans ReplicatedStorage).
   - Pour chaque article, remplacez `GamePassId = 0` ou `ProductId = 0` par le numéro copié.
   - Exemple : `GamePassId = 123456789`.
6. Publiez de nouveau. C'est fini.

Tant qu'un numéro vaut 0, l'article affiche « Coming soon » dans le jeu publié.
Dans Studio, il est offert pour tester ses effets gratuitement.
