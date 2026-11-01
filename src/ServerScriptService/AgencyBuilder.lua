-- AgencyBuilder (ModuleScript)
-- Emplacement : ServerScriptService
-- Construit toute l'agence pour l'emploi au lancement du jeu : 7 pièces, murs, portes
-- verrouillées, mobilier, décor, lumières, zones de rangement et objets éparpillés.
-- Style bureau réaliste et sobre.
-- Il est utilisé par le script TidyManager. Il ne fait rien tout seul.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TidyConfig = require(ReplicatedStorage:WaitForChild("TidyConfig"))

local AgencyBuilder = {}

---------------------------------------------------------------------------
-- Dimensions (en studs). L'intérieur du bâtiment va de
-- X = -80 à 80 et de Z = -60 à 60. La surface du sol est à Y = 1.
---------------------------------------------------------------------------
local FLOOR_TOP = 1
local HALF_X = 80
local HALF_Z = 60
local WALL_HEIGHT = 12
local CEILING_BOTTOM = FLOOR_TOP + WALL_HEIGHT
local DOOR_HEIGHT = 8
local DESK_HEIGHT = 2.5
local COUNTER_HEIGHT = 3.75

-- Taille de la pièce principale de chaque objet. Sert aux objets et à leurs places.
local ITEM_SIZES = {
	Folder = Vector3.new(1.3, 0.15, 1.6),
	Paper = Vector3.new(1.1, 0.25, 1.5),
	Chair = Vector3.new(2, 0.35, 2),
	Box = Vector3.new(2.1, 1.6, 1.6),
	Mug = Vector3.new(0.5, 0.55, 0.5),
	Plant = Vector3.new(1, 1.9, 1),
}

-- Distance entre le sol et le centre de la pièce principale de chaque objet.
local REST_HEIGHTS = {
	Folder = 0.075,
	Paper = 0.125,
	Chair = 1.8,
	Box = 0.8,
	Mug = 0.275,
	Plant = 0.95,
}

-- Objets qui peuvent être renversés : hauteur et rayon une fois couchés.
local TIPPED = {
	Chair = { Height = 1, Radius = 2.4 },
	Mug = { Height = 0.25, Radius = 0.6 },
	Plant = { Height = 0.6, Radius = 1.2 },
}

-- Rayon occupé au sol par chaque objet (pour ne pas les poser les uns sur les autres).
local ITEM_RADIUS = {
	Folder = 1.1,
	Paper = 1,
	Chair = 1.6,
	Box = 1.5,
	Mug = 0.5,
	Plant = 0.8,
}

local COLORS = {
	Wall = Color3.fromRGB(232, 230, 224),
	WallBand = Color3.fromRGB(140, 146, 152),
	Trim = Color3.fromRGB(245, 245, 242),
	Partition = Color3.fromRGB(226, 224, 218),
	Ceiling = Color3.fromRGB(226, 226, 222),
	CeilingGrid = Color3.fromRGB(205, 205, 202),
	Light = Color3.fromRGB(248, 248, 244),
	Tiles = Color3.fromRGB(198, 196, 190),
	MintTiles = Color3.fromRGB(208, 200, 186),
	Carpet = Color3.fromRGB(88, 98, 110),
	WarmCarpet = Color3.fromRGB(96, 96, 100),
	GreenCarpet = Color3.fromRGB(104, 112, 104),
	WoodFloor = Color3.fromRGB(178, 176, 170),
	Concrete = Color3.fromRGB(170, 170, 166),
	Wood = Color3.fromRGB(176, 150, 116),
	DarkWood = Color3.fromRGB(104, 78, 56),
	Metal = Color3.fromRGB(160, 164, 170),
	DarkMetal = Color3.fromRGB(70, 72, 78),
	Black = Color3.fromRGB(28, 28, 30),
	White = Color3.fromRGB(244, 244, 240),
	OfficeChair = Color3.fromRGB(46, 48, 54),
	Rug = Color3.fromRGB(52, 62, 80),
	GreenRug = Color3.fromRGB(84, 90, 96),
	Paper = Color3.fromRGB(244, 244, 238),
	Cardboard = Color3.fromRGB(178, 140, 94),
	Tape = Color3.fromRGB(206, 176, 128),
	Glass = Color3.fromRGB(190, 215, 230),
	DoorGlass = Color3.fromRGB(170, 195, 210),
	Plant = Color3.fromRGB(62, 112, 64),
	Pot = Color3.fromRGB(90, 90, 92),
	Cork = Color3.fromRGB(172, 132, 92),
	SignBlue = Color3.fromRGB(34, 52, 78),
	Ghost = Color3.fromRGB(90, 220, 130),
}

-- Couleurs réalistes des objets.
local FOLDER_COLORS = {
	Color3.fromRGB(214, 190, 140),
	Color3.fromRGB(70, 92, 132),
	Color3.fromRGB(120, 44, 44),
	Color3.fromRGB(62, 92, 72),
	Color3.fromRGB(150, 150, 152),
}
local CHAIR_COLORS = {
	Color3.fromRGB(55, 60, 70),
	Color3.fromRGB(40, 55, 85),
	Color3.fromRGB(85, 85, 90),
}
local STICKER_COLORS = {
	Color3.fromRGB(240, 240, 236),
	Color3.fromRGB(230, 210, 120),
}
local SHEET_COLORS = {
	Color3.fromRGB(250, 248, 240),
	Color3.fromRGB(236, 240, 246),
	Color3.fromRGB(246, 242, 226),
}
local MUG_COLORS = {
	Color3.fromRGB(244, 244, 240),
	Color3.fromRGB(70, 74, 82),
	Color3.fromRGB(40, 55, 85),
	Color3.fromRGB(150, 60, 50),
}
local POT_COLORS = {
	Color3.fromRGB(90, 90, 92),
	Color3.fromRGB(235, 235, 230),
	Color3.fromRGB(170, 110, 80),
}

---------------------------------------------------------------------------
-- Obstacles au sol : liste de rectangles {minX, maxX, minZ, maxZ} où l'on
-- ne pose pas d'objet au début d'une partie.
---------------------------------------------------------------------------
local obstacles = {}
local collectObstacles = false

local function addObstacle(minX, maxX, minZ, maxZ)
	table.insert(obstacles, { minX, maxX, minZ, maxZ })
end

-- Enregistre l'emprise au sol d'une pièce si elle gêne le passage.
local function registerFootprint(part)
	local half = part.Size / 2
	local minX, maxX, minY, maxY, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = part.CFrame * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
				minX, maxX = math.min(minX, corner.X), math.max(maxX, corner.X)
				minY, maxY = math.min(minY, corner.Y), math.max(maxY, corner.Y)
				minZ, maxZ = math.min(minZ, corner.Z), math.max(maxZ, corner.Z)
			end
		end
	end
	if maxY > FLOOR_TOP + 0.06 and minY < FLOOR_TOP + 6 then
		addObstacle(minX, maxX, minZ, maxZ)
	end
end

---------------------------------------------------------------------------
-- Petites fonctions utilitaires
---------------------------------------------------------------------------

-- Applique un matériau par son nom, avec un matériau de secours s'il n'existe pas.
local function setMaterial(part, materialName)
	local ok = pcall(function()
		part.Material = Enum.Material[materialName]
	end)
	if not ok then
		part.Material = Enum.Material.SmoothPlastic
	end
end

-- Crée une pièce ancrée. "options" permet de régler d'autres propriétés.
local function newPart(parent, name, size, cframe, color, materialName, options)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	setMaterial(part, materialName or "SmoothPlastic")
	if options then
		for key, value in options do
			part[key] = value
		end
	end
	if collectObstacles and part.CanCollide then
		registerFootprint(part)
	end
	part.Parent = parent
	return part
end

-- Crée une pièce ancrée à partir de la position de son centre (sans rotation).
local function block(parent, name, size, position, color, materialName, options)
	return newPart(parent, name, size, CFrame.new(position), color, materialName, options)
end

