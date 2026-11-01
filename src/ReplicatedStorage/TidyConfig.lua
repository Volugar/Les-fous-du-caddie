-- TidyConfig (ModuleScript)
-- Emplacement : ReplicatedStorage
-- Réglages partagés par le serveur (TidyManager, AgencyBuilder) et le joueur (TidyUI).
-- Tous les textes vus par le joueur sont en anglais.

local TidyConfig = {}

-- Nom de l'agence fictive (affiché en majuscules sur les panneaux).
TidyConfig.AgencyName = "Northfield Employment Agency"

-- Chaque type d'objet que le joueur peut ranger.
-- DisplayName : nom d'un objet.        Plural : nom au pluriel (compteurs).
-- PlaceName   : nom de l'endroit où il se range.
-- Hint        : consigne affichée quand l'objet est en main.
-- Points      : points gagnés en le rangeant.
-- CarryOffset : position de l'objet tenu (vue à la première personne), par rapport au corps du joueur.
TidyConfig.ItemTypes = {
	Folder = {
		DisplayName = "Case Folder",
		Plural = "Case Folders",
		PlaceName = "Archive Shelf",
		Hint = "Put it on an archive shelf in the Archives.",
		Points = 10,
		CarryOffset = CFrame.new(0.8, -0.3, -1.8),
	},
	Paper = {
		DisplayName = "Stack of Papers",
		Plural = "Paper Stacks",
		PlaceName = "Document Tray",
		Hint = "Put it in a document tray (desks, reception, printers, booths).",
		Points = 10,
		CarryOffset = CFrame.new(0.8, -0.3, -1.8),
	},
	Chair = {
		DisplayName = "Chair",
		Plural = "Chairs",
		PlaceName = "Chair Spot",
		Hint = "Put it back in a free chair spot.",
		Points = 20,
		CarryOffset = CFrame.new(0, -1, -2.6),
	},
	Box = {
		DisplayName = "Cardboard Box",
		Plural = "Boxes",
		PlaceName = "Storage Shelf",
		Hint = "Put it on a shelf in the Storage room.",
		Points = 15,
		CarryOffset = CFrame.new(0, -0.6, -2.4),
	},
	Mug = {
		DisplayName = "Mug",
		Plural = "Mugs",
		PlaceName = "Cupboard",
		Hint = "Put it in a cupboard in the Break Room.",
		Points = 10,
		CarryOffset = CFrame.new(0.8, -0.2, -1.6),
	},
	Plant = {
		DisplayName = "Potted Plant",
		Plural = "Plants",
		PlaceName = "Planter",
		Hint = "Put it on a planter.",
		Points = 15,
		CarryOffset = CFrame.new(0.9, -0.4, -2),
	},
	Book = {
		DisplayName = "Book",
		Plural = "Books",
		PlaceName = "Bookcase",
		Hint = "Put it on a bookcase with the same colored label in the Resource Library.",
		Points = 8,
		CarryOffset = CFrame.new(0.8, -0.3, -1.6),
	},
	Parcel = {
		DisplayName = "Parcel",
		Plural = "Parcels",
		PlaceName = "Pigeonhole Shelf",
		Hint = "Put it in the pigeonhole shelf with the same colored label in the Mail Room.",
		Points = 12,
		CarryOffset = CFrame.new(0.8, -0.4, -1.8),
	},
}

-- Ordre d'affichage des catégories.
TidyConfig.TypeOrder = { "Folder", "Paper", "Chair", "Box", "Mug", "Plant", "Book", "Parcel" }

-- Sous-catégories : un livre ou un colis doit aller sur le meuble de SA couleur.
TidyConfig.Categories = {
	Book = {
		{ Id = "CV", Name = "CV & Cover Letters", Color = Color3.fromRGB(176, 58, 50) },
		{ Id = "Interview", Name = "Interview Skills", Color = Color3.fromRGB(52, 92, 160) },
		{ Id = "Training", Name = "Training & Courses", Color = Color3.fromRGB(58, 128, 80) },
		{ Id = "Careers", Name = "Careers & Sectors", Color = Color3.fromRGB(196, 156, 52) },
	},
	Parcel = {
		{ Id = "Red", Name = "Red Label", Color = Color3.fromRGB(196, 60, 52) },
		{ Id = "Blue", Name = "Blue Label", Color = Color3.fromRGB(52, 100, 180) },
		{ Id = "Green", Name = "Green Label", Color = Color3.fromRGB(60, 140, 80) },
		{ Id = "Yellow", Name = "Yellow Label", Color = Color3.fromRGB(214, 176, 48) },
	},
}

