-- TidyConfig (ModuleScript)
-- Emplacement : ReplicatedStorage
-- Réglages partagés par le serveur (TidyManager, AgencyBuilder) et le joueur (TidyUI).
-- Tous les textes vus par le joueur sont en anglais.

local TidyConfig = {}

-- Nom de l'agence fictive (affiché en majuscules sur un panneau).
TidyConfig.AgencyName = "Northfield Employment Agency"

-- Chaque type d'objet que le joueur peut ranger.
-- DisplayName : nom d'un objet.        Plural : nom au pluriel (compteurs).
-- PlaceName   : nom de l'endroit où il se range.
-- Hint        : consigne affichée quand l'objet est en main.
-- Points      : points gagnés en le rangeant.
-- CarryOffset : position de l'objet tenu, par rapport au corps du joueur.
TidyConfig.ItemTypes = {
	Folder = {
		DisplayName = "Case Folder",
		Plural = "Case Folders",
		PlaceName = "Archive Shelf",
		Hint = "Put it on an archive shelf in the Archives.",
		Points = 10,
		CarryOffset = CFrame.new(0, 0, -1.6),
	},
	Paper = {
		DisplayName = "Stack of Papers",
		Plural = "Paper Stacks",
		PlaceName = "Document Tray",
		Hint = "Put it in a document tray (offices, reception or training room).",
		Points = 10,
		CarryOffset = CFrame.new(0, 0, -1.6),
	},
	Chair = {
		DisplayName = "Chair",
		Plural = "Chairs",
		PlaceName = "Chair Spot",
		Hint = "Put it back in a free spot: waiting area, break room tables or training room.",
		Points = 20,
		CarryOffset = CFrame.new(0, 0.3, -2.4),
	},
	Box = {
		DisplayName = "Cardboard Box",
		Plural = "Boxes",
		PlaceName = "Storage Shelf",
		Hint = "Put it on a shelf in the Storage room.",
		Points = 15,
		CarryOffset = CFrame.new(0, 0.2, -2),
	},
	Mug = {
		DisplayName = "Mug",
		Plural = "Mugs",
		PlaceName = "Cupboard",
		Hint = "Put it in a cupboard in the Break Room.",
		Points = 10,
		CarryOffset = CFrame.new(0, 0.2, -1.5),
	},
	Plant = {
		DisplayName = "Potted Plant",
		Plural = "Plants",
		PlaceName = "Planter",
		Hint = "Put it on a planter (offices, hallway or training room).",
		Points = 15,
		CarryOffset = CFrame.new(0, 0, -1.8),
	},
}

-- Ordre d'affichage des catégories.
TidyConfig.TypeOrder = { "Folder", "Paper", "Chair", "Box", "Mug", "Plant" }

-- Les pièces de l'agence. Cost = points pour ouvrir la pièce (0 = ouverte dès le début).
-- Items = objets qui traînent dans la pièce à chaque partie.
-- La première pièce qui contient le joueur donne le nom affiché « You are in: … ».
TidyConfig.Rooms = {
	{ Id = "Reception", Name = "Reception", MinX = -30, MaxX = 30, MinZ = 20, MaxZ = 60, Cost = 0, Items = { Paper = 12, Chair = 18 } },
	{ Id = "Offices", Name = "Offices", MinX = -80, MaxX = 0, MinZ = -60, MaxZ = 20, Cost = 200, Items = { Paper = 36, Plant = 12 } },
	{ Id = "Hallway", Name = "Hallway", MinX = 0, MaxX = 80, MinZ = -10, MaxZ = 20, Cost = 0, Items = { Plant = 12 } },
	{ Id = "BreakRoom", Name = "Break Room", MinX = -80, MaxX = -30, MinZ = 20, MaxZ = 60, Cost = 400, Items = { Mug = 36, Chair = 16 } },
	{ Id = "Archives", Name = "Archives", MinX = 0, MaxX = 50, MinZ = -60, MaxZ = -10, Cost = 600, Items = { Folder = 72 } },
	{ Id = "Storage", Name = "Storage", MinX = 50, MaxX = 80, MinZ = -60, MaxZ = -10, Cost = 800, Items = { Box = 36 } },
	{ Id = "Training", Name = "Training Room", MinX = 30, MaxX = 80, MinZ = 20, MaxZ = 60, Cost = 1000, Items = { Chair = 20, Paper = 6, Plant = 6 } },
}

-- Points bonus quand toute une pièce est rangée.
TidyConfig.RoomBonus = 100

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
	{ Id = "Capacity", Name = "Bigger Bag", Description = "Carry one more item", MaxLevel = 8, BaseCost = 25 },
	{ Id = "Speed", Name = "Comfortable Shoes", Description = "Walk a little faster", MaxLevel = 4, BaseCost = 30 },
	{ Id = "Magnet", Name = "Magnet", Description = "Unlocks the magnet, then increases its range", MaxLevel = 4, BaseCost = 60 },
	{ Id = "Magnifier", Name = "Magnifier", Description = "Unlocks the magnifier that shows where to go", MaxLevel = 1, BaseCost = 50 },
}

-- Son joué quand un objet est rangé (son intégré à Roblox).
TidyConfig.PlaceSoundId = "rbxasset://sounds/electronicpingshort.wav"

-- Noms partagés entre les scripts. Ne les changez pas, sauf partout à la fois.
TidyConfig.ItemTag = "TidyItem"
TidyConfig.SlotTag = "TidySlot"
TidyConfig.ZoneTag = "TidyZone"
TidyConfig.DoorTag = "TidyDoor"

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

-- Cherche une pièce par son identifiant.
function TidyConfig.GetRoom(id)
	for _, room in TidyConfig.Rooms do
		if room.Id == id then
			return room
		end
	end
	return nil
end

-- Renvoie la pièce qui contient une position (ou nil).
function TidyConfig.GetRoomAt(position)
	for _, room in TidyConfig.Rooms do
		if position.X >= room.MinX and position.X <= room.MaxX and position.Z >= room.MinZ and position.Z <= room.MaxZ then
			return room
		end
	end
	return nil
end

return TidyConfig