-- Crée un cylindre vertical (les cylindres Roblox sont couchés sur X, on les fait pivoter).
local function cylinder(parent, name, height, diameter, center, color, materialName)
	local part = newPart(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		materialName
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function addSignText(board, face, text, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(245, 245, 245)
	label.TextScaled = true
	label.Parent = gui
	return label
end

-- Crée un panneau plat avec du texte. "facing" est la direction vers laquelle le texte regarde.
local function newSign(parent, name, text, size, position, facing, backgroundColor, textColor)
	local board = newPart(
		parent,
		name,
		size,
		CFrame.lookAt(position, position + facing),
		backgroundColor or COLORS.SignBlue,
		"SmoothPlastic",
		{ CanCollide = false, CastShadow = false }
	)
	addSignText(board, Enum.NormalId.Front, text, textColor)
	return board
end

local function newModel(parent, name)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function newFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

---------------------------------------------------------------------------
-- Zones de rangement et places
---------------------------------------------------------------------------
local allSlots = {}
local allZones = {}
local allDoors = {}

-- Transforme un meuble en zone de rangement : on clique dessus pour y ranger.
-- Un panneau flottant affiche le compteur de la catégorie.
local function makeZone(model, itemType, anchorPart, billboardHeight)
	local room = TidyConfig.GetRoomAt(anchorPart.Position)
	model:SetAttribute("ItemType", itemType)
	model:SetAttribute("ZoneLabel", TidyConfig.ItemTypes[itemType].PlaceName)
	model:SetAttribute("Room", room and room.Id or "")
	CollectionService:AddTag(model, TidyConfig.ZoneTag)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CategoryBillboard"
	billboard.Adornee = anchorPart
	billboard.Size = UDim2.fromOffset(180, 44)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, billboardHeight, 0)
	billboard.MaxDistance = 40
	billboard.LightInfluence = 0
	billboard.Parent = model

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = COLORS.SignBlue
	label.BackgroundTransparency = 0.1
	label.Font = Enum.Font.GothamBold
	label.Text = TidyConfig.ItemTypes[itemType].PlaceName
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextScaled = true
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = label

	table.insert(allZones, model)
	return newFolder(model, "Spots")
end

-- Place invisible où un objet doit être rangé. Elle brille quand le joueur
-- tient un objet du bon type (géré par TidyUI).
local function createSlot(spotsFolder, itemType, targetCFrame)
	local index = #spotsFolder:GetChildren() + 1
	local slot = newPart(spotsFolder, itemType .. "Spot" .. index, ITEM_SIZES[itemType], targetCFrame, COLORS.Ghost, "Neon", {
		Transparency = 1,
		CastShadow = false,
	})
	slot.CanCollide = false
	slot.CanTouch = false
	slot.CanQuery = false
	slot:SetAttribute("ItemType", itemType)
	slot:SetAttribute("Occupied", false)
	CollectionService:AddTag(slot, TidyConfig.SlotTag)

	-- Aucun objet ne doit apparaître là où une chaise se range.
	if itemType == "Chair" then
		local p = targetCFrame.Position
		addObstacle(p.X - 1.4, p.X + 1.4, p.Z - 1.4, p.Z + 1.4)
	end

	table.insert(allSlots, slot)
	return slot
end

---------------------------------------------------------------------------
-- Murs, portes et fenêtres
---------------------------------------------------------------------------

-- Mur intérieur le long de l'axe X (à une valeur de Z), avec des ouvertures.
-- doors = liste de { From, To, Room (pièce verrouillée ou nil) }.
local function interiorWallAlongX(parent, z, x1, x2, doors)
	local cursor = x1
	table.sort(doors, function(a, b)
		return a.From < b.From
	end)
	local segments = {}
	for _, door in doors do
		table.insert(segments, { cursor, door.From })
		cursor = door.To
	end
	table.insert(segments, { cursor, x2 })
	for _, segment in segments do
		local length = segment[2] - segment[1]
		if length > 0.01 then
			block(parent, "Partition", Vector3.new(length, WALL_HEIGHT, 0.5), Vector3.new(segment[1] + length / 2, FLOOR_TOP + WALL_HEIGHT / 2, z), COLORS.Partition, "Plaster")
		end
	end
	for _, door in doors do
		local length = door.To - door.From
		local centerX = door.From + length / 2
		block(parent, "DoorLintel", Vector3.new(length, WALL_HEIGHT - DOOR_HEIGHT, 0.5), Vector3.new(centerX, FLOOR_TOP + DOOR_HEIGHT + (WALL_HEIGHT - DOOR_HEIGHT) / 2, z), COLORS.Partition, "Plaster")
		addObstacle(door.From - 1, door.To + 1, z - 3, z + 3)
		door.Center = Vector3.new(centerX, FLOOR_TOP + DOOR_HEIGHT / 2, z)
		door.Size = Vector3.new(length, DOOR_HEIGHT, 0.3)
		door.Facing = Vector3.new(0, 0, 1)
	end
end

-- Mur intérieur le long de l'axe Z (à une valeur de X), avec des ouvertures.
local function interiorWallAlongZ(parent, x, z1, z2, doors)
	local cursor = z1
	table.sort(doors, function(a, b)
		return a.From < b.From
	end)
	local segments = {}
	for _, door in doors do
		table.insert(segments, { cursor, door.From })
		cursor = door.To
	end
	table.insert(segments, { cursor, z2 })
	for _, segment in segments do
		local length = segment[2] - segment[1]
		if length > 0.01 then
			block(parent, "Partition", Vector3.new(0.5, WALL_HEIGHT, length), Vector3.new(x, FLOOR_TOP + WALL_HEIGHT / 2, segment[1] + length / 2), COLORS.Partition, "Plaster")
		end
	end
	for _, door in doors do
		local length = door.To - door.From
		local centerZ = door.From + length / 2
		block(parent, "DoorLintel", Vector3.new(0.5, WALL_HEIGHT - DOOR_HEIGHT, length), Vector3.new(x, FLOOR_TOP + DOOR_HEIGHT + (WALL_HEIGHT - DOOR_HEIGHT) / 2, centerZ), COLORS.Partition, "Plaster")
		addObstacle(x - 3, x + 3, door.From - 1, door.To + 1)
		door.Center = Vector3.new(x, FLOOR_TOP + DOOR_HEIGHT / 2, centerZ)
		door.Size = Vector3.new(length, DOOR_HEIGHT, 0.3)
		door.Facing = Vector3.new(1, 0, 0)
	end
end

-- Porte vitrée verrouillée : on clique dessus pour ouvrir la pièce avec ses points.
local function createLockedDoor(parent, door)
	local room = TidyConfig.GetRoom(door.Room)
	local barrier = newPart(
		parent,
		"LockedDoor_" .. door.Room,
		door.Size,
		CFrame.lookAt(door.Center, door.Center + door.Facing),
		COLORS.DoorGlass,
		"Glass",
		{ Transparency = 0.35 }
	)
	barrier:SetAttribute("Room", door.Room)
	local text = room.Name .. "\nLOCKED\n" .. room.Cost .. " points\nClick to open"
	addSignText(barrier, Enum.NormalId.Front, text, COLORS.White)
	addSignText(barrier, Enum.NormalId.Back, text, COLORS.White)
	CollectionService:AddTag(barrier, TidyConfig.DoorTag)
	table.insert(allDoors, barrier)
	return barrier
end

-- Mur extérieur le long de l'axe Z (côtés est et ouest), avec des fenêtres.
local function windowedSideWall(parent, name, x, windows, insideDirection)
	local sillY = FLOOR_TOP + 3
	local windowTop = FLOOR_TOP + 9
	local wallHeight = CEILING_BOTTOM
	local length = HALF_Z * 2
	block(parent, name .. "Low", Vector3.new(1, sillY, length), Vector3.new(x, sillY / 2, 0), COLORS.Wall, "Plaster")
	block(parent, name .. "High", Vector3.new(1, wallHeight - windowTop, length), Vector3.new(x, (windowTop + wallHeight) / 2, 0), COLORS.Wall, "Plaster")
	local windowHeight = windowTop - sillY
	local windowY = (sillY + windowTop) / 2
	local cursor = -HALF_Z
	for _, window in windows do
		local pillar = window[1] - cursor
		if pillar > 0.01 then
			block(parent, name .. "Pillar", Vector3.new(1, windowHeight, pillar), Vector3.new(x, windowY, cursor + pillar / 2), COLORS.Wall, "Plaster")
		end
		local glassLength = window[2] - window[1]
		block(parent, name .. "Window", Vector3.new(0.3, windowHeight, glassLength), Vector3.new(x, windowY, window[1] + glassLength / 2), COLORS.Glass, "Glass", { Transparency = 0.5 })
		block(parent, name .. "Sill", Vector3.new(0.6, 0.2, glassLength), Vector3.new(x + insideDirection * 0.8, sillY + 0.1, window[1] + glassLength / 2), COLORS.Trim, "SmoothPlastic")
		cursor = window[2]
	end
	local last = HALF_Z - cursor
	if last > 0.01 then
		block(parent, name .. "Pillar", Vector3.new(1, windowHeight, last), Vector3.new(x, windowY, cursor + last / 2), COLORS.Wall, "Plaster")
	end
end

---------------------------------------------------------------------------
-- Bâtiment : sols, murs, portes, plafond et lumières
---------------------------------------------------------------------------
local function buildStructure(parent)
	local floorY = FLOOR_TOP / 2
	local function floor(name, minX, maxX, minZ, maxZ, color, material, options)
		block(parent, name, Vector3.new(maxX - minX, 1, maxZ - minZ), Vector3.new((minX + maxX) / 2, floorY, (minZ + maxZ) / 2), color, material, options)
	end

	-- Sols de chaque pièce (ils se touchent sans se chevaucher).
	floor("ReceptionFloor", -30, 30, 20, 60, COLORS.Tiles, "CeramicTiles", { Reflectance = 0.05 })
	floor("OfficesFloor", -80, 0, -60, 20, COLORS.Carpet, "Carpet")
	floor("HallwayFloor", 0, 80, -10, 20, COLORS.WoodFloor, "CeramicTiles")
	floor("BreakRoomFloor", -80, -30, 20, 60, COLORS.MintTiles, "CeramicTiles", { Reflectance = 0.04 })
	floor("ArchivesFloor", 0, 50, -60, -10, COLORS.WarmCarpet, "Carpet")
	floor("StorageFloor", 50, 80, -60, -10, COLORS.Concrete, "Concrete")
	floor("TrainingFloor", 30, 80, 20, 60, COLORS.GreenCarpet, "Carpet")

	-- Murs extérieurs (hors de la zone intérieure).
	local wallHeight = CEILING_BOTTOM
	local wallY = wallHeight / 2
	local fullLengthX = HALF_X * 2 + 2
	local fullLengthZ = HALF_Z * 2 + 2

	block(parent, "NorthWall", Vector3.new(fullLengthX, wallHeight, 1), Vector3.new(0, wallY, -HALF_Z - 0.5), COLORS.Wall, "Plaster")

	-- Mur sud avec l'entrée (8 studs de large, 8 studs de haut).
	local doorHalf = 4
	local doorTop = FLOOR_TOP + 8
	local sideLength = HALF_X + 1 - doorHalf
	block(parent, "SouthWallLeft", Vector3.new(sideLength, wallHeight, 1), Vector3.new(-(doorHalf + sideLength / 2), wallY, HALF_Z + 0.5), COLORS.Wall, "Plaster")
	block(parent, "SouthWallRight", Vector3.new(sideLength, wallHeight, 1), Vector3.new(doorHalf + sideLength / 2, wallY, HALF_Z + 0.5), COLORS.Wall, "Plaster")
	block(parent, "EntranceLintel", Vector3.new(doorHalf * 2, wallHeight - doorTop, 1), Vector3.new(0, (doorTop + wallHeight) / 2, HALF_Z + 0.5), COLORS.Wall, "Plaster")
	for _, side in { -1, 1 } do
		block(parent, "GlassDoor", Vector3.new(3.9, 8, 0.3), Vector3.new(side * 2, FLOOR_TOP + 4, HALF_Z + 0.5), COLORS.Glass, "Glass", { Transparency = 0.6 })
		block(parent, "DoorHandle", Vector3.new(0.15, 1.5, 0.5), Vector3.new(side * 0.4, FLOOR_TOP + 3.75, HALF_Z + 0.2), COLORS.Metal, "Metal")
	end
	block(parent, "DoorFrame", Vector3.new(0.3, 8, 0.4), Vector3.new(0, FLOOR_TOP + 4, HALF_Z + 0.5), COLORS.DarkMetal, "Metal")

	-- Murs est et ouest avec des fenêtres.
	windowedSideWall(parent, "WestWall", -HALF_X - 0.5, { { -52, -36 }, { -26, -10 }, { 0, 14 }, { 28, 52 } }, 1)
	windowedSideWall(parent, "EastWall", HALF_X + 0.5, { { -48, -24 }, { -6, 14 }, { 26, 54 } }, -1)

	-- Cloisons intérieures et portes. Room = pièce que la porte garde fermée.
	local doors = {}
	local function door(from, to, room)
		local d = { From = from, To = to, Room = room }
		if room then
			table.insert(doors, d)
		end
		return d
	end
	interiorWallAlongX(parent, 20, -80, 80, { door(-19, -11, "Offices"), door(11, 19, nil) })
	interiorWallAlongZ(parent, -30, 20, 60, { door(36, 44, "BreakRoom") })
	interiorWallAlongZ(parent, 30, 20, 60, { door(36, 44, "Training") })
	interiorWallAlongZ(parent, 0, -60, 20, { door(1, 9, "Offices") })
	interiorWallAlongX(parent, -10, 0, 80, { door(21, 29, "Archives"), door(61, 69, "Storage") })
	interiorWallAlongZ(parent, 50, -60, -10, {})
	for _, d in doors do
		createLockedDoor(parent, d)
	end

	-- Nom des pièces au-dessus des portes.
	local signY = FLOOR_TOP + DOOR_HEIGHT + 1.5
	local roomSigns = {
		{ "OFFICES", Vector3.new(-15, signY, 20.3), Vector3.new(0, 0, 1) },
		{ "HALLWAY", Vector3.new(15, signY, 20.3), Vector3.new(0, 0, 1) },
		{ "BREAK ROOM", Vector3.new(-29.7, signY, 40), Vector3.new(1, 0, 0) },
		{ "TRAINING", Vector3.new(29.7, signY, 40), Vector3.new(-1, 0, 0) },
		{ "ARCHIVES", Vector3.new(25, signY, -9.7), Vector3.new(0, 0, 1) },
		{ "STORAGE", Vector3.new(65, signY, -9.7), Vector3.new(0, 0, 1) },
		{ "OFFICES", Vector3.new(0.3, signY, 5), Vector3.new(1, 0, 0) },
	}
	for _, sign in roomSigns do
		newSign(parent, "RoomSign", sign[1], Vector3.new(7, 1.2, 0.1), sign[2], sign[3])
	end

	-- Faux plafond à dalles : fond clair et grille métallique.
	block(parent, "Ceiling", Vector3.new(fullLengthX, 1, fullLengthZ), Vector3.new(0, CEILING_BOTTOM + 0.5, 0), COLORS.Ceiling, "SmoothPlastic")
	local gridX = -HALF_X + 4
	while gridX < HALF_X do
		block(parent, "CeilingGrid", Vector3.new(0.12, 0.06, HALF_Z * 2), Vector3.new(gridX, CEILING_BOTTOM - 0.03, 0), COLORS.CeilingGrid, "Metal", { CanCollide = false, CastShadow = false })
		gridX += 4
	end
	local gridZ = -HALF_Z + 4
	while gridZ < HALF_Z do
		block(parent, "CeilingGrid", Vector3.new(HALF_X * 2, 0.06, 0.12), Vector3.new(0, CEILING_BOTTOM - 0.03, gridZ), COLORS.CeilingGrid, "Metal", { CanCollide = false, CastShadow = false })
		gridZ += 4
	end

	-- Luminaires encastrés, répartis dans chaque pièce (alignés sur la grille du plafond).
	for _, room in TidyConfig.Rooms do
		local lampX = room.MinX + 10
		while lampX <= room.MaxX - 6 do
			local lampZ = room.MinZ + 10
			while lampZ <= room.MaxZ - 6 do
				local panel = block(parent, "CeilingLight", Vector3.new(3.6, 0.1, 1.8), Vector3.new(lampX, CEILING_BOTTOM - 0.05, lampZ), COLORS.Light, "Neon", { CanCollide = false, CastShadow = false })
				local light = Instance.new("SurfaceLight")
				light.Face = Enum.NormalId.Bottom
				light.Angle = 120
				light.Range = 18
				light.Brightness = 1.2
				light.Color = Color3.fromRGB(250, 248, 242)
				light.Shadows = false
				light.Parent = panel
				lampZ += 16
			end
			lampX += 16
		end
	end

	-- Bandeau de couleur en bas des murs extérieurs, avec une baguette blanche.
	local bandTop = FLOOR_TOP + 3
	local bandY = FLOOR_TOP + 1.5
	local function band(name, size, position, withTrim)
		block(parent, name, size, position, COLORS.WallBand, "SmoothPlastic", { CanCollide = false })
		if withTrim then
			local trimSize = Vector3.new(size.X + (if size.X < 1 then 0.05 else 0), 0.2, size.Z + (if size.Z < 1 then 0.05 else 0))
			block(parent, name .. "Trim", trimSize, Vector3.new(position.X, bandTop + 0.1, position.Z), COLORS.Trim, "SmoothPlastic", { CanCollide = false })
		end
	end
	band("NorthBand", Vector3.new(HALF_X * 2, 3, 0.1), Vector3.new(0, bandY, -HALF_Z + 0.05), true)
	band("EastBand", Vector3.new(0.1, 3, HALF_Z * 2), Vector3.new(HALF_X - 0.05, bandY, 0), false)
	band("WestBand", Vector3.new(0.1, 3, HALF_Z * 2), Vector3.new(-HALF_X + 0.05, bandY, 0), false)
	local southLength = HALF_X - doorHalf
	band("SouthBand", Vector3.new(southLength, 3, 0.1), Vector3.new(-(doorHalf + southLength / 2), bandY, HALF_Z - 0.05), true)
	band("SouthBand", Vector3.new(southLength, 3, 0.1), Vector3.new(doorHalf + southLength / 2, bandY, HALF_Z - 0.05), true)

	-- Tapis d'entrée.
	block(parent, "EntranceMat", Vector3.new(6, 0.05, 3), Vector3.new(0, FLOOR_TOP + 0.025, HALF_Z - 2.5), COLORS.DarkMetal, "Fabric", { CanCollide = false })
end

---------------------------------------------------------------------------
-- Mobilier et décor
---------------------------------------------------------------------------

-- Chaise de bureau (décor). "floorPosition" est au sol ; la chaise regarde vers -Z avant rotation.
local function createOfficeChair(parent, floorPosition, yawRadians)
	local model = newModel(parent, "OfficeChair")
	local base = CFrame.new(floorPosition) * CFrame.Angles(0, yawRadians, 0)
	newPart(model, "Base", Vector3.new(1.8, 0.2, 1.8), base * CFrame.new(0, 0.1, 0), COLORS.DarkMetal, "Metal")
	newPart(model, "Post", Vector3.new(0.3, 1.5, 0.3), base * CFrame.new(0, 0.95, 0), COLORS.Metal, "Metal")
	newPart(model, "Seat", Vector3.new(2, 0.4, 2), base * CFrame.new(0, 1.9, 0), COLORS.OfficeChair, "Fabric")
	newPart(model, "Back", Vector3.new(2, 2.2, 0.3), base * CFrame.new(0, 3.2, 0.9), COLORS.OfficeChair, "Fabric")
	return model
end

local function createPlant(parent, x, z)
	local model = newModel(parent, "Plant")
	cylinder(model, "Pot", 1.4, 1.2, Vector3.new(x, FLOOR_TOP + 0.7, z), COLORS.Pot, "Concrete")
	local leaves = block(model, "Leaves", Vector3.new(2.2, 2.2, 2.2), Vector3.new(x, FLOOR_TOP + 2.3, z), COLORS.Plant, "Grass")
	leaves.Shape = Enum.PartType.Ball
	return model
end

-- Bac à documents : 3 piles de papiers peuvent s'y empiler.
local function createTray(model, spots, position)
	block(model, "DocumentTray", Vector3.new(1.4, 0.1, 1.8), position + Vector3.new(0, 0.05, 0), COLORS.DarkMetal, "Metal")
	for level = 0, 2 do
		local y = 0.1 + REST_HEIGHTS.Paper + level * ITEM_SIZES.Paper.Y
		createSlot(spots, "Paper", CFrame.new(position + Vector3.new(0, y, 0)))
	end
end

-- Bureau : plateau, ordinateur et petits objets. Renvoie le plateau et la hauteur du dessus.
local function buildDesk(model, cx, cz)
	local top = FLOOR_TOP + DESK_HEIGHT
	local desktop = block(model, "Desktop", Vector3.new(6, 0.2, 3), Vector3.new(cx, top - 0.1, cz), COLORS.Wood, "Wood")
	for _, side in { -1, 1 } do
		block(model, "SidePanel", Vector3.new(0.2, DESK_HEIGHT - 0.2, 2.8), Vector3.new(cx + side * 2.85, FLOOR_TOP + (DESK_HEIGHT - 0.2) / 2, cz), COLORS.Metal, "SmoothPlastic")
	end
	block(model, "ModestyPanel", Vector3.new(5.5, 1.5, 0.1), Vector3.new(cx, FLOOR_TOP + 1.55, cz + 1.3), COLORS.Metal, "SmoothPlastic")
	block(model, "MonitorStand", Vector3.new(0.4, 0.5, 0.3), Vector3.new(cx, top + 0.25, cz + 0.7), COLORS.Black, "SmoothPlastic")
	block(model, "Monitor", Vector3.new(2.2, 1.3, 0.1), Vector3.new(cx, top + 1.15, cz + 0.7), COLORS.Black, "SmoothPlastic")
	block(model, "Keyboard", Vector3.new(1.6, 0.08, 0.5), Vector3.new(cx, top + 0.04, cz - 0.6), COLORS.Black, "SmoothPlastic")
	block(model, "Mouse", Vector3.new(0.25, 0.08, 0.4), Vector3.new(cx + 1.05, top + 0.04, cz - 0.6), COLORS.Black, "SmoothPlastic")
	return desktop, top
end

-- Bureau de conseiller avec deux chaises et un bac à documents.
local function createAdvisorDesk(parent, index, cx, cz)
	local model = newModel(parent, "AdvisorDesk" .. index)
	local desktop, top = buildDesk(model, cx, cz)
	cylinder(model, "Mug", 0.45, 0.35, Vector3.new(cx - 2.2, top + 0.225, cz - 0.7), CHAIR_COLORS[(index - 1) % #CHAIR_COLORS + 1], "SmoothPlastic")
	cylinder(model, "PenPot", 0.5, 0.4, Vector3.new(cx - 2.2, top + 0.25, cz + 0.7), COLORS.DarkMetal, "Metal")
	createOfficeChair(model, Vector3.new(cx, FLOOR_TOP, cz - 2.4), math.pi)
	createOfficeChair(model, Vector3.new(cx, FLOOR_TOP, cz + 2.4), 0)
	local spots = makeZone(model, "Paper", desktop, 3.5)
	createTray(model, spots, Vector3.new(cx + 2, top, cz))
end

-- Bureau du formateur : deux bacs à documents.
local function createTeacherDesk(parent, cx, cz)
	local model = newModel(parent, "TeacherDesk")
	local desktop, top = buildDesk(model, cx, cz)
	createOfficeChair(model, Vector3.new(cx, FLOOR_TOP, cz - 2.4), math.pi)
	local spots = makeZone(model, "Paper", desktop, 3.5)
	createTray(model, spots, Vector3.new(cx + 2, top, cz))
	createTray(model, spots, Vector3.new(cx - 2, top, cz))
end

-- Comptoir d'accueil avec 4 bacs à documents. Le comptoir regarde vers +Z.
local function createReception(parent, cx, cz)
	local model = newModel(parent, "Reception")
	local top = FLOOR_TOP + COUNTER_HEIGHT

	block(model, "CounterBody", Vector3.new(12, COUNTER_HEIGHT - 0.25, 2.5), Vector3.new(cx, FLOOR_TOP + (COUNTER_HEIGHT - 0.25) / 2, cz), COLORS.DarkWood, "Wood")
	local counterTop = block(model, "CounterTop", Vector3.new(12.4, 0.25, 2.9), Vector3.new(cx, top - 0.125, cz), COLORS.Tiles, "Marble")
	newSign(model, "ReceptionSign", "RECEPTION", Vector3.new(5, 1, 0.05), Vector3.new(cx, FLOOR_TOP + 2.2, cz + 1.275), Vector3.new(0, 0, 1))
	block(model, "MonitorStand", Vector3.new(0.4, 0.5, 0.3), Vector3.new(cx, top + 0.25, cz - 0.6), COLORS.Black, "SmoothPlastic")
	block(model, "Monitor", Vector3.new(2.2, 1.3, 0.1), Vector3.new(cx, top + 1.15, cz - 0.6), COLORS.Black, "SmoothPlastic")
	createOfficeChair(model, Vector3.new(cx, FLOOR_TOP, cz - 3), math.pi)

	-- Nom de l'agence, suspendu au plafond au-dessus du comptoir.
	local signY = FLOOR_TOP + 9
	local signZ = cz - 1
	newSign(model, "AgencySign", string.upper(TidyConfig.AgencyName), Vector3.new(16, 1.8, 0.3), Vector3.new(cx, signY, signZ), Vector3.new(0, 0, 1))
	local wireLength = CEILING_BOTTOM - (signY + 0.9)
	for _, offset in { -6, 6 } do
		block(model, "SignWire", Vector3.new(0.05, wireLength, 0.05), Vector3.new(cx + offset, signY + 0.9 + wireLength / 2, signZ), COLORS.DarkMetal, "Metal", { CanCollide = false })
	end

	local spots = makeZone(model, "Paper", counterTop, 3)
	for _, offset in { -4.5, -2.6, 2.6, 4.5 } do
		createTray(model, spots, Vector3.new(cx + offset, top, cz))
	end
end

-- Étagère des dossiers : 3 tablettes de 6 dossiers debout. Le dos est côté -Z.
local function createArchiveShelf(parent, index, cx, cz)
	local model = newModel(parent, "ArchiveShelf" .. index)
	local width, depth, height = 6, 2, 6.2

	local backPanel = block(model, "BackPanel", Vector3.new(width, height, 0.2), Vector3.new(cx, FLOOR_TOP + height / 2, cz - 0.9), COLORS.Wood, "Wood")
	for _, side in { -1, 1 } do
		block(model, "SidePanel", Vector3.new(0.2, height, depth - 0.2), Vector3.new(cx + side * (width / 2 - 0.1), FLOOR_TOP + height / 2, cz + 0.1), COLORS.Wood, "Wood")
	end
	local shelfTops = { 0.2, 2.2, 4.2, height }
	for _, shelfTop in shelfTops do
		block(model, "Shelf", Vector3.new(width - 0.4, 0.15, depth - 0.2), Vector3.new(cx, FLOOR_TOP + shelfTop - 0.075, cz + 0.1), COLORS.Wood, "Wood")
	end
	for _, offset in { -1.4, 1.4 } do
		block(model, "ArchiveBox", Vector3.new(2.4, 0.7, 1.6), Vector3.new(cx + offset, FLOOR_TOP + height + 0.35, cz + 0.1), COLORS.Cardboard, "Cardboard")
	end

	local spots = makeZone(model, "Folder", backPanel, 5)
	for level = 1, 3 do
		for slotIndex = 0, 5 do
			local x = cx - 2 + slotIndex * 0.8
			local y = FLOOR_TOP + shelfTops[level] + ITEM_SIZES.Folder.X / 2
			createSlot(spots, "Folder", CFrame.new(x, y, cz + 0.05) * CFrame.Angles(0, 0, math.rad(90)))
		end
	end
end

-- Meuble à tiroirs décoratif, dos contre un mur côté -Z.
local function createFilingCabinet(parent, cx, backZ)
	local model = newModel(parent, "FilingCabinet")
	local depth = 2.2
	local frontZ = backZ + depth
	block(model, "Body", Vector3.new(1.8, 4.5, depth), Vector3.new(cx, FLOOR_TOP + 2.25, backZ + depth / 2), COLORS.Metal, "Metal")
	for i = 0, 3 do
		local y = FLOOR_TOP + 0.6 + i * 1.1
		block(model, "DrawerLine", Vector3.new(1.7, 0.04, 0.02), Vector3.new(cx, y - 0.5, frontZ + 0.01), COLORS.DarkMetal, "Metal", { CanCollide = false })
		block(model, "Handle", Vector3.new(0.6, 0.1, 0.1), Vector3.new(cx, y, frontZ + 0.05), COLORS.DarkMetal, "Metal")
	end
end

-- Étagère métallique de la réserve : 3 niveaux de 2 cartons.
local function createStorageShelf(parent, index, cx, cz)
	local model = newModel(parent, "StorageShelf" .. index)
	local width, depth, height = 4.8, 3, 7

	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block(model, "Post", Vector3.new(0.2, height, 0.2), Vector3.new(cx + sx * (width / 2 - 0.1), FLOOR_TOP + height / 2, cz + sz * (depth / 2 - 0.1)), COLORS.DarkMetal, "Metal")
		end
	end
	local levels = { 0.3, 2.5, 4.7, 6.9 }
	local boards = {}
	for _, level in levels do
		table.insert(boards, block(model, "ShelfBoard", Vector3.new(width - 0.1, 0.15, depth - 0.1), Vector3.new(cx, FLOOR_TOP + level - 0.075, cz), COLORS.Metal, "Metal"))
	end

	local spots = makeZone(model, "Box", boards[4], 1.8)
	for level = 1, 3 do
		for _, offset in { -1.15, 1.15 } do
			createSlot(spots, "Box", CFrame.new(cx + offset, FLOOR_TOP + levels[level] + REST_HEIGHTS.Box, cz))
		end
	end
end

-- Vaisselier : 3 étagères de 6 tasses. Le dos est côté -Z.
local function createCupboard(parent, index, cx, cz)
	local model = newModel(parent, "Cupboard" .. index)
	local width, depth, height = 6, 1.6, 6

	local backPanel = block(model, "BackPanel", Vector3.new(width, height, 0.15), Vector3.new(cx, FLOOR_TOP + height / 2, cz - 0.725), COLORS.Trim, "SmoothPlastic")
	for _, side in { -1, 1 } do
		block(model, "SidePanel", Vector3.new(0.2, height, depth - 0.15), Vector3.new(cx + side * (width / 2 - 0.1), FLOOR_TOP + height / 2, cz + 0.075), COLORS.Trim, "SmoothPlastic")
	end
	block(model, "Base", Vector3.new(width - 0.4, 1, depth - 0.15), Vector3.new(cx, FLOOR_TOP + 0.5, cz + 0.075), COLORS.SignBlue, "SmoothPlastic")
	local shelfTops = { 1, 2.6, 4.2, height }
	for level = 2, 4 do
		block(model, "Shelf", Vector3.new(width - 0.4, 0.12, depth - 0.15), Vector3.new(cx, FLOOR_TOP + shelfTops[level] - 0.06, cz + 0.075), COLORS.Trim, "SmoothPlastic")
	end

	local spots = makeZone(model, "Mug", backPanel, 4.5)
	for level = 1, 3 do
		for slotIndex = 0, 5 do
			local x = cx - 2.25 + slotIndex * 0.9
			createSlot(spots, "Mug", CFrame.new(x, FLOOR_TOP + shelfTops[level] + REST_HEIGHTS.Mug, cz + 0.1))
		end
	end
end

-- Jardinière : banc bas avec 6 places de plantes, aligné sur l'axe X.
local function createPlanter(parent, index, cx, cz)
	local model = newModel(parent, "Planter" .. index)
	local length, depth, height = 7.6, 1.4, 0.8
	local top = block(model, "Top", Vector3.new(length, 0.15, depth), Vector3.new(cx, FLOOR_TOP + height - 0.075, cz), COLORS.Wood, "Wood")
	for _, side in { -1, 1 } do
		block(model, "Leg", Vector3.new(0.3, height - 0.15, depth - 0.2), Vector3.new(cx + side * (length / 2 - 0.3), FLOOR_TOP + (height - 0.15) / 2, cz), COLORS.DarkWood, "Wood")
	end
	local spots = makeZone(model, "Plant", top, 3.5)
	for slotIndex = 0, 5 do
		local x = cx - 3 + slotIndex * 1.2
		createSlot(spots, "Plant", CFrame.new(x, FLOOR_TOP + height + REST_HEIGHTS.Plant, cz))
	end
end

-- Table de la salle de pause avec 4 places de chaises autour.
local function createCafeTable(parent, index, cx, cz)
	local model = newModel(parent, "CafeTable" .. index)
	local top = FLOOR_TOP + DESK_HEIGHT
	local tableTop = block(model, "TableTop", Vector3.new(3.6, 0.2, 3.6), Vector3.new(cx, top - 0.1, cz), COLORS.Wood, "Wood")
	block(model, "Leg", Vector3.new(0.4, DESK_HEIGHT - 0.35, 0.4), Vector3.new(cx, FLOOR_TOP + 0.15 + (DESK_HEIGHT - 0.35) / 2, cz), COLORS.DarkMetal, "Metal")
	block(model, "Foot", Vector3.new(1.8, 0.15, 1.8), Vector3.new(cx, FLOOR_TOP + 0.075, cz), COLORS.DarkMetal, "Metal")
	local spots = makeZone(model, "Chair", tableTop, 4)
	for _, offset in { Vector3.new(0, 0, -2.8), Vector3.new(2.8, 0, 0), Vector3.new(0, 0, 2.8), Vector3.new(-2.8, 0, 0) } do
		local position = Vector3.new(cx + offset.X, FLOOR_TOP + REST_HEIGHTS.Chair, cz + offset.Z)
		createSlot(spots, "Chair", CFrame.lookAt(position, Vector3.new(cx, position.Y, cz)))
	end
end

-- Tapis avec des places de chaises en grille (salle d'attente, formation).
local function createChairRug(parent, name, center, size, xs, zs, yawDegrees, rugColor, billboardHeight)
	local model = newModel(parent, name)
	local rug = block(model, "Rug", Vector3.new(size.X, 0.05, size.Y), Vector3.new(center.X, FLOOR_TOP + 0.025, center.Y), rugColor, "Fabric", { CanCollide = false })
	rug.CanCollide = true -- on peut marcher et cliquer dessus
	addObstacle(center.X - size.X / 2, center.X + size.X / 2, center.Y - size.Y / 2, center.Y + size.Y / 2)
	local spots = makeZone(model, "Chair", rug, billboardHeight)
	for _, x in xs do
		for _, z in zs do
			createSlot(spots, "Chair", CFrame.new(x, FLOOR_TOP + REST_HEIGHTS.Chair, z) * CFrame.Angles(0, math.rad(yawDegrees), 0))
		end
	end
	return model
end

-- Horloge murale. "facing" est la direction vers laquelle regarde le cadran.
local function createClock(parent, position, facing)
	local model = newModel(parent, "WallClock")
	local base = CFrame.lookAt(position, position + facing)
	local rim = newPart(model, "Rim", Vector3.new(0.15, 1.8, 1.8), base * CFrame.Angles(0, math.rad(90), 0), COLORS.DarkMetal, "Metal", { CanCollide = false })
	rim.Shape = Enum.PartType.Cylinder
	local face = newPart(model, "Face", Vector3.new(0.05, 1.55, 1.55), base * CFrame.new(0, 0, -0.08) * CFrame.Angles(0, math.rad(90), 0), COLORS.Trim, "SmoothPlastic", { CanCollide = false })
	face.Shape = Enum.PartType.Cylinder
	newPart(model, "HourHand", Vector3.new(0.08, 0.45, 0.03), base * CFrame.new(0, 0, -0.12) * CFrame.Angles(0, 0, math.rad(-60)) * CFrame.new(0, 0.2, 0), COLORS.Black, "SmoothPlastic", { CanCollide = false })
	newPart(model, "MinuteHand", Vector3.new(0.06, 0.65, 0.03), base * CFrame.new(0, 0, -0.13) * CFrame.Angles(0, 0, math.rad(30)) * CFrame.new(0, 0.3, 0), COLORS.Black, "SmoothPlastic", { CanCollide = false })
end

-- Distributeur de tickets.
local function createTicketMachine(parent, x, z)
	local model = newModel(parent, "TicketMachine")
	block(model, "Base", Vector3.new(1.2, 0.15, 1.2), Vector3.new(x, FLOOR_TOP + 0.075, z), COLORS.DarkMetal, "Metal")
	block(model, "Pole", Vector3.new(0.25, 3, 0.25), Vector3.new(x, FLOOR_TOP + 1.65, z), COLORS.Metal, "Metal")
	block(model, "Box", Vector3.new(1, 1.2, 0.7), Vector3.new(x, FLOOR_TOP + 3.75, z), Color3.fromRGB(230, 80, 70), "SmoothPlastic")
	newSign(model, "Label", "TICKETS", Vector3.new(0.8, 0.35, 0.02), Vector3.new(x, FLOOR_TOP + 3.95, z + 0.36), Vector3.new(0, 0, 1), COLORS.Trim, COLORS.Black)
end

local function createWaterCooler(parent, x, z)
	local cooler = newModel(parent, "WaterCooler")
	block(cooler, "Body", Vector3.new(1.2, 3.2, 1.2), Vector3.new(x, FLOOR_TOP + 1.6, z), Color3.fromRGB(235, 235, 235), "SmoothPlastic")
	local bottle = cylinder(cooler, "Bottle", 1.2, 0.9, Vector3.new(x, FLOOR_TOP + 3.8, z), Color3.fromRGB(150, 200, 240), "Glass")
	bottle.Transparency = 0.3
end

-- Banc du couloir.
local function createBench(parent, cx, cz)
	local model = newModel(parent, "Bench")
	block(model, "Seat", Vector3.new(6, 0.3, 1.4), Vector3.new(cx, FLOOR_TOP + 1.4, cz), COLORS.Wood, "Wood")
	for _, side in { -1, 1 } do
		block(model, "Leg", Vector3.new(0.3, 1.25, 1.2), Vector3.new(cx + side * 2.6, FLOOR_TOP + 0.625, cz), COLORS.DarkMetal, "Metal")
	end
end

-- Comptoir de la salle de pause avec machine à café et évier (décor), dos côté -Z.
local function createKitchenCounter(parent, cx, backZ)
	local model = newModel(parent, "KitchenCounter")
	local depth = 2
	local cz = backZ + depth / 2
	block(model, "Cabinet", Vector3.new(10, 3.3, depth), Vector3.new(cx, FLOOR_TOP + 1.65, cz), COLORS.SignBlue, "SmoothPlastic")
	block(model, "Worktop", Vector3.new(10.2, 0.2, depth + 0.2), Vector3.new(cx, FLOOR_TOP + 3.4, cz), COLORS.Tiles, "Marble")
	block(model, "CoffeeMachine", Vector3.new(1.4, 1.8, 1.2), Vector3.new(cx - 3, FLOOR_TOP + 4.4, cz - 0.2), COLORS.Black, "SmoothPlastic")
	block(model, "CoffeeLight", Vector3.new(0.3, 0.15, 0.05), Vector3.new(cx - 3, FLOOR_TOP + 4.8, cz + 0.425), Color3.fromRGB(255, 120, 80), "Neon", { CanCollide = false })
	block(model, "Sink", Vector3.new(2.4, 0.1, 1.4), Vector3.new(cx + 2, FLOOR_TOP + 3.55, cz), COLORS.Metal, "Metal", { CanCollide = false })
	block(model, "Tap", Vector3.new(0.2, 1, 0.2), Vector3.new(cx + 2, FLOOR_TOP + 4, cz - 0.6), COLORS.Metal, "Metal")
end

-- Tableau blanc de la salle de formation (mur côté -Z).
local function createWhiteboard(parent, cx, wallZ)
	local model = newModel(parent, "Whiteboard")
	newSign(model, "Board", "INTERVIEW SKILLS WORKSHOP\nWednesday 10:00", Vector3.new(12, 4, 0.1), Vector3.new(cx, FLOOR_TOP + 6, wallZ + 0.4), Vector3.new(0, 0, 1), COLORS.White, Color3.fromRGB(40, 60, 120))
	block(model, "Frame", Vector3.new(12.4, 4.4, 0.08), Vector3.new(cx, FLOOR_TOP + 6, wallZ + 0.3), COLORS.Metal, "Metal", { CanCollide = false })
	block(model, "Tray", Vector3.new(10, 0.15, 0.4), Vector3.new(cx, FLOOR_TOP + 3.9, wallZ + 0.5), COLORS.Metal, "Metal", { CanCollide = false })
end

local function poster(parent, text, position, facing, color)
	newSign(parent, "Poster", text, Vector3.new(5, 3.4, 0.1), position, facing, color)
end

---------------------------------------------------------------------------
-- Aménagement de chaque pièce
---------------------------------------------------------------------------
local function furnishAccueil(parent)
	createReception(parent, 0, 34)
	createChairRug(parent, "WaitingArea", Vector2.new(19, 50), Vector2.new(16, 16), { 14, 18, 22 }, { 44, 46.5, 49, 51.5, 54, 56.5 }, -90, COLORS.Rug, 6)
	newSign(parent, "NowServingScreen", "NOW SERVING   A-047", Vector3.new(6, 2, 0.2), Vector3.new(29.65, FLOOR_TOP + 6.5, 50), Vector3.new(-1, 0, 0), COLORS.Black, Color3.fromRGB(255, 90, 70))
	newSign(parent, "WaitingSign", "WAITING AREA", Vector3.new(6, 0.9, 0.2), Vector3.new(29.65, FLOOR_TOP + 8.6, 50), Vector3.new(-1, 0, 0))
	createTicketMachine(parent, -8, 50)
	createWaterCooler(parent, -28.5, 52)

	local board = newModel(parent, "JobOffersBoard")
	local boardZ = HALF_Z - 0.08
	block(board, "Cork", Vector3.new(8, 4, 0.15), Vector3.new(-18, FLOOR_TOP + 5, boardZ), COLORS.Cork, "Fabric")
	newSign(board, "Title", "JOB BOARD", Vector3.new(8, 0.9, 0.1), Vector3.new(-18, FLOOR_TOP + 7.6, HALF_Z - 0.05), Vector3.new(0, 0, -1))
	local tilt = { -4, 3, -2, 5, -3, 2 }
	local n = 0
	for _, y in { FLOOR_TOP + 5.9, FLOOR_TOP + 4.1 } do
		for _, x in { -21, -18, -15 } do
			n += 1
			newPart(board, "JobOffer", Vector3.new(1.6, 1.4, 0.02), CFrame.new(x, y, boardZ - 0.085) * CFrame.Angles(0, 0, math.rad(tilt[n])), COLORS.Paper, "SmoothPlastic", { CanCollide = false })
		end
	end

	poster(parent, "PLEASE TAKE\nA TICKET", Vector3.new(0, FLOOR_TOP + 7, 20.3), Vector3.new(0, 0, 1), COLORS.SignBlue)
	createClock(parent, Vector3.new(12, FLOOR_TOP + 8, HALF_Z - 0.1), Vector3.new(0, 0, -1))
	for _, p in { { -28, 58 }, { 27, 23 }, { -27, 23 } } do
		createPlant(parent, p[1], p[2])
	end
end

local function furnishBureaux(parent)
	local index = 0
	for _, z in { -46, -30, -14 } do
		for _, x in { -66, -50, -34, -18 } do
			index += 1
			createAdvisorDesk(parent, index, x, z)
		end
	end
	createPlanter(parent, 1, -60, -59.3)
	createPlanter(parent, 2, -30, -59.3)
	poster(parent, "CV WORKSHOP\nTUESDAYS 2 PM", Vector3.new(-45, FLOOR_TOP + 7, -HALF_Z + 0.05), Vector3.new(0, 0, 1), COLORS.SignBlue)
	poster(parent, "INTERVIEWS BY\nAPPOINTMENT ONLY", Vector3.new(-15, FLOOR_TOP + 7, -HALF_Z + 0.05), Vector3.new(0, 0, 1), Color3.fromRGB(70, 74, 82))
	createClock(parent, Vector3.new(-75, FLOOR_TOP + 8, -HALF_Z + 0.1), Vector3.new(0, 0, 1))
	createWaterCooler(parent, -4, -56)
	for _, p in { { -77, -57 }, { -77, 17 }, { -3, 17 } } do
		createPlant(parent, p[1], p[2])
	end
end

local function furnishCouloir(parent)
	createPlanter(parent, 3, 42, 19.05)
	createPlanter(parent, 4, 58, 19.05)
	createBench(parent, 45, -8.6)
	createBench(parent, 10, -8.6)
	poster(parent, "CAREER TRAINING\nPROGRAMS", Vector3.new(HALF_X - 0.05, FLOOR_TOP + 7, 17), Vector3.new(-1, 0, 0), Color3.fromRGB(52, 80, 70))
	poster(parent, "LOCAL EMPLOYERS\nARE HIRING", Vector3.new(40, FLOOR_TOP + 7, -9.7), Vector3.new(0, 0, 1), COLORS.SignBlue)
	createPlant(parent, 77, -7)
end

local function furnishPause(parent)
	createCupboard(parent, 1, -72, 21)
	createCupboard(parent, 2, -62, 21)
	createKitchenCounter(parent, -44, 20.25)
	local index = 0
	for _, z in { 34, 48 } do
		for _, x in { -66, -50 } do
			index += 1
			createCafeTable(parent, index, x, z)
		end
	end
	poster(parent, "PLEASE CLEAN UP\nAFTER YOURSELF", Vector3.new(-55, FLOOR_TOP + 7, HALF_Z - 0.05), Vector3.new(0, 0, -1), Color3.fromRGB(70, 74, 82))
	createClock(parent, Vector3.new(-40, FLOOR_TOP + 8, HALF_Z - 0.1), Vector3.new(0, 0, -1))
	block(parent, "Fridge", Vector3.new(2.4, 6, 2.2), Vector3.new(-78.5, FLOOR_TOP + 3, 57.5), COLORS.White, "SmoothPlastic")
	createPlant(parent, -33, 57)
end

local function furnishArchives(parent)
	for index, x in { 8, 18, 28, 38 } do
		createArchiveShelf(parent, index, x, -HALF_Z + 1)
	end
	createFilingCabinet(parent, 44.6, -HALF_Z)
	createFilingCabinet(parent, 46.6, -HALF_Z)
	local tableModel = newModel(parent, "ReadingTable")
	block(tableModel, "TableTop", Vector3.new(8, 0.2, 3.5), Vector3.new(25, FLOOR_TOP + DESK_HEIGHT - 0.1, -34), COLORS.Wood, "Wood")
	for _, sx in { -1, 1 } do
		block(tableModel, "Leg", Vector3.new(0.3, DESK_HEIGHT - 0.2, 3), Vector3.new(25 + sx * 3.7, FLOOR_TOP + (DESK_HEIGHT - 0.2) / 2, -34), COLORS.DarkWood, "Wood")
	end
	createOfficeChair(parent, Vector3.new(22, FLOOR_TOP, -31.4), 0)
	createOfficeChair(parent, Vector3.new(28, FLOOR_TOP, -31.4), 0)
	createPlant(parent, 3, -13)
end

local function furnishReserve(parent)
	local index = 0
	for _, x in { 56, 65, 74 } do
		index += 1
		createStorageShelf(parent, index, x, -HALF_Z + 1.5)
	end
	for _, x in { 56, 65, 74 } do
		index += 1
		createStorageShelf(parent, index, x, -36)
	end
end

local function furnishFormation(parent)
	createWhiteboard(parent, 55, 20)
	createTeacherDesk(parent, 55, 28)
	createChairRug(parent, "TrainingRows", Vector2.new(55, 45), Vector2.new(30, 16), { 45, 50, 55, 60, 65 }, { 39, 43, 47, 51 }, 0, COLORS.GreenRug, 6)
	createPlanter(parent, 5, 70, 59.3)
	poster(parent, "PREPARING FOR\nYOUR INTERVIEW", Vector3.new(40, FLOOR_TOP + 7, HALF_Z - 0.05), Vector3.new(0, 0, -1), COLORS.SignBlue)
	createClock(parent, Vector3.new(78, FLOOR_TOP + 8, HALF_Z - 0.1), Vector3.new(0, 0, -1))
	createPlant(parent, 33, 23)
end

---------------------------------------------------------------------------
-- Objets à ranger
---------------------------------------------------------------------------

local function weldToMain(main, part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = main
	weld.Part1 = part
	weld.Parent = main
end

-- Fabrique les pièces d'un objet autour de l'origine. Renvoie le modèle et sa pièce principale.
local function buildItemParts(itemType, index)
	local model = Instance.new("Model")
	model.Name = itemType .. index
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local size = ITEM_SIZES[itemType]
	local main

	if itemType == "Folder" then
		main = newPart(model, "Main", size, CFrame.new(), FOLDER_COLORS[(index - 1) % #FOLDER_COLORS + 1], "SmoothPlastic")
		local label = newPart(model, "Label", Vector3.new(0.6, 0.02, 0.9), CFrame.new(0, 0.08, 0), COLORS.Paper, "SmoothPlastic")
		label.CanCollide = false
		weldToMain(main, label)
	elseif itemType == "Paper" then
		main = newPart(model, "Main", size, CFrame.new(), COLORS.Paper, "SmoothPlastic")
		local sheet = newPart(model, "TopSheet", Vector3.new(1.05, 0.02, 1.45), CFrame.new(0.05, 0.135, -0.03) * CFrame.Angles(0, math.rad(7), 0), SHEET_COLORS[(index - 1) % #SHEET_COLORS + 1], "SmoothPlastic")
		sheet.CanCollide = false
		weldToMain(main, sheet)
	elseif itemType == "Chair" then
		-- La pièce principale est l'assise. La chaise regarde vers -Z.
		local chairColor = CHAIR_COLORS[(index - 1) % #CHAIR_COLORS + 1]
		main = newPart(model, "Main", size, CFrame.new(), chairColor, "Plastic")
		local back = newPart(model, "Back", Vector3.new(2, 2, 0.25), CFrame.new(0, 1.175, 0.875), chairColor, "Plastic")
		weldToMain(main, back)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local leg = newPart(model, "Leg", Vector3.new(0.15, 1.625, 0.15), CFrame.new(0.85 * sx, -0.9875, 0.85 * sz), COLORS.Metal, "Metal")
				weldToMain(main, leg)
			end
		end
	elseif itemType == "Box" then
		main = newPart(model, "Main", size, CFrame.new(), COLORS.Cardboard, "Cardboard")
		local tape = newPart(model, "Tape", Vector3.new(size.X + 0.04, 0.02, 0.45), CFrame.new(0, size.Y / 2 + 0.005, 0), COLORS.Tape, "SmoothPlastic")
		tape.CanCollide = false
		weldToMain(main, tape)
		local sticker = newPart(model, "Sticker", Vector3.new(0.9, 0.6, 0.02), CFrame.new(0, 0, -size.Z / 2 - 0.01), STICKER_COLORS[(index - 1) % #STICKER_COLORS + 1], "SmoothPlastic")
		sticker.CanCollide = false
		weldToMain(main, sticker)
	elseif itemType == "Mug" then
		-- La pièce principale est une boîte invisible qui sert à cliquer et à ranger.
		main = newPart(model, "Main", size, CFrame.new(), COLORS.White, "SmoothPlastic", { Transparency = 1 })
		local mugColor = MUG_COLORS[(index - 1) % #MUG_COLORS + 1]
		local body = newPart(model, "Body", Vector3.new(0.55, 0.46, 0.46), CFrame.Angles(0, 0, math.rad(90)), mugColor, "SmoothPlastic")
		body.Shape = Enum.PartType.Cylinder
		body.CanCollide = false
		weldToMain(main, body)
		local handle = newPart(model, "Handle", Vector3.new(0.1, 0.3, 0.12), CFrame.new(0.28, 0, 0), mugColor, "SmoothPlastic")
		handle.CanCollide = false
		weldToMain(main, handle)
	elseif itemType == "Plant" then
		main = newPart(model, "Main", size, CFrame.new(), COLORS.Plant, "SmoothPlastic", { Transparency = 1 })
		local pot = newPart(model, "Pot", Vector3.new(0.8, 0.9, 0.9), CFrame.new(0, -0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), POT_COLORS[(index - 1) % #POT_COLORS + 1], "SmoothPlastic")
		pot.Shape = Enum.PartType.Cylinder
		pot.CanCollide = false
		weldToMain(main, pot)
		local leaves = newPart(model, "Leaves", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 0.3, 0), COLORS.Plant, "Grass")
		leaves.Shape = Enum.PartType.Ball
		leaves.CanCollide = false
		weldToMain(main, leaves)
		local sprout = newPart(model, "Sprout", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0.15, 0.6, 0.1), Color3.fromRGB(100, 190, 90), "Grass")
		sprout.Shape = Enum.PartType.Ball
		sprout.CanCollide = false
		weldToMain(main, sprout)
	else
		error("Unknown item type: " .. tostring(itemType))
	end

	model.PrimaryPart = main
	return model, main
end

local function createItem(parent, itemType, index, homeCFrame, roomId)
	local model = buildItemParts(itemType, index)
	model:PivotTo(homeCFrame)
	model:SetAttribute("ItemType", itemType)
	model:SetAttribute("State", "Loose")
	model:SetAttribute("HomeCFrame", homeCFrame)
	model:SetAttribute("RestHeight", REST_HEIGHTS[itemType])
	model:SetAttribute("Room", roomId)
	model.Parent = parent
	CollectionService:AddTag(model, TidyConfig.ItemTag)
	return model
end

local function overlapsObstacle(x, z, radius)
	for _, o in obstacles do
		if x + radius > o[1] and x - radius < o[2] and z + radius > o[3] and z - radius < o[4] then
			return true
		end
	end
	return false
end

local function overlapsItems(placed, x, z, radius)
	for _, p in placed do
		local dx, dz = p[1] - x, p[2] - z
		if dx * dx + dz * dz < (p[3] + radius) ^ 2 then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Éclairage et point d'apparition
---------------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = 0
	Lighting.Ambient = Color3.fromRGB(110, 110, 112)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 130)
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true

	local colorCorrection = Lighting:FindFirstChild("AgencyColorCorrection")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "AgencyColorCorrection"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Brightness = 0
	colorCorrection.Saturation = -0.05
	colorCorrection.Contrast = 0.05
	colorCorrection.TintColor = Color3.fromRGB(250, 250, 255)

	local bloom = Lighting:FindFirstChild("AgencyBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "AgencyBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.1
	bloom.Size = 20
	bloom.Threshold = 2.5
end

local function createSpawn(parent)
	-- Supprime le point d'apparition du modèle pour que le joueur commence dans l'agence.
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			descendant:Destroy()
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "AgencySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = CFrame.new(0, FLOOR_TOP + 0.1, HALF_Z - 6)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = false
	spawn.CastShadow = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = true
	spawn.Parent = parent
	return spawn
end

---------------------------------------------------------------------------
-- Fonctions principales
---------------------------------------------------------------------------
local itemsFolder = nil
local currentItems = {}

-- Construit le bâtiment, le mobilier et les zones (une seule fois).
function AgencyBuilder.Build()
	local old = Workspace:FindFirstChild("EmploymentAgency")
	if old then
		old:Destroy()
	end
	table.clear(obstacles)
	table.clear(allSlots)
	table.clear(allZones)
	table.clear(allDoors)

	setupLighting()

	local root = Instance.new("Model")
	root.Name = "EmploymentAgency"

	local structure = newFolder(root, "Building")
	local furniture = newFolder(root, "Furniture")
	itemsFolder = newFolder(root, "MisplacedItems")

	collectObstacles = true
	buildStructure(structure)
	furnishAccueil(newFolder(furniture, "Reception"))
	furnishBureaux(newFolder(furniture, "Offices"))
	furnishCouloir(newFolder(furniture, "Hallway"))
	furnishPause(newFolder(furniture, "BreakRoom"))
	furnishArchives(newFolder(furniture, "Archives"))
	furnishReserve(newFolder(furniture, "Storage"))
	furnishFormation(newFolder(furniture, "Training"))
	collectObstacles = false

	-- Endroit laissé libre : arrivée du joueur.
	addObstacle(-5, 5, 48, HALF_Z)

	createSpawn(root)
	root.Parent = Workspace

	return {
		Root = root,
		Zones = allZones,
		Slots = allSlots,
		Doors = allDoors,
	}
end

-- Éparpille de nouveaux objets dans chaque pièce. Supprime ceux de la partie précédente.
-- Renvoie la liste des objets créés.
function AgencyBuilder.ScatterItems(seed)
	for _, item in currentItems do
		item:Destroy()
	end
	table.clear(currentItems)
	for _, slot in allSlots do
		slot:SetAttribute("Occupied", false)
	end

	local rng = Random.new(seed)
	local placed = {}
	local counters = {}
	for _, room in TidyConfig.Rooms do
		for _, itemType in TidyConfig.TypeOrder do
			local count = room.Items[itemType] or 0
			for _ = 1, count do
				counters[itemType] = (counters[itemType] or 0) + 1
				local index = counters[itemType]
				local tipped = TIPPED[itemType] ~= nil and rng:NextNumber() < 0.45
				local radius = if tipped then TIPPED[itemType].Radius else ITEM_RADIUS[itemType]
				local found = false
				local x, z = 0, 0
				for _ = 1, 400 do
					x = rng:NextNumber(room.MinX + radius + 1, room.MaxX - radius - 1)
					z = rng:NextNumber(room.MinZ + radius + 1, room.MaxZ - radius - 1)
					if not overlapsObstacle(x, z, radius) and not overlapsItems(placed, x, z, radius) then
						found = true
						break
					end
				end
				if found then
					table.insert(placed, { x, z, radius })
					local base = CFrame.new(x, FLOOR_TOP, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					local home
					if tipped then
						home = base * CFrame.new(0, TIPPED[itemType].Height, 0) * CFrame.Angles(0, 0, math.rad(90))
					else
						home = base * CFrame.new(0, REST_HEIGHTS[itemType], 0)
					end
					table.insert(currentItems, createItem(itemsFolder, itemType, index, home, room.Id))
				else
					warn("[AgencyBuilder] No free floor space for " .. itemType .. index .. " in " .. room.Id)
				end
			end
		end
	end

	return table.clone(currentItems)
end

-- Dossier où vivent les objets qui traînent.
function AgencyBuilder.GetItemsFolder()
	return itemsFolder
end

-- Dimensions utiles au gestionnaire (lâcher un objet).
AgencyBuilder.FloorTop = FLOOR_TOP
AgencyBuilder.HalfX = HALF_X
AgencyBuilder.HalfZ = HALF_Z

return AgencyBuilder