-- Les pièces de l'agence (organisation inspirée d'une agence publique pour l'emploi).
-- Cost = points pour ouvrir la pièce (0 = ouverte dès le début).
-- Items = objets qui traînent dans la pièce à chaque journée de travail.
-- La première pièce qui contient le joueur donne le nom affiché « You are in: … ».
TidyConfig.Rooms = {
	{ Id = "Reception", Name = "Reception", MinX = -30, MaxX = 30, MinZ = 20, MaxZ = 60, Cost = 0, Items = { Paper = 12, Chair = 18 } },
	{ Id = "SelfService", Name = "Self-Service Area", MinX = 0, MaxX = 80, MinZ = -10, MaxZ = 20, Cost = 0, Items = { Chair = 12, Paper = 6, Plant = 12 } },
	{ Id = "Offices", Name = "Advisor Offices", MinX = -80, MaxX = 0, MinZ = -60, MaxZ = 20, Cost = 200, Items = { Paper = 36, Plant = 12 } },
	{ Id = "BreakRoom", Name = "Break Room", MinX = -80, MaxX = -30, MinZ = 20, MaxZ = 60, Cost = 400, Items = { Mug = 72, Chair = 16 } },
	{ Id = "Archives", Name = "Archives", MinX = 0, MaxX = 50, MinZ = -60, MaxZ = -10, Cost = 600, Items = { Folder = 144 } },
	{ Id = "Storage", Name = "Storage", MinX = 50, MaxX = 80, MinZ = -60, MaxZ = -10, Cost = 800, Items = { Box = 54 } },
	{ Id = "Training", Name = "Workshop Room", MinX = 30, MaxX = 80, MinZ = 20, MaxZ = 60, Cost = 1000, Items = { Chair = 20, Paper = 6, Plant = 6 } },
	{ Id = "Booths", Name = "Interview Booths", MinX = -80, MaxX = -20, MinZ = -100, MaxZ = -60, Cost = 1200, Items = { Chair = 16, Paper = 24 } },
	{ Id = "Library", Name = "Resource Library", MinX = -20, MaxX = 30, MinZ = -100, MaxZ = -60, Cost = 1500, Items = { Book = 192 } },
	{ Id = "MailRoom", Name = "Mail Room", MinX = 30, MaxX = 80, MinZ = -100, MaxZ = -60, Cost = 1800, Items = { Parcel = 144 } },
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
	{ Id = "Capacity", Name = "Bigger Bag", Description = "Carry one more item", MaxLevel = 10, BaseCost = 30 },
	{ Id = "Speed", Name = "Comfortable Shoes", Description = "Walk a little faster", MaxLevel = 5, BaseCost = 40 },
	{ Id = "Magnet", Name = "Magnet", Description = "Unlocks the magnet, then increases its range", MaxLevel = 5, BaseCost = 80 },
	{ Id = "Magnifier", Name = "Magnifier", Description = "Unlocks the magnifier that shows where to go", MaxLevel = 1, BaseCost = 60 },
}

-- Rangs du joueur, selon le nombre total d'objets rangés (sauvegardé d'une session à l'autre).
TidyConfig.Ranks = {
	{ Name = "Intern", Items = 0 },
	{ Name = "Office Assistant", Items = 100 },
	{ Name = "Filing Clerk", Items = 300 },
	{ Name = "Records Officer", Items = 700 },
	{ Name = "Job Advisor", Items = 1500 },
	{ Name = "Senior Advisor", Items = 3000 },
	{ Name = "Office Manager", Items = 6000 },
	{ Name = "Agency Director", Items = 10000 },
}

-- Bonus quotidien : points par jour de suite (plafonné à 7 jours).
TidyConfig.DailyBonusPerDay = 50
TidyConfig.DailyBonusMaxDays = 7

-- Musique d'ambiance. Mettez ici l'identifiant de la musique après l'avoir importée sur Roblox,
-- au format "rbxassetid://123456789". Laissez vide pour jouer sans musique.
TidyConfig.MusicSoundId = ""
TidyConfig.MusicVolume = 0.3

-- Son joué quand un objet est rangé (son intégré à Roblox).
TidyConfig.PlaceSoundId = "rbxasset://sounds/electronicpingshort.wav"

-- Salons privés (zone d'accueil) : durée de vie d'un code de salon, en secondes.
TidyConfig.RoomCodeLifetime = 6 * 3600

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

-- Cherche une sous-catégorie (livres, colis) par son identifiant.
function TidyConfig.GetCategory(itemType, categoryId)
	for _, category in TidyConfig.Categories[itemType] or {} do
		if category.Id == categoryId then
			return category
		end
	end
	return nil
end

-- Rang correspondant à un nombre total d'objets rangés.
function TidyConfig.GetRank(lifetimeItems)
	local current = TidyConfig.Ranks[1]
	for _, rank in TidyConfig.Ranks do
		if lifetimeItems >= rank.Items then
			current = rank
		end
	end
	return current
end

return TidyConfig
