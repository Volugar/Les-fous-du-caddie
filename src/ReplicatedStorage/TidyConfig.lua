-- TidyConfig (ModuleScript)
-- Emplacement : ReplicatedStorage
-- Réglages partagés par le serveur (TidyManager, AgencyBuilder) et le joueur (TidyUI).
-- Tous les textes du jeu visibles par le joueur sont en français.

local TidyConfig = {}

-- Nom de l'agence fictive (sans accents : il est affiché en majuscules sur un panneau).
TidyConfig.AgencyName = "Agence pour l'emploi de Valmont"

-- Chaque type d'objet que le joueur peut ranger.
-- DisplayName : nom d'un objet.        Plural : nom au pluriel (compteurs).
-- PlaceName   : nom de l'endroit où il se range.
-- Hint        : consigne affichée quand l'objet est en main.
-- Points      : points gagnés en le rangeant.
-- CarryOffset : position de l'objet tenu, par rapport au corps du joueur.
TidyConfig.ItemTypes = {
	Folder = {
		DisplayName = "Dossier",
		Plural = "Dossiers",
		PlaceName = "Étagère des dossiers",
		Hint = "Rangez-le sur une étagère des dossiers, contre le mur du fond.",
		Points = 10,
		CarryOffset = CFrame.new(0, 0, -1.6),
	},
	Paper = {
		DisplayName = "Pile de papiers",
		Plural = "Papiers",
		PlaceName = "Bac à documents",
		Hint = "Rangez-la dans un bac à documents, sur un bureau ou à l'accueil.",
		Points = 10,
		CarryOffset = CFrame.new(0, 0, -1.6),
	},
	Chair = {
		DisplayName = "Chaise",
		Plural = "Chaises",
		PlaceName = "Salle d'attente",
		Hint = "Remettez-la sur le tapis bleu de la salle d'attente.",
		Points = 20,
		CarryOffset = CFrame.new(0, 0.3, -2.4),
	},
	Box = {
		DisplayName = "Carton",
		Plural = "Cartons",
		PlaceName = "Étagère de la réserve",
		Hint = "Rangez-le sur une étagère de la réserve.",
		Points = 15,
		CarryOffset = CFrame.new(0, 0.2, -2),
	},
}

-- Ordre d'affichage des catégories.
TidyConfig.TypeOrder = { "Folder", "Paper", "Chair", "Box" }

-- Nombre d'objets mal rangés à chaque partie.
-- Maximum possible (nombre de places) : Folder 36, Paper 24, Chair 18, Box 18.
TidyConfig.ItemCounts = {
	Folder = 36,
	Paper = 24,
	Chair = 18,
	Box = 18,
}

-- Distance maximale (en studs) pour ramasser ou ranger d'un clic.
TidyConfig.ReachDistance = 14

-- Marge supplémentaire utilisée par le serveur quand il revérifie la distance.
TidyConfig.ServerDistanceMargin = 4

-- Sac et vitesse de départ.
TidyConfig.BaseCapacity = 3
TidyConfig.BaseWalkSpeed = 16

-- Aimant : portée au niveau 1, puis gain de portée par niveau.
TidyConfig.MagnetBaseRadius = 10
TidyConfig.MagnetRadiusPerLevel = 4

-- Améliorations achetées avec les points. Prix = BaseCost x (niveau visé).
TidyConfig.Upgrades = {
	{ Id = "Capacity", Name = "Sac plus grand", Description = "+1 objet transporté", MaxLevel = 5, BaseCost = 25 },
	{ Id = "Speed", Name = "Chaussures de course", Description = "+2 de vitesse de marche", MaxLevel = 3, BaseCost = 30 },
	{ Id = "Magnet", Name = "Aimant", Description = "Débloque l'aimant, puis augmente sa portée", MaxLevel = 3, BaseCost = 60 },
	{ Id = "Magnifier", Name = "Loupe", Description = "Débloque la loupe qui montre où aller", MaxLevel = 1, BaseCost = 50 },
}

-- Zones de l'agence (pour l'affichage « Vous êtes dans : … »). La première qui correspond gagne.
TidyConfig.Areas = {
	{ Name = "Réserve", MinX = 24, MaxX = 40, MinZ = -30, MaxZ = -12 },
	{ Name = "Salle d'attente", MinX = 14, MaxX = 40, MinZ = 12, MaxZ = 30 },
	{ Name = "Accueil", MinX = -40, MaxX = 40, MinZ = 8, MaxZ = 30 },
	{ Name = "Archives", MinX = -4, MaxX = 24, MinZ = -30, MaxZ = -20 },
	{ Name = "Couloir", MinX = 24, MaxX = 40, MinZ = -12, MaxZ = 8 },
	{ Name = "Bureaux", MinX = -40, MaxX = 24, MinZ = -30, MaxZ = 8 },
}

-- Noms partagés entre les scripts. Ne les changez pas, sauf partout à la fois.
TidyConfig.ItemTag = "TidyItem"
TidyConfig.SlotTag = "TidySlot"
TidyConfig.ZoneTag = "TidyZone"

-- Prix d'une amélioration pour passer au niveau suivant.
function TidyConfig.GetUpgradeCost(upgrade, currentLevel)
	return upgrade.BaseCost * (currentLevel + 1)
end

-- Cherche une amélioration par son identifiant.
function TidyConfig.GetUpgrade(id)
	for _, upgrade in TidyConfig.Upgrades do
		if upgrade.Id == id then
			return upgrade
		end
	end
	return nil
end

return TidyConfig
