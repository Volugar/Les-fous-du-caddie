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
-- X = -80 à 80 et de Z = -100 à 60. La surface du sol est à Y = 1.
---------------------------------------------------------------------------
local FLOOR_TOP = 1
local HALF_X = 80
local HALF_Z = 60 -- côté sud (entrée) : Z = 60
local MIN_Z = -100 -- côté nord (aile nord ajoutée) : Z = -100
local MAX_Z = HALF_Z
local MID_Z = (MIN_Z + MAX_Z) / 2
local DEPTH_Z = MAX_Z - MIN_Z
local WALL_HEIGHT = 12
local CEILING_BOTTOM = FLOOR_TOP + WALL_HEIGHT
local GROUND_TOP = FLOOR_TOP
local UPPER_TOP = TidyConfig.FloorHeights[2]

-- Change l'étage en cours de construction (toutes les hauteurs suivent).
local function setFloor(top)
	FLOOR_TOP = top
	CEILING_BOTTOM = top + WALL_HEIGHT
end
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
	Book = Vector3.new(0.3, 1.1, 0.8),
	Parcel = Vector3.new(0.8, 0.6, 0.8),
	Laptop = Vector3.new(1.2, 0.1, 0.9),
	Cushion = Vector3.new(1.2, 0.4, 1.2),
}

-- Distance entre le sol et le centre de la pièce principale de chaque objet.
local REST_HEIGHTS = {
	Folder = 0.075,
	Paper = 0.125,
	Chair = 1.8,
	Box = 0.8,
	Mug = 0.275,
	Plant = 0.95,
	Book = 0.55,
	Parcel = 0.3,
	Laptop = 0.05,
	Cushion = 0.2,
}

-- Objets qui peuvent être renversés : hauteur et rayon une fois couchés.
local TIPPED = {
	Chair = { Height = 1, Radius = 2.4 },
	Mug = { Height = 0.25, Radius = 0.6 },
	Plant = { Height = 0.6, Radius = 1.2 },
	Book = { Height = 0.15, Radius = 0.7, Always = true }, -- un livre qui traîne est posé à plat
}

-- Rayon occupé au sol par chaque objet (pour ne pas les poser les uns sur les autres).
local ITEM_RADIUS = {
	Folder = 1.1,
	Paper = 1,
	Chair = 1.6,
	Box = 1.5,
	Mug = 0.5,
	Plant = 0.8,
	Book = 0.7,
	Parcel = 0.7,
	Laptop = 0.8,
	Cushion = 0.9,
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
	BoothFabric = Color3.fromRGB(122, 132, 144),
	BookcaseWood = Color3.fromRGB(120, 92, 66),
	Sofa = Color3.fromRGB(70, 82, 100),
	Laptop = Color3.fromRGB(60, 62, 68),
	Bulb = Color3.fromRGB(255, 226, 170),
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
local CUSHION_COLORS = {
	Color3.fromRGB(196, 170, 120),
	Color3.fromRGB(150, 70, 60),
	Color3.fromRGB(90, 120, 110),
	Color3.fromRGB(220, 214, 200),
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
	table.insert(obstacles, { minX, maxX, minZ, maxZ, FLOOR_TOP })
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
local function makeZone(model, itemType, anchorPart, billboardHeight, categoryId)
	local room = TidyConfig.GetRoomAt(anchorPart.Position)
	local category = categoryId and TidyConfig.GetCategory(itemType, categoryId)
	local zoneLabel = TidyConfig.ItemTypes[itemType].PlaceName
	if category then
		zoneLabel = zoneLabel .. " - " .. category.Name
	end
	model:SetAttribute("ItemType", itemType)
	model:SetAttribute("ZoneLabel", zoneLabel)
	model:SetAttribute("Room", room and room.Id or "")
	if category then
		model:SetAttribute("Category", category.Id)
	end
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
	label.BackgroundColor3 = if category then category.Color else COLORS.SignBlue
	label.BackgroundTransparency = 0.1
	label.Font = Enum.Font.GothamBold
	label.Text = zoneLabel
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
local function createSlot(spotsFolder, itemType, targetCFrame, categoryId)
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
	if categoryId then
		slot:SetAttribute("Category", categoryId)
	end
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
local function windowedSideWall(parent, name, x, windows, insideDirection, minZ, maxZ, baseY)
	minZ = minZ or MIN_Z
	maxZ = maxZ or MAX_Z
	baseY = baseY or 0
	local sillY = FLOOR_TOP + 3
	local windowTop = FLOOR_TOP + 9
	local wallHeight = CEILING_BOTTOM
	local length = maxZ - minZ
	local midZ = (minZ + maxZ) / 2
	block(parent, name .. "Low", Vector3.new(1, sillY - baseY, length), Vector3.new(x, (baseY + sillY) / 2, midZ), COLORS.Wall, "Plaster")
	block(parent, name .. "High", Vector3.new(1, wallHeight - windowTop, length), Vector3.new(x, (windowTop + wallHeight) / 2, midZ), COLORS.Wall, "Plaster")
	local windowHeight = windowTop - sillY
	local windowY = (sillY + windowTop) / 2
	local cursor = minZ
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
	local last = maxZ - cursor
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
	floor("BoothsFloor", -80, -20, -100, -60, COLORS.Carpet, "Carpet")
	floor("LibraryFloor", -20, 30, -100, -60, COLORS.WarmCarpet, "Carpet")
	floor("MailRoomFloor", 30, 80, -100, -60, COLORS.Concrete, "Concrete")

	-- Murs extérieurs (hors de la zone intérieure).
	local wallHeight = CEILING_BOTTOM
	local wallY = wallHeight / 2
	local fullLengthX = HALF_X * 2 + 2
	local fullLengthZ = DEPTH_Z + 2

	block(parent, "NorthWall", Vector3.new(fullLengthX, wallHeight, 1), Vector3.new(0, wallY, MIN_Z - 0.5), COLORS.Wall, "Plaster")

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
	windowedSideWall(parent, "WestWall", -HALF_X - 0.5, { { -92, -70 }, { -52, -36 }, { -26, -10 }, { 0, 14 }, { 28, 52 } }, 1)
	windowedSideWall(parent, "EastWall", HALF_X + 0.5, { { -92, -70 }, { -48, -24 }, { -6, 14 }, { 26, 54 } }, -1)

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
	interiorWallAlongX(parent, -60, -80, 80, { door(-50, -42, "Booths"), door(-12, -4, "Library"), door(38, 46, "MailRoom") })
	interiorWallAlongZ(parent, -20, -100, -60, { door(-84, -76, "Library") })
	interiorWallAlongZ(parent, 30, -100, -60, { door(-84, -76, "MailRoom") })
	for _, d in doors do
		createLockedDoor(parent, d)
	end

	-- Nom des pièces au-dessus des portes.
	local signY = FLOOR_TOP + DOOR_HEIGHT + 1.5
	local roomSigns = {
		{ "OFFICES", Vector3.new(-15, signY, 20.3), Vector3.new(0, 0, 1) },
		{ "SELF-SERVICE", Vector3.new(15, signY, 20.3), Vector3.new(0, 0, 1) },
		{ "BREAK ROOM", Vector3.new(-29.7, signY, 40), Vector3.new(1, 0, 0) },
		{ "WORKSHOPS", Vector3.new(29.7, signY, 40), Vector3.new(-1, 0, 0) },
		{ "ARCHIVES", Vector3.new(25, signY, -9.7), Vector3.new(0, 0, 1) },
		{ "STORAGE", Vector3.new(65, signY, -9.7), Vector3.new(0, 0, 1) },
		{ "OFFICES", Vector3.new(0.3, signY, 5), Vector3.new(1, 0, 0) },
		{ "INTERVIEW BOOTHS", Vector3.new(-46, signY, -59.7), Vector3.new(0, 0, 1) },
		{ "LIBRARY", Vector3.new(-8, signY, -59.7), Vector3.new(0, 0, 1) },
		{ "MAIL ROOM", Vector3.new(42, signY, -59.7), Vector3.new(0, 0, 1) },
		{ "LIBRARY", Vector3.new(-19.7, signY, -80), Vector3.new(1, 0, 0) },
		{ "MAIL ROOM", Vector3.new(29.7, signY, -80), Vector3.new(1, 0, 0) },
	}
	for _, sign in roomSigns do
		newSign(parent, "RoomSign", sign[1], Vector3.new(7, 1.2, 0.1), sign[2], sign[3])
	end

	-- Faux plafond à dalles : fond clair et grille métallique.
	block(parent, "Ceiling", Vector3.new(fullLengthX, 1, fullLengthZ), Vector3.new(0, CEILING_BOTTOM + 0.5, MID_Z), COLORS.Ceiling, "SmoothPlastic")
	local gridX = -HALF_X + 4
	while gridX < HALF_X do
		block(parent, "CeilingGrid", Vector3.new(0.12, 0.06, DEPTH_Z), Vector3.new(gridX, CEILING_BOTTOM - 0.03, MID_Z), COLORS.CeilingGrid, "Metal", { CanCollide = false, CastShadow = false })
		gridX += 4
	end
	local gridZ = MIN_Z + 4
	while gridZ < MAX_Z do
		block(parent, "CeilingGrid", Vector3.new(HALF_X * 2, 0.06, 0.12), Vector3.new(0, CEILING_BOTTOM - 0.03, gridZ), COLORS.CeilingGrid, "Metal", { CanCollide = false, CastShadow = false })
		gridZ += 4
	end

	-- Luminaires encastrés, répartis dans chaque pièce (alignés sur la grille du plafond).
	for _, room in TidyConfig.Rooms do
		if TidyConfig.FloorHeights[room.Floor or 1] ~= FLOOR_TOP then
			continue
		end
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
	band("NorthBand", Vector3.new(HALF_X * 2, 3, 0.1), Vector3.new(0, bandY, MIN_Z + 0.05), true)
	band("EastBand", Vector3.new(0.1, 3, DEPTH_Z), Vector3.new(HALF_X - 0.05, bandY, MID_Z), false)
	band("WestBand", Vector3.new(0.1, 3, DEPTH_Z), Vector3.new(-HALF_X + 0.05, bandY, MID_Z), false)
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

-- Box d'entretien individuel : cloisons, bureau, bac à documents et 2 places de chaises.
-- facing = 1 : la box s'ouvre vers +Z ; facing = -1 : elle s'ouvre vers -Z.
local function createBooth(parent, index, cx, cz, facing)
	local model = newModel(parent, "InterviewBooth" .. index)
	local base = CFrame.new(cx, FLOOR_TOP, cz) * (if facing == 1 then CFrame.new() else CFrame.Angles(0, math.pi, 0))
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local top = DESK_HEIGHT

	newPart(model, "BackWall", Vector3.new(7.6, 4.5, 0.3), at(0, 2.25, -4.15), COLORS.BoothFabric, "Fabric")
	for _, side in { -1, 1 } do
		newPart(model, "SideWall", Vector3.new(0.3, 4.5, 7.7), at(side * 3.65, 2.25, -0.15), COLORS.BoothFabric, "Fabric")
	end
	local desktop = newPart(model, "Desktop", Vector3.new(4.4, 0.15, 1.6), at(0, top - 0.075, -1.2), COLORS.Wood, "Wood")
	for _, side in { -1, 1 } do
		newPart(model, "DeskSide", Vector3.new(0.15, top - 0.15, 1.4), at(side * 2.1, (top - 0.15) / 2, -1.2), COLORS.Metal, "SmoothPlastic")
	end
	newPart(model, "ModestyPanel", Vector3.new(4, 1.4, 0.08), at(0, 1.5, -0.5), COLORS.Metal, "SmoothPlastic")
	newPart(model, "MonitorStand", Vector3.new(0.4, 0.5, 0.3), at(-0.9, top + 0.25, -1.2), COLORS.Black, "SmoothPlastic")
	newPart(model, "Monitor", Vector3.new(2, 1.2, 0.1), at(-0.9, top + 1.1, -1.2), COLORS.Black, "SmoothPlastic")
	newPart(model, "Keyboard", Vector3.new(1.4, 0.06, 0.45), at(-0.9, top + 0.03, -1.75), COLORS.Black, "SmoothPlastic")
	createOfficeChair(model, at(0, 0, -2.85).Position, if facing == 1 then math.pi else 0)
	newSign(model, "BoothNumber", "BOOTH " .. index, Vector3.new(2.4, 0.6, 0.05), at(0, 3.6, -3.97).Position, base.LookVector * -1, COLORS.SignBlue)

	-- Bac à documents sur le bureau (zone "papiers").
	local paperSpots = makeZone(model, "Paper", desktop, 3.5)
	createTray(model, paperSpots, at(1.2, top, -1.2).Position)

	-- Tapis de la box (zone "chaises") avec 2 places face au bureau.
	local chairZone = newModel(model, "BoothChairs")
	local mat = newPart(chairZone, "BoothMat", Vector3.new(6.9, 0.05, 7.6), at(0, 0.025, -0.15), COLORS.GreenRug, "Fabric", { CanCollide = false })
	mat.CanCollide = true
	local chairSpots = makeZone(chairZone, "Chair", mat, 4.5)
	for _, x in { -1.3, 1.3 } do
		createSlot(chairSpots, "Chair", at(x, REST_HEIGHTS.Chair, 1.7))
	end
	addObstacle(cx - 4, cx + 4, cz - 4.6, cz + 4.6)
end

-- Bibliothèque : 3 étagères de 8 livres debout et une étiquette de couleur (catégorie).
-- Le dos est côté -Z.
local function createBookcase(parent, index, cx, cz, categoryId)
	local category = TidyConfig.GetCategory("Book", categoryId)
	local model = newModel(parent, "Bookcase" .. index)
	local width, depth, height = 6, 1.2, 7
	local backPanel = block(model, "BackPanel", Vector3.new(width, height, 0.1), Vector3.new(cx, FLOOR_TOP + height / 2, cz - 0.55), COLORS.BookcaseWood, "Wood")
	for _, side in { -1, 1 } do
		block(model, "SidePanel", Vector3.new(0.2, height, depth - 0.1), Vector3.new(cx + side * (width / 2 - 0.1), FLOOR_TOP + height / 2, cz + 0.05), COLORS.BookcaseWood, "Wood")
	end
	local shelfTops = { 0.3, 2, 3.7, 5.4, height }
	for _, shelfTop in shelfTops do
		block(model, "Shelf", Vector3.new(width - 0.4, 0.12, depth - 0.1), Vector3.new(cx, FLOOR_TOP + shelfTop - 0.06, cz + 0.05), COLORS.BookcaseWood, "Wood")
	end
	-- Rangée du haut : livres déjà rangés (décor), dans des teintes de la catégorie.
	for i = 0, 9 do
		local shade = 0.75 + (i % 3) * 0.12
		local color = Color3.new(category.Color.R * shade, category.Color.G * shade, category.Color.B * shade)
		block(model, "ShelvedBook", Vector3.new(0.3, 1.1, 0.8), Vector3.new(cx - 2.4 + i * 0.53, FLOOR_TOP + shelfTops[4] + 0.55, cz + 0.05), color, "SmoothPlastic")
	end
	newSign(model, "CategoryLabel", string.upper(category.Name), Vector3.new(5.6, 0.6, 0.05), Vector3.new(cx, FLOOR_TOP + height + 0.4, cz + 0.55), Vector3.new(0, 0, 1), category.Color)

	local spots = makeZone(model, "Book", backPanel, 5.5, categoryId)
	for level = 1, 3 do
		for i = 0, 7 do
			local x = cx - 2.28 + i * 0.65
			createSlot(spots, "Book", CFrame.new(x, FLOOR_TOP + shelfTops[level] + REST_HEIGHTS.Book, cz + 0.05), categoryId)
		end
	end
end

-- Casier à colis : 3 niveaux de 6 cases, avec une étiquette de couleur. Le dos est côté -Z.
local function createPigeonholes(parent, index, cx, cz, categoryId)
	local category = TidyConfig.GetCategory("Parcel", categoryId)
	local model = newModel(parent, "Pigeonholes" .. index)
	local width, depth, height = 6, 1.4, 6
	local backPanel = block(model, "BackPanel", Vector3.new(width, height, 0.1), Vector3.new(cx, FLOOR_TOP + height / 2, cz - 0.65), COLORS.Metal, "Metal")
	for _, side in { -1, 1 } do
		block(model, "SidePanel", Vector3.new(0.2, height, depth - 0.1), Vector3.new(cx + side * (width / 2 - 0.1), FLOOR_TOP + height / 2, cz + 0.05), COLORS.Metal, "Metal")
	end
	block(model, "Base", Vector3.new(width - 0.4, 0.8, depth - 0.1), Vector3.new(cx, FLOOR_TOP + 0.4, cz + 0.05), COLORS.DarkMetal, "Metal")
	local levels = { 0.8, 2.4, 4, height }
	for level = 2, 4 do
		block(model, "Shelf", Vector3.new(width - 0.4, 0.1, depth - 0.1), Vector3.new(cx, FLOOR_TOP + levels[level] - 0.05, cz + 0.05), COLORS.Metal, "Metal")
	end
	for level = 1, 3 do
		for k = 0, 4 do
			block(model, "Divider", Vector3.new(0.05, 1.5, depth - 0.2), Vector3.new(cx - 1.8 + k * 0.9, FLOOR_TOP + levels[level] + 0.75, cz + 0.05), COLORS.Metal, "Metal")
		end
	end
	newSign(model, "CategoryLabel", string.upper(category.Name), Vector3.new(5.6, 0.6, 0.05), Vector3.new(cx, FLOOR_TOP + height + 0.4, cz + 0.65), Vector3.new(0, 0, 1), category.Color)

	local spots = makeZone(model, "Parcel", backPanel, 5, categoryId)
	for level = 1, 3 do
		for i = 0, 5 do
			createSlot(spots, "Parcel", CFrame.new(cx - 2.25 + i * 0.9, FLOOR_TOP + levels[level] + REST_HEIGHTS.Parcel, cz + 0.05), categoryId)
		end
	end
end

-- Poste informatique en libre-service, avec une place de chaise.
local function createKiosk(parent, index, cx, cz)
	local model = newModel(parent, "ComputerKiosk" .. index)
	local top = FLOOR_TOP + DESK_HEIGHT
	local desktop = block(model, "Desktop", Vector3.new(3, 0.15, 1.6), Vector3.new(cx, top - 0.075, cz), COLORS.White, "SmoothPlastic")
	for _, side in { -1, 1 } do
		block(model, "Side", Vector3.new(0.15, DESK_HEIGHT - 0.15, 1.4), Vector3.new(cx + side * 1.4, FLOOR_TOP + (DESK_HEIGHT - 0.15) / 2, cz), COLORS.Metal, "SmoothPlastic")
	end
	block(model, "MonitorStand", Vector3.new(0.4, 0.5, 0.3), Vector3.new(cx, top + 0.25, cz - 0.4), COLORS.Black, "SmoothPlastic")
	block(model, "Monitor", Vector3.new(1.8, 1.1, 0.1), Vector3.new(cx, top + 1.05, cz - 0.4), COLORS.Black, "SmoothPlastic")
	block(model, "Screen", Vector3.new(1.6, 0.9, 0.02), Vector3.new(cx, top + 1.05, cz - 0.34), Color3.fromRGB(120, 160, 205), "Neon", { CanCollide = false, Transparency = 0.2 })
	block(model, "Keyboard", Vector3.new(1.4, 0.06, 0.45), Vector3.new(cx, top + 0.03, cz + 0.3), COLORS.Black, "SmoothPlastic")
	block(model, "Mouse", Vector3.new(0.22, 0.06, 0.35), Vector3.new(cx + 0.95, top + 0.03, cz + 0.3), COLORS.Black, "SmoothPlastic")
	local spots = makeZone(model, "Chair", desktop, 3.5)
	createSlot(spots, "Chair", CFrame.new(cx, FLOOR_TOP + REST_HEIGHTS.Chair, cz + 1.9))
end

-- Imprimante en libre-service avec un bac de sortie (3 piles de papiers).
local function createPrinterStation(parent, index, cx, cz)
	local model = newModel(parent, "PrinterStation" .. index)
	block(model, "Cabinet", Vector3.new(2.6, 2.4, 1.8), Vector3.new(cx, FLOOR_TOP + 1.2, cz), COLORS.Metal, "SmoothPlastic")
	local printer = block(model, "Printer", Vector3.new(2.2, 0.9, 1.6), Vector3.new(cx, FLOOR_TOP + 2.85, cz), COLORS.White, "SmoothPlastic")
	block(model, "ControlPanel", Vector3.new(0.6, 0.05, 0.4), Vector3.new(cx + 0.6, FLOOR_TOP + 3.325, cz + 0.4), COLORS.DarkMetal, "SmoothPlastic", { CanCollide = false })
	block(model, "SideTable", Vector3.new(1.8, 0.12, 1.8), Vector3.new(cx, FLOOR_TOP + DESK_HEIGHT - 0.06, cz + 2.2), COLORS.Wood, "Wood")
	block(model, "TableLeg", Vector3.new(0.3, DESK_HEIGHT - 0.12, 0.3), Vector3.new(cx, FLOOR_TOP + (DESK_HEIGHT - 0.12) / 2, cz + 2.2), COLORS.DarkMetal, "Metal")
	local spots = makeZone(model, "Paper", printer, 3)
	createTray(model, spots, Vector3.new(cx, FLOOR_TOP + DESK_HEIGHT, cz + 2.2))
end

-- Petits détails de décor.
local function createTrashBin(parent, x, z)
	local model = newModel(parent, "TrashBin")
	cylinder(model, "Bin", 1.4, 0.9, Vector3.new(x, FLOOR_TOP + 0.7, z), COLORS.DarkMetal, "Metal")
	cylinder(model, "Rim", 0.08, 0.95, Vector3.new(x, FLOOR_TOP + 1.42, z), COLORS.Metal, "Metal")
end

local function createFireExtinguisher(parent, position, facing)
	local model = newModel(parent, "FireExtinguisher")
	local base = CFrame.lookAt(position, position + facing)
	local body = newPart(model, "Body", Vector3.new(1.3, 0.5, 0.5), base * CFrame.new(0, 0, -0.3) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 30, 30), "SmoothPlastic", { CanCollide = false })
	body.Shape = Enum.PartType.Cylinder
	newSign(model, "Label", "FIRE EXTINGUISHER", Vector3.new(1.6, 0.4, 0.05), position + Vector3.new(0, 1.2, 0) + facing * 0.05, facing, Color3.fromRGB(190, 30, 30))
end

local function createCoatRack(parent, x, z)
	local model = newModel(parent, "CoatRack")
	block(model, "Pole", Vector3.new(0.2, 5.5, 0.2), Vector3.new(x, FLOOR_TOP + 2.75, z), COLORS.DarkWood, "Wood")
	block(model, "Foot", Vector3.new(1.4, 0.15, 1.4), Vector3.new(x, FLOOR_TOP + 0.075, z), COLORS.DarkWood, "Wood")
	block(model, "Coat", Vector3.new(0.9, 2.2, 0.5), Vector3.new(x + 0.4, FLOOR_TOP + 4, z), Color3.fromRGB(60, 64, 76), "Fabric", { CanCollide = false })
end

local function createReadingTable(parent, name, cx, cz)
	local model = newModel(parent, name)
	block(model, "TableTop", Vector3.new(8, 0.2, 3.5), Vector3.new(cx, FLOOR_TOP + DESK_HEIGHT - 0.1, cz), COLORS.Wood, "Wood")
	for _, sx in { -1, 1 } do
		block(model, "Leg", Vector3.new(0.3, DESK_HEIGHT - 0.2, 3), Vector3.new(cx + sx * 3.7, FLOOR_TOP + (DESK_HEIGHT - 0.2) / 2, cz), COLORS.DarkWood, "Wood")
	end
	createOfficeChair(model, Vector3.new(cx - 2.5, FLOOR_TOP, cz + 2.6), 0)
	createOfficeChair(model, Vector3.new(cx + 2.5, FLOOR_TOP, cz + 2.6), 0)
end

local function createMailCart(parent, cx, cz)
	local model = newModel(parent, "MailCart")
	block(model, "Basket", Vector3.new(3, 1.4, 1.8), Vector3.new(cx, FLOOR_TOP + 1.5, cz), Color3.fromRGB(70, 90, 130), "Fabric")
	block(model, "Frame", Vector3.new(3.2, 0.8, 2), Vector3.new(cx, FLOOR_TOP + 0.4, cz), COLORS.DarkMetal, "Metal")
	block(model, "Handle", Vector3.new(0.15, 1.2, 1.8), Vector3.new(cx - 1.7, FLOOR_TOP + 2.2, cz), COLORS.Metal, "Metal")
end

-- Ascenseur entre le rez-de-chaussée et l'étage (cabine ouverte vers +Z).
-- Le sol de la cabine est un "plateau" : on marche dessus pour changer d'étage.
local function createElevator(parent, cx, backZ, targetPosition, label, lockedRoom)
	local model = newModel(parent, "Elevator")
	local frontZ = backZ + 6.6
	local midZ = (backZ + frontZ) / 2
	for _, side in { -1, 1 } do
		block(model, "SideWall", Vector3.new(0.3, 9, 6.6), Vector3.new(cx + side * 3.35, FLOOR_TOP + 4.5, midZ), COLORS.Metal, "Metal")
		block(model, "FrontWall", Vector3.new(1.55, 9, 0.3), Vector3.new(cx + side * 2.725, FLOOR_TOP + 4.5, frontZ + 0.15), COLORS.Metal, "Metal")
	end
	block(model, "Lintel", Vector3.new(3.9, 2, 0.3), Vector3.new(cx, FLOOR_TOP + 8, frontZ + 0.15), COLORS.Metal, "Metal")
	block(model, "Roof", Vector3.new(7, 0.3, 6.9), Vector3.new(cx, FLOOR_TOP + 9.15, midZ + 0.15), COLORS.DarkMetal, "Metal")
	local pad = block(model, "LiftPad", Vector3.new(6.3, 0.1, 6.3), Vector3.new(cx, FLOOR_TOP + 0.05, midZ), Color3.fromRGB(150, 190, 220), "Neon", { Transparency = 0.4 })
	pad:SetAttribute("Target", targetPosition)
	if lockedRoom then
		pad:SetAttribute("RequiresRoom", lockedRoom)
	end
	CollectionService:AddTag(pad, "TidyLift")
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1
	light.Parent = pad
	newSign(model, "ElevatorSign", label, Vector3.new(6, 0.9, 0.1), Vector3.new(cx, FLOOR_TOP + 9.9, frontZ + 0.36), Vector3.new(0, 0, 1))
	addObstacle(cx - 4.5, cx + 4.5, frontZ, frontZ + 4.5)
	if lockedRoom then
		createLockedDoor(parent, {
			Room = lockedRoom,
			Center = Vector3.new(cx, FLOOR_TOP + 3.5, frontZ + 0.15),
			Size = Vector3.new(3.6, 7, 0.3),
			Facing = Vector3.new(0, 0, 1),
		})
	end
	return pad
end

-- Canapé avec 6 coussins (3 assise + 3 dossier). Le canapé regarde vers -Z avant rotation.
local function createSofa(parent, index, cx, cz, yaw)
	local model = newModel(parent, "Sofa" .. index)
	local base = CFrame.new(cx, FLOOR_TOP, cz) * CFrame.Angles(0, yaw, 0)
	local seat = newPart(model, "Base", Vector3.new(6, 1.1, 2.4), base * CFrame.new(0, 0.55, 0), COLORS.Sofa, "Fabric")
	newPart(model, "Back", Vector3.new(6, 1.9, 0.5), base * CFrame.new(0, 2.05, 0.95), COLORS.Sofa, "Fabric")
	for _, side in { -1, 1 } do
		newPart(model, "Arm", Vector3.new(0.5, 1.7, 2.4), base * CFrame.new(side * 3.25, 0.85, 0), COLORS.Sofa, "Fabric")
	end
	local spots = makeZone(model, "Cushion", seat, 3.5)
	for _, x in { -1.9, 0, 1.9 } do
		createSlot(spots, "Cushion", base * CFrame.new(x, 1.3, -0.25))
		createSlot(spots, "Cushion", base * CFrame.new(x, 2.1, 0.45) * CFrame.Angles(math.rad(90), 0, 0))
	end
end

local function createCoffeeTable(parent, cx, cz)
	local model = newModel(parent, "CoffeeTable")
	block(model, "Top", Vector3.new(4, 0.15, 2), Vector3.new(cx, FLOOR_TOP + 1.325, cz), COLORS.Wood, "Wood")
	for _, sx in { -1, 1 } do
		block(model, "Leg", Vector3.new(0.2, 1.25, 1.6), Vector3.new(cx + sx * 1.7, FLOOR_TOP + 0.625, cz), COLORS.DarkMetal, "Metal")
	end
	block(model, "Magazine", Vector3.new(0.9, 0.04, 1.2), Vector3.new(cx - 0.8, FLOOR_TOP + 1.42, cz), Color3.fromRGB(200, 70, 60), "SmoothPlastic", { CanCollide = false })
end

-- Chariot de recharge : 2 niveaux de 6 ordinateurs portables debout. Dos côté -Z.
local function createLaptopCart(parent, index, cx, cz)
	local model = newModel(parent, "LaptopCart" .. index)
	block(model, "BackPanel", Vector3.new(5, 3.5, 0.08), Vector3.new(cx, FLOOR_TOP + 0.3 + 1.75, cz - 0.86), COLORS.DarkMetal, "Metal")
	for _, side in { -1, 1 } do
		block(model, "SidePanel", Vector3.new(0.15, 3.5, 1.7), Vector3.new(cx + side * 2.425, FLOOR_TOP + 0.3 + 1.75, cz + 0.03), COLORS.DarkMetal, "Metal")
	end
	local levels = { 0.5, 2, 3.8 }
	local boards = {}
	for _, level in levels do
		table.insert(boards, block(model, "Shelf", Vector3.new(4.7, 0.15, 1.7), Vector3.new(cx, FLOOR_TOP + level - 0.075, cz + 0.03), COLORS.Metal, "Metal"))
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			cylinder(model, "Wheel", 0.25, 0.3, Vector3.new(cx + sx * 2.1, FLOOR_TOP + 0.15, cz + sz * 0.6), COLORS.Black, "SmoothPlastic")
		end
	end
	block(model, "PowerLight", Vector3.new(1.2, 0.08, 0.02), Vector3.new(cx, FLOOR_TOP + 3.6, cz + 0.89), Color3.fromRGB(80, 220, 120), "Neon", { CanCollide = false })
	local spots = makeZone(model, "Laptop", boards[3], 2)
	for level = 1, 2 do
		for i = 0, 5 do
			createSlot(spots, "Laptop", CFrame.new(cx - 2 + i * 0.8, FLOOR_TOP + levels[level] + 0.6, cz + 0.03) * CFrame.Angles(0, 0, math.rad(90)))
		end
	end
end

local function createServerRack(parent, cx, cz)
	local model = newModel(parent, "ServerRack")
	block(model, "Cabinet", Vector3.new(2, 7, 3), Vector3.new(cx, FLOOR_TOP + 3.5, cz), COLORS.Black, "Metal")
	for i = 0, 5 do
		local color = if i % 2 == 0 then Color3.fromRGB(80, 220, 120) else Color3.fromRGB(80, 160, 240)
		block(model, "Led", Vector3.new(1.4, 0.06, 0.02), Vector3.new(cx, FLOOR_TOP + 1.2 + i * 0.9, cz + 1.51), color, "Neon", { CanCollide = false })
	end
end

-- Grande table de réunion avec 14 places de chaises.
local function createConferenceTable(parent, index, cx, cz)
	local model = newModel(parent, "ConferenceTable" .. index)
	local top = block(model, "TableTop", Vector3.new(16, 0.2, 5), Vector3.new(cx, FLOOR_TOP + 2.5, cz), COLORS.DarkWood, "Wood")
	for _, sx in { -1, 1 } do
		block(model, "Pedestal", Vector3.new(1.2, 2.4, 2.4), Vector3.new(cx + sx * 5, FLOOR_TOP + 1.2, cz), COLORS.DarkMetal, "Metal")
	end
	local spots = makeZone(model, "Chair", top, 4)
	for i = 0, 5 do
		local x = cx - 6.25 + i * 2.5
		for _, sz in { -1, 1 } do
			local position = Vector3.new(x, FLOOR_TOP + REST_HEIGHTS.Chair, cz + sz * 3.7)
			createSlot(spots, "Chair", CFrame.lookAt(position, Vector3.new(x, position.Y, cz)))
		end
	end
	for _, sx in { -1, 1 } do
		local position = Vector3.new(cx + sx * 9.7, FLOOR_TOP + REST_HEIGHTS.Chair, cz)
		createSlot(spots, "Chair", CFrame.lookAt(position, Vector3.new(cx, position.Y, cz)))
	end
end

-- Buffet bas contre un mur, avec 2 bacs à documents.
local function createCredenza(parent, index, cx, cz)
	local model = newModel(parent, "Credenza" .. index)
	local body = block(model, "Body", Vector3.new(1.8, 2.5, 6), Vector3.new(cx, FLOOR_TOP + 1.25, cz), COLORS.Wood, "Wood")
	local spots = makeZone(model, "Paper", body, 3)
	createTray(model, spots, Vector3.new(cx, FLOOR_TOP + 2.5, cz - 1.5))
	createTray(model, spots, Vector3.new(cx, FLOOR_TOP + 2.5, cz + 1.5))
end

-- Poste de travail partagé : bureau avec bac à documents, et une place de chaise.
local function createHotDesk(parent, index, cx, cz)
	local model = newModel(parent, "HotDesk" .. index)
	local top = FLOOR_TOP + DESK_HEIGHT
	local desktop = block(model, "Desktop", Vector3.new(4, 0.15, 1.8), Vector3.new(cx, top - 0.075, cz), COLORS.White, "SmoothPlastic")
	for _, side in { -1, 1 } do
		block(model, "Side", Vector3.new(0.15, DESK_HEIGHT - 0.15, 1.6), Vector3.new(cx + side * 1.9, FLOOR_TOP + (DESK_HEIGHT - 0.15) / 2, cz), COLORS.Metal, "SmoothPlastic")
	end
	block(model, "MonitorStand", Vector3.new(0.4, 0.5, 0.3), Vector3.new(cx - 0.6, top + 0.25, cz - 0.5), COLORS.Black, "SmoothPlastic")
	block(model, "Monitor", Vector3.new(1.8, 1.1, 0.1), Vector3.new(cx - 0.6, top + 1.05, cz - 0.5), COLORS.Black, "SmoothPlastic")
	block(model, "Keyboard", Vector3.new(1.4, 0.06, 0.45), Vector3.new(cx - 0.6, top + 0.03, cz + 0.3), COLORS.Black, "SmoothPlastic")
	local paperSpots = makeZone(model, "Paper", desktop, 3.5)
	createTray(model, paperSpots, Vector3.new(cx + 1.2, top, cz))
	local chairZone = newModel(model, "DeskChair")
	local mat = block(chairZone, "ChairMat", Vector3.new(2.6, 0.05, 2.6), Vector3.new(cx, FLOOR_TOP + 0.025, cz + 2), Color3.fromRGB(150, 156, 164), "SmoothPlastic", { CanCollide = false })
	mat.CanCollide = true
	local chairSpots = makeZone(chairZone, "Chair", mat, 3.5)
	createSlot(chairSpots, "Chair", CFrame.new(cx, FLOOR_TOP + REST_HEIGHTS.Chair, cz + 2))
end

-- Tableau décoratif (toile de couleur dans un cadre).
local function createWallArt(parent, position, facing, size, color)
	local model = newModel(parent, "WallArt")
	newPart(model, "Frame", Vector3.new(size.X + 0.3, size.Y + 0.3, 0.1), CFrame.lookAt(position, position + facing), COLORS.DarkWood, "Wood", { CanCollide = false })
	newPart(model, "Canvas", Vector3.new(size.X, size.Y, 0.04), CFrame.lookAt(position + facing * 0.06, position + facing * 2), color, "SmoothPlastic", { CanCollide = false })
	newPart(model, "Stripe", Vector3.new(size.X, size.Y * 0.2, 0.02), CFrame.lookAt(position + facing * 0.09 + Vector3.new(0, -size.Y * 0.15, 0), position + facing * 2), COLORS.Trim, "SmoothPlastic", { CanCollide = false })
end

---------------------------------------------------------------------------
-- Aménagement de chaque pièce
---------------------------------------------------------------------------
local function furnishReception(parent)
	createReception(parent, 0, 34)
	createChairRug(parent, "WaitingArea", Vector2.new(19, 50), Vector2.new(16, 16), { 14, 18, 22 }, { 44, 46.5, 49, 51.5, 54, 56.5 }, -90, COLORS.Rug, 6)
	newSign(parent, "NowServingScreen", "NOW SERVING   A-047", Vector3.new(6, 2, 0.2), Vector3.new(29.65, FLOOR_TOP + 6.5, 50), Vector3.new(-1, 0, 0), COLORS.Black, Color3.fromRGB(255, 90, 70))
	newSign(parent, "WaitingSign", "WAITING AREA", Vector3.new(6, 0.9, 0.2), Vector3.new(29.65, FLOOR_TOP + 8.6, 50), Vector3.new(-1, 0, 0))
	createTicketMachine(parent, -8, 50)
	createWaterCooler(parent, -28.5, 52)
	newSign(parent, "ExitSign", "EXIT", Vector3.new(2.4, 0.8, 0.1), Vector3.new(0, FLOOR_TOP + 9.6, HALF_Z - 0.06), Vector3.new(0, 0, -1), Color3.fromRGB(30, 140, 70))

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

	poster(parent, "PLEASE TAKE\nA TICKET", Vector3.new(6, FLOOR_TOP + 7, 20.3), Vector3.new(0, 0, 1), COLORS.SignBlue)
	createElevator(parent, -3.5, 20.25, Vector3.new(-3.5, UPPER_TOP + 3, 30.5), "ELEVATOR  -  UPPER FLOOR", "UpperHall")
	createWallArt(parent, Vector3.new(-29.7, FLOOR_TOP + 6.5, 50), Vector3.new(1, 0, 0), Vector2.new(4, 3), Color3.fromRGB(70, 110, 150))
	createWallArt(parent, Vector3.new(20, FLOOR_TOP + 6.5, 59.9), Vector3.new(0, 0, -1), Vector2.new(5, 3), Color3.fromRGB(160, 120, 70))
	createClock(parent, Vector3.new(12, FLOOR_TOP + 8, HALF_Z - 0.1), Vector3.new(0, 0, -1))
	createFireExtinguisher(parent, Vector3.new(-29.7, FLOOR_TOP + 1.2, 30), Vector3.new(1, 0, 0))
	createTrashBin(parent, 8, 57)
	createTrashBin(parent, -26, 40)
	createCoatRack(parent, 5, 58.5)
	for _, p in { { -28, 58 }, { 27, 23 }, { -27, 23 } } do
		createPlant(parent, p[1], p[2])
	end
end

local function furnishOffices(parent)
	local index = 0
	for _, z in { -46, -30, -14 } do
		for _, x in { -66, -50, -34, -18 } do
			index += 1
			createAdvisorDesk(parent, index, x, z)
		end
	end
	createPlanter(parent, 1, -60, -58.9)
	createPlanter(parent, 2, -30, -58.9)
	poster(parent, "CV WORKSHOP\nTUESDAYS 2 PM", Vector3.new(-70, FLOOR_TOP + 7, -59.7), Vector3.new(0, 0, 1), COLORS.SignBlue)
	poster(parent, "INTERVIEWS BY\nAPPOINTMENT ONLY", Vector3.new(-24, FLOOR_TOP + 7, -59.7), Vector3.new(0, 0, 1), Color3.fromRGB(70, 74, 82))
	createClock(parent, Vector3.new(-56, FLOOR_TOP + 9.5, -59.65), Vector3.new(0, 0, 1))
	createWaterCooler(parent, -4, -55)
	createFireExtinguisher(parent, Vector3.new(-0.3, FLOOR_TOP + 1.2, -20), Vector3.new(-1, 0, 0))
	for _, p in { { -26, -38 }, { -58, -22 }, { -42, -6 } } do
		createTrashBin(parent, p[1], p[2])
	end
	for _, p in { { -77, -57 }, { -77, 17 }, { -3, 17 } } do
		createPlant(parent, p[1], p[2])
	end
end

local function furnishSelfService(parent)
	local index = 0
	for _, z in { 2, 11 } do
		for _, x in { 30, 38, 46, 54, 62, 70 } do
			index += 1
			createKiosk(parent, index, x, z)
		end
	end
	createPrinterStation(parent, 1, 77, -5)
	createPrinterStation(parent, 2, 77, 7)
	createPlanter(parent, 3, 42, 19.05)
	createPlanter(parent, 4, 58, 19.05)
	createBench(parent, 45, -8.6)
	createBench(parent, 10, -8.6)
	newSign(parent, "SelfServiceSign", "SELF-SERVICE AREA  -  JOB SEARCH COMPUTERS", Vector3.new(16, 1.2, 0.1), Vector3.new(50, FLOOR_TOP + 8.6, 19.7), Vector3.new(0, 0, -1))
	poster(parent, "CAREER TRAINING\nPROGRAMS", Vector3.new(HALF_X - 0.05, FLOOR_TOP + 7, 17), Vector3.new(-1, 0, 0), Color3.fromRGB(52, 80, 70))
	poster(parent, "LOCAL EMPLOYERS\nARE HIRING", Vector3.new(40, FLOOR_TOP + 7, -9.7), Vector3.new(0, 0, 1), COLORS.SignBlue)
	createTrashBin(parent, 22, 16)
	createPlant(parent, 3, -7)
end

local function furnishBreakRoom(parent)
	createCupboard(parent, 1, -72, 21)
	createCupboard(parent, 2, -62, 21)
	createCupboard(parent, 3, -55, 21)
	createCupboard(parent, 4, -34, 21)
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
	createTrashBin(parent, -76, 52)
	createPlant(parent, -33, 57)
end

local function furnishArchives(parent)
	local index = 0
	for _, cz in { -58.6, -44 } do
		for _, x in { 6, 14, 22, 30 } do
			index += 1
			createArchiveShelf(parent, index, x, cz)
		end
	end
	createFilingCabinet(parent, 34.9, -59.75)
	createFilingCabinet(parent, 36.9, -59.75)
	createReadingTable(parent, "ReadingTable", 25, -26)
	createPlant(parent, 3, -13)
	createTrashBin(parent, 46, -14)
end

local function furnishStorage(parent)
	local index = 0
	for _, cz in { -58.2, -47, -36 } do
		for _, x in { 56, 65, 74 } do
			index += 1
			createStorageShelf(parent, index, x, cz)
		end
	end
	createFireExtinguisher(parent, Vector3.new(50.3, FLOOR_TOP + 1.2, -20), Vector3.new(1, 0, 0))
end

local function furnishTraining(parent)
	createWhiteboard(parent, 55, 20)
	createTeacherDesk(parent, 55, 28)
	createChairRug(parent, "TrainingRows", Vector2.new(55, 45), Vector2.new(30, 16), { 45, 50, 55, 60, 65 }, { 39, 43, 47, 51 }, 0, COLORS.GreenRug, 6)
	createPlanter(parent, 5, 70, 59.3)
	poster(parent, "PREPARING FOR\nYOUR INTERVIEW", Vector3.new(40, FLOOR_TOP + 7, HALF_Z - 0.05), Vector3.new(0, 0, -1), COLORS.SignBlue)
	createClock(parent, Vector3.new(78, FLOOR_TOP + 8, HALF_Z - 0.1), Vector3.new(0, 0, -1))
	createPlant(parent, 33, 23)
	createTrashBin(parent, 77, 24)
end

local function furnishBooths(parent)
	local index = 0
	for _, x in { -73, -63, -53, -43, -33 } do
		index += 1
		createBooth(parent, index, x, -95.3, 1)
	end
	for _, x in { -73, -63, -33 } do
		index += 1
		createBooth(parent, index, x, -64.6, -1)
	end
	poster(parent, "INTERVIEW IN PROGRESS\nPLEASE KEEP QUIET", Vector3.new(-79.95, FLOOR_TOP + 7, -80), Vector3.new(1, 0, 0), Color3.fromRGB(70, 74, 82))
	createWaterCooler(parent, -22, -98)
	createPlant(parent, -77, -80)
	createTrashBin(parent, -24, -66)
end

local function furnishLibrary(parent)
	local cats = { "CV", "Interview", "Training", "Careers", "CV" }
	for i, x in { -14, -6, 2, 10, 18 } do
		createBookcase(parent, i, x, -99.1, cats[i])
	end
	local freeCats = { "Interview", "Training", "Careers" }
	for i, x in { -6, 2, 10 } do
		createBookcase(parent, 5 + i, x, -80, freeCats[i])
	end
	createReadingTable(parent, "ReadingTable1", 0, -70)
	createReadingTable(parent, "ReadingTable2", 16, -70)
	newSign(parent, "LibrarySign", "RESOURCE LIBRARY  -  QUIET PLEASE", Vector3.new(14, 1.2, 0.1), Vector3.new(5, FLOOR_TOP + 9.8, -60.3), Vector3.new(0, 0, -1))
	createPlant(parent, 27, -63)
	createPlant(parent, -17, -63)
end

local function furnishMailRoom(parent)
	local cats = { "Red", "Blue", "Green", "Yellow", "Red", "Blue" }
	for i, x in { 35, 43, 51, 59, 67, 75 } do
		createPigeonholes(parent, i, x, -99, cats[i])
	end
	createPigeonholes(parent, 7, 50, -80, "Green")
	createPigeonholes(parent, 8, 60, -80, "Yellow")
	local sortingTable = newModel(parent, "SortingTable")
	block(sortingTable, "TableTop", Vector3.new(6, 0.2, 3), Vector3.new(65, FLOOR_TOP + 3.2, -68), COLORS.Wood, "Wood")
	for _, sx in { -1, 1 } do
		block(sortingTable, "Leg", Vector3.new(0.3, 3.1, 2.6), Vector3.new(65 + sx * 2.7, FLOOR_TOP + 1.55, -68), COLORS.DarkMetal, "Metal")
	end
	createMailCart(parent, 40, -88)
	createMailCart(parent, 74, -86)
	poster(parent, "SORT EVERY PARCEL\nBY LABEL COLOR", Vector3.new(HALF_X - 0.05, FLOOR_TOP + 7, -64), Vector3.new(-1, 0, 0), COLORS.SignBlue)
	createClock(parent, Vector3.new(30.3, FLOOR_TOP + 8, -66), Vector3.new(1, 0, 0))
	createTrashBin(parent, 77, -63)
end

---------------------------------------------------------------------------
-- Étage (accessible par l'ascenseur) : 6 pièces au-dessus de la partie sud de l'agence
---------------------------------------------------------------------------
local function buildUpperFloor(parent)
	local slabY = FLOOR_TOP - 0.5
	local function floor(name, minX, maxX, minZ, maxZ, color, material, options)
		block(parent, name, Vector3.new(maxX - minX, 1, maxZ - minZ), Vector3.new((minX + maxX) / 2, slabY, (minZ + maxZ) / 2), color, material, options)
	end
	floor("UpperHallFloor", -20, 20, 20, 60, COLORS.Tiles, "CeramicTiles", { Reflectance = 0.05 })
	floor("LoungeFloor", -80, -20, 20, 60, COLORS.WarmCarpet, "Carpet")
	floor("ConferenceFloor", 20, 80, 20, 60, COLORS.Carpet, "Carpet")
	floor("WorkspaceFloor", -20, 20, -60, 20, COLORS.WoodFloor, "WoodPlanks")
	floor("ITRoomFloor", 20, 80, -60, 20, COLORS.Concrete, "SmoothPlastic")
	floor("DirectorFloor", -80, -20, -60, 20, COLORS.DarkWood, "WoodPlanks")

	-- Murs extérieurs de l'étage.
	local baseY = FLOOR_TOP - 1
	local height = CEILING_BOTTOM - baseY
	block(parent, "UpperNorthWall", Vector3.new(HALF_X * 2 + 2, height, 1), Vector3.new(0, baseY + height / 2, -60.5), COLORS.Wall, "Plaster")
	block(parent, "UpperSouthWall", Vector3.new(HALF_X * 2 + 2, height, 1), Vector3.new(0, baseY + height / 2, 60.5), COLORS.Wall, "Plaster")
	windowedSideWall(parent, "UpperWestWall", -HALF_X - 0.5, { { -50, -30 }, { -10, 10 }, { 30, 50 } }, 1, -60, 60, baseY)
	windowedSideWall(parent, "UpperEastWall", HALF_X + 0.5, { { -50, -30 }, { -10, 10 }, { 30, 50 } }, -1, -60, 60, baseY)

	-- Cloisons de l'étage (portes ouvertes : tout l'étage s'ouvre avec l'ascenseur).
	interiorWallAlongX(parent, 20, -80, 80, { { From = 8, To = 16 } })
	interiorWallAlongZ(parent, -20, -60, 60, { { From = -24, To = -16 }, { From = 36, To = 44 } })
	interiorWallAlongZ(parent, 20, -60, 60, { { From = -24, To = -16 }, { From = 36, To = 44 } })

	local signY = FLOOR_TOP + DOOR_HEIGHT + 1.5
	for _, sign in {
		{ "EMPLOYER LOUNGE", Vector3.new(-19.7, signY, 40), Vector3.new(1, 0, 0) },
		{ "CONFERENCE", Vector3.new(19.7, signY, 40), Vector3.new(-1, 0, 0) },
		{ "OPEN WORKSPACE", Vector3.new(12, signY, 20.3), Vector3.new(0, 0, 1) },
		{ "DIRECTOR", Vector3.new(-19.7, signY, -20), Vector3.new(1, 0, 0) },
		{ "IT ROOM", Vector3.new(19.7, signY, -20), Vector3.new(-1, 0, 0) },
	} do
		newSign(parent, "RoomSign", sign[1], Vector3.new(7, 1.2, 0.1), sign[2], sign[3])
	end

	-- Faux plafond et luminaires de l'étage.
	block(parent, "UpperCeiling", Vector3.new(HALF_X * 2 + 2, 1, 122), Vector3.new(0, CEILING_BOTTOM + 0.5, 0), COLORS.Ceiling, "SmoothPlastic")
	local gridX = -HALF_X + 4
	while gridX < HALF_X do
		block(parent, "CeilingGrid", Vector3.new(0.12, 0.06, 120), Vector3.new(gridX, CEILING_BOTTOM - 0.03, 0), COLORS.CeilingGrid, "Metal", { CanCollide = false, CastShadow = false })
		gridX += 4
	end
	local gridZ = -60 + 4
	while gridZ < 60 do
		block(parent, "CeilingGrid", Vector3.new(HALF_X * 2, 0.06, 0.12), Vector3.new(0, CEILING_BOTTOM - 0.03, gridZ), COLORS.CeilingGrid, "Metal", { CanCollide = false, CastShadow = false })
		gridZ += 4
	end
	for _, room in TidyConfig.Rooms do
		if (room.Floor or 1) == 2 then
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
	end
end

local function furnishUpperHall(parent)
	createElevator(parent, -3.5, 20.25, Vector3.new(-3.5, GROUND_TOP + 3, 30.5), "ELEVATOR  -  GROUND FLOOR", nil)
	createChairRug(parent, "HallSeating", Vector2.new(0, 46), Vector2.new(14, 8), { -4.5, -1.5, 1.5, 4.5 }, { 44, 48 }, 0, COLORS.Rug, 5)
	createPlanter(parent, 6, 12, 59.2)
	newSign(parent, "UpperHallSign", "UPPER FLOOR  -  EMPLOYER SERVICES", Vector3.new(14, 1.2, 0.1), Vector3.new(0, FLOOR_TOP + 9.4, 59.9), Vector3.new(0, 0, -1))
	createWallArt(parent, Vector3.new(-19.7, FLOOR_TOP + 6.5, 52), Vector3.new(1, 0, 0), Vector2.new(4, 3), Color3.fromRGB(90, 130, 110))
	createPlant(parent, -17, 57)
	createPlant(parent, 17, 24)
	createTrashBin(parent, -12, 58)
end

local function furnishLounge(parent)
	local index = 0
	for _, center in { { -65, 30 }, { -35, 30 }, { -65, 50 }, { -35, 50 } } do
		local gx, gz = center[1], center[2]
		index += 1
		createSofa(parent, index, gx, gz - 3.6, math.pi)
		index += 1
		createSofa(parent, index, gx, gz + 3.6, 0)
		createCoffeeTable(parent, gx, gz)
	end
	createPlanter(parent, 7, -50, 59.2)
	createWallArt(parent, Vector3.new(-50, FLOOR_TOP + 6.5, 20.3), Vector3.new(0, 0, 1), Vector2.new(6, 3.5), Color3.fromRGB(180, 140, 90))
	createWaterCooler(parent, -78.5, 40)
	createPlant(parent, -77, 23)
	createPlant(parent, -23, 57)
end

local function furnishConference(parent)
	createConferenceTable(parent, 1, 48, 30)
	createConferenceTable(parent, 2, 48, 50)
	createCredenza(parent, 1, 78.5, 30)
	createCredenza(parent, 2, 78.5, 50)
	for _, z in { 30, 50 } do
		newSign(parent, "MeetingScreen", "MEETING ROOM", Vector3.new(7, 3.5, 0.15), Vector3.new(48, FLOOR_TOP + 6, if z == 30 then 20.35 else 59.9), Vector3.new(0, 0, if z == 30 then 1 else -1), COLORS.Black, Color3.fromRGB(120, 170, 220))
	end
	createPlant(parent, 23, 57)
	createPlant(parent, 23, 23)
end

local function furnishWorkspace(parent)
	local index = 0
	for _, z in { -45, -30, -15, 0 } do
		for _, x in { -10, 8 } do
			index += 1
			createHotDesk(parent, index, x, z)
		end
	end
	createPlanter(parent, 8, 0, -59.2)
	createWallArt(parent, Vector3.new(-19.7, FLOOR_TOP + 6.5, -45), Vector3.new(1, 0, 0), Vector2.new(4, 3), Color3.fromRGB(150, 90, 80))
	createWallArt(parent, Vector3.new(19.7, FLOOR_TOP + 6.5, -45), Vector3.new(-1, 0, 0), Vector2.new(4, 3), Color3.fromRGB(70, 100, 140))
	createTrashBin(parent, 17, 10)
end

local function furnishITRoom(parent)
	local index = 0
	for _, z in { -5, -25 } do
		for _, x in { 32, 44, 56 } do
			index += 1
			createLaptopCart(parent, index, x, z)
		end
	end
	for i = 0, 5 do
		createServerRack(parent, 30 + i * 2.4, -48)
	end
	for i, x in { 56, 65, 74 } do
		createStorageShelf(parent, 20 + i, x, -58.2)
	end
	newSign(parent, "ITSign", "IT ROOM  -  RETURN LAPTOPS TO THE CHARGING CARTS", Vector3.new(16, 1.2, 0.1), Vector3.new(50, FLOOR_TOP + 9.4, 19.7), Vector3.new(0, 0, -1))
	createFireExtinguisher(parent, Vector3.new(20.3, FLOOR_TOP + 1.2, 5), Vector3.new(1, 0, 0))
end

local function furnishDirector(parent)
	for i, x in { -70, -62, -54, -46 } do
		createArchiveShelf(parent, 20 + i, x, -58.6)
	end
	createTeacherDesk(parent, -50, -20)
	createPlanter(parent, 9, -30, -59.2)
	block(parent, "DirectorRug", Vector3.new(14, 0.05, 10), Vector3.new(-50, FLOOR_TOP + 0.025, -16), Color3.fromRGB(120, 60, 50), "Fabric", { CanCollide = false })
	createWallArt(parent, Vector3.new(-50, FLOOR_TOP + 6.5, 19.7), Vector3.new(0, 0, -1), Vector2.new(6, 4), Color3.fromRGB(60, 80, 110))
	createCoatRack(parent, -24, 16)
	createPlant(parent, -77, 17)
	createPlant(parent, -23, -57)
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
local function buildItemParts(itemType, index, categoryId)
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
	elseif itemType == "Book" then
		local category = TidyConfig.GetCategory("Book", categoryId) or TidyConfig.Categories.Book[1]
		main = newPart(model, "Main", size, CFrame.new(), category.Color, "SmoothPlastic")
		local band = newPart(model, "Band", Vector3.new(size.X + 0.02, 0.14, size.Z + 0.02), CFrame.new(0, 0.3, 0), Color3.fromRGB(236, 230, 210), "SmoothPlastic")
		band.CanCollide = false
		weldToMain(main, band)
	elseif itemType == "Laptop" then
		main = newPart(model, "Main", size, CFrame.new(), COLORS.Laptop, "SmoothPlastic")
		local logo = newPart(model, "Logo", Vector3.new(0.22, 0.02, 0.22), CFrame.new(0, size.Y / 2 + 0.01, 0), Color3.fromRGB(200, 204, 210), "SmoothPlastic")
		logo.CanCollide = false
		weldToMain(main, logo)
	elseif itemType == "Cushion" then
		main = newPart(model, "Main", size, CFrame.new(), CUSHION_COLORS[(index - 1) % #CUSHION_COLORS + 1], "Fabric")
		local seam = newPart(model, "Seam", Vector3.new(size.X + 0.02, 0.06, size.Z + 0.02), CFrame.new(), Color3.fromRGB(240, 236, 226), "Fabric")
		seam.CanCollide = false
		weldToMain(main, seam)
	elseif itemType == "Parcel" then
		local category = TidyConfig.GetCategory("Parcel", categoryId) or TidyConfig.Categories.Parcel[1]
		main = newPart(model, "Main", size, CFrame.new(), COLORS.Cardboard, "Cardboard")
		local label = newPart(model, "Label", Vector3.new(0.5, 0.3, 0.02), CFrame.new(0, 0, size.Z / 2 + 0.01), category.Color, "SmoothPlastic")
		label.CanCollide = false
		weldToMain(main, label)
		local topLabel = newPart(model, "TopLabel", Vector3.new(0.5, 0.02, 0.35), CFrame.new(0, size.Y / 2 + 0.01, 0), category.Color, "SmoothPlastic")
		topLabel.CanCollide = false
		weldToMain(main, topLabel)
	else
		error("Unknown item type: " .. tostring(itemType))
	end

	model.PrimaryPart = main
	return model, main
end

local function createItem(parent, itemType, index, homeCFrame, roomId, categoryId)
	local model = buildItemParts(itemType, index, categoryId)
	model:PivotTo(homeCFrame)
	model:SetAttribute("ItemType", itemType)
	model:SetAttribute("State", "Loose")
	model:SetAttribute("HomeCFrame", homeCFrame)
	model:SetAttribute("RestHeight", REST_HEIGHTS[itemType])
	model:SetAttribute("Room", roomId)
	if categoryId then
		model:SetAttribute("Category", categoryId)
	end
	model.Parent = parent
	CollectionService:AddTag(model, TidyConfig.ItemTag)
	return model
end

local function overlapsObstacle(x, z, radius)
	for _, o in obstacles do
		if o[5] == FLOOR_TOP and x + radius > o[1] and x - radius < o[2] and z + radius > o[3] and z - radius < o[4] then
			return true
		end
	end
	return false
end

local function overlapsItems(placed, x, z, radius)
	for _, p in placed do
		local dx, dz = p[1] - x, p[2] - z
		if p[4] == FLOOR_TOP and dx * dx + dz * dz < (p[3] + radius) ^ 2 then
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

	local atmosphere = Lighting:FindFirstChild("AgencyAtmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "AgencyAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.25
	atmosphere.Haze = 1
	atmosphere.Color = Color3.fromRGB(200, 215, 230)

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
	furnishReception(newFolder(furniture, "Reception"))
	furnishOffices(newFolder(furniture, "Offices"))
	furnishSelfService(newFolder(furniture, "SelfService"))
	furnishBreakRoom(newFolder(furniture, "BreakRoom"))
	furnishArchives(newFolder(furniture, "Archives"))
	furnishStorage(newFolder(furniture, "Storage"))
	furnishTraining(newFolder(furniture, "Training"))
	furnishBooths(newFolder(furniture, "Booths"))
	furnishLibrary(newFolder(furniture, "Library"))
	furnishMailRoom(newFolder(furniture, "MailRoom"))

	-- Étage
	setFloor(UPPER_TOP)
	buildUpperFloor(newFolder(root, "UpperBuilding"))
	local upperFurniture = newFolder(root, "UpperFurniture")
	furnishUpperHall(newFolder(upperFurniture, "UpperHall"))
	furnishLounge(newFolder(upperFurniture, "Lounge"))
	furnishConference(newFolder(upperFurniture, "Conference"))
	furnishWorkspace(newFolder(upperFurniture, "Workspace"))
	furnishITRoom(newFolder(upperFurniture, "ITRoom"))
	furnishDirector(newFolder(upperFurniture, "Director"))
	setFloor(GROUND_TOP)
	collectObstacles = false

	-- Endroit laissé libre : arrivée du joueur.
	addObstacle(-5, 5, 48, HALF_Z)

	local spawn = createSpawn(root)
	root.Parent = Workspace

	return {
		Root = root,
		Zones = allZones,
		Slots = allSlots,
		Doors = allDoors,
		Spawn = spawn,
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
		setFloor(TidyConfig.FloorHeights[room.Floor or 1])
		for _, itemType in TidyConfig.TypeOrder do
			local count = room.Items[itemType] or 0
			for _ = 1, count do
				counters[itemType] = (counters[itemType] or 0) + 1
				local index = counters[itemType]
				local tippedInfo = TIPPED[itemType]
				local tipped = tippedInfo ~= nil and (tippedInfo.Always or rng:NextNumber() < 0.45)
				local categories = TidyConfig.Categories[itemType]
				local categoryId = categories and categories[(index - 1) % #categories + 1].Id or nil
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
					table.insert(placed, { x, z, radius, FLOOR_TOP })
					local base = CFrame.new(x, FLOOR_TOP, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					local home
					if tipped then
						home = base * CFrame.new(0, TIPPED[itemType].Height, 0) * CFrame.Angles(0, 0, math.rad(90))
					else
						home = base * CFrame.new(0, REST_HEIGHTS[itemType], 0)
					end
					table.insert(currentItems, createItem(itemsFolder, itemType, index, home, room.Id, categoryId))
				else
					warn("[AgencyBuilder] No free floor space for " .. itemType .. index .. " in " .. room.Id)
				end
			end
		end
	end

	setFloor(GROUND_TOP)
	return table.clone(currentItems)
end

-- Zone d'accueil (lobby) : une grande place en plein air devant une façade de l'agence,
-- avec fontaine, arbres, lampadaires, et 3 portails sur lesquels on marche :
-- PLAY (jouer ici), CREATE ROOM (salon privé), JOIN ROOM (rejoindre avec un code).
-- Renvoie le point d'apparition et la liste des panneaux à mettre à jour.
local function createTree(parent, x, z, scale)
	local model = newModel(parent, "Tree")
	block(model, "Trunk", Vector3.new(1.2, 8 * scale, 1.2) , Vector3.new(x, GROUND_TOP + 4 * scale, z), Color3.fromRGB(96, 70, 48), "Wood")
	for i, offset in { Vector3.new(0, 9, 0), Vector3.new(1.6, 7.6, 0.8), Vector3.new(-1.4, 7.8, -1) } do
		local size = (if i == 1 then 7 else 5) * scale
		local leaves = block(model, "Leaves", Vector3.new(size, size, size), Vector3.new(x, GROUND_TOP, z) + offset * scale, if i == 2 then Color3.fromRGB(80, 140, 70) else Color3.fromRGB(64, 120, 60), "Grass", { CanCollide = false })
		leaves.Shape = Enum.PartType.Ball
	end
end

local function createLampPost(parent, x, z)
	local model = newModel(parent, "LampPost")
	block(model, "Pole", Vector3.new(0.4, 9, 0.4), Vector3.new(x, GROUND_TOP + 4.5, z), COLORS.Black, "Metal")
	block(model, "Base", Vector3.new(1, 0.6, 1), Vector3.new(x, GROUND_TOP + 0.3, z), COLORS.Black, "Metal")
	local head = block(model, "Lamp", Vector3.new(1.3, 1, 1.3), Vector3.new(x, GROUND_TOP + 9.4, z), COLORS.Bulb, "Neon")
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 220, 170)
	light.Parent = head
end

local function createFlowerBed(parent, cx, cz, length)
	local model = newModel(parent, "FlowerBed")
	block(model, "Curb", Vector3.new(length, 0.8, 3), Vector3.new(cx, GROUND_TOP + 0.4, cz), Color3.fromRGB(170, 166, 158), "Concrete")
	block(model, "Soil", Vector3.new(length - 0.4, 0.1, 2.6), Vector3.new(cx, GROUND_TOP + 0.85, cz), Color3.fromRGB(90, 64, 44), "Ground")
	local flowerColors = { Color3.fromRGB(230, 90, 110), Color3.fromRGB(250, 210, 80), Color3.fromRGB(170, 110, 220), Color3.fromRGB(250, 250, 250) }
	local count = math.floor(length / 0.9)
	for i = 0, count - 1 do
		local x = cx - length / 2 + 0.6 + i * 0.9
		local flower = block(model, "Flower", Vector3.new(0.6, 0.6, 0.6), Vector3.new(x, GROUND_TOP + 1.2, cz + ((i % 2) - 0.5) * 1), flowerColors[i % #flowerColors + 1], "SmoothPlastic", { CanCollide = false })
		flower.Shape = Enum.PartType.Ball
	end
end

local function createFlag(parent, x, z, color)
	local model = newModel(parent, "Flag")
	block(model, "Pole", Vector3.new(0.3, 16, 0.3), Vector3.new(x, GROUND_TOP + 8, z), COLORS.White, "Metal")
	block(model, "Cloth", Vector3.new(4, 2.5, 0.1), Vector3.new(x + 2.15, GROUND_TOP + 14.5, z), color, "Fabric", { CanCollide = false })
end

-- Portail du lobby : plateforme lumineuse, arche et nom flottant. "action" = Play, Create ou Join.
local function createPortal(parent, cx, cz, action, title, subtitle, color)
	local model = newModel(parent, "Portal_" .. action)
	block(model, "Platform", Vector3.new(11, 0.6, 11), Vector3.new(cx, GROUND_TOP + 0.3, cz), Color3.fromRGB(60, 64, 72), "Slate")
	local pad = block(model, "Pad", Vector3.new(8, 0.1, 8), Vector3.new(cx, GROUND_TOP + 0.65, cz), color, "Neon", { Transparency = 0.25, CanCollide = false })
	pad:SetAttribute("Action", action)
	CollectionService:AddTag(pad, "LobbyPad")
	for _, side in { -1, 1 } do
		block(model, "Pillar", Vector3.new(1.2, 11, 1.2), Vector3.new(cx + side * 4.9, GROUND_TOP + 6.1, cz - 4.9), Color3.fromRGB(40, 44, 52), "Metal")
		block(model, "PillarGlow", Vector3.new(0.3, 10.6, 0.3), Vector3.new(cx + side * 4.9, GROUND_TOP + 6.1, cz - 4.2), color, "Neon", { CanCollide = false })
	end
	block(model, "Beam", Vector3.new(11, 1.2, 1.2), Vector3.new(cx, GROUND_TOP + 12.2, cz - 4.9), Color3.fromRGB(40, 44, 52), "Metal")
	block(model, "PortalGlass", Vector3.new(8.6, 10.4, 0.2), Vector3.new(cx, GROUND_TOP + 6.1, cz - 4.9), color, "Neon", { Transparency = 0.65, CanCollide = false })

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Rate = 12
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.SpreadAngle = Vector2.new(20, 20)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Color = ColorSequence.new(color)
	sparkles.Size = NumberSequence.new(0.35)
	sparkles.LightEmission = 0.8
	sparkles.Parent = pad
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 16
	glow.Brightness = 1.5
	glow.Parent = pad

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PortalLabel"
	billboard.Adornee = pad
	billboard.Size = UDim2.fromOffset(260, 90)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 15, 0)
	billboard.MaxDistance = 150
	billboard.LightInfluence = 0
	billboard.Parent = model
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, 0.62)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextStrokeColor3 = color
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextScaled = true
	titleLabel.Parent = billboard
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.fromScale(0, 0.62)
	subtitleLabel.Size = UDim2.fromScale(1, 0.38)
	subtitleLabel.Font = Enum.Font.GothamBold
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	subtitleLabel.TextStrokeTransparency = 0.4
	subtitleLabel.TextScaled = true
	subtitleLabel.Parent = billboard
	return pad
end

-- Grand panneau avec titre et lignes de texte (classement, rangs, règles).
local function createBoard(parent, name, position, facing, title, lineCount, color)
	local model = newModel(parent, name)
	local board = newPart(model, "Board", Vector3.new(14, 12, 0.6), CFrame.lookAt(position, position + facing), color, "SmoothPlastic")
	for _, side in { -1, 1 } do
		local post = position + board.CFrame.RightVector * side * 7.4
		block(model, "Post", Vector3.new(0.6, position.Y + 6 - GROUND_TOP, 0.6), Vector3.new(post.X, (position.Y + 6 + GROUND_TOP) / 2, post.Z), COLORS.DarkMetal, "Metal")
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromScale(0.04, 0.03)
	titleLabel.Size = UDim2.fromScale(0.92, 0.14)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	titleLabel.TextScaled = true
	titleLabel.Parent = gui
	for i = 1, lineCount do
		local line = Instance.new("TextLabel")
		line.Name = "Line" .. i
		line.BackgroundTransparency = 1
		line.Position = UDim2.fromScale(0.06, 0.18 + (i - 1) * (0.78 / lineCount))
		line.Size = UDim2.fromScale(0.88, 0.78 / lineCount * 0.9)
		line.Font = Enum.Font.GothamBold
		line.Text = ""
		line.TextColor3 = Color3.fromRGB(240, 240, 240)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextScaled = true
		line.Parent = gui
	end
	return gui
end

function AgencyBuilder.BuildHub()
	local old = Workspace:FindFirstChild("AgencyLobby")
	if old then
		old:Destroy()
	end
	setFloor(GROUND_TOP)
	local root = Instance.new("Model")
	root.Name = "AgencyLobby"
	local cz = 200
	local half = 60
	local minZ, maxZ = cz - half, cz + half

	-- Sol de la place, allée centrale, et limites invisibles.
	block(root, "Plaza", Vector3.new(half * 2, 1, half * 2), Vector3.new(0, GROUND_TOP / 2, cz), Color3.fromRGB(196, 190, 178), "Pavement")
	block(root, "Walkway", Vector3.new(12, 0.1, 80), Vector3.new(0, GROUND_TOP + 0.05, cz + 15), Color3.fromRGB(160, 120, 96), "Brick", { CanCollide = false })
	for _, wall in {
		{ Vector3.new(half * 2, 40, 1), Vector3.new(0, 20, minZ - 0.5) },
		{ Vector3.new(half * 2, 40, 1), Vector3.new(0, 20, maxZ + 0.5) },
		{ Vector3.new(1, 40, half * 2), Vector3.new(-half - 0.5, 20, cz) },
		{ Vector3.new(1, 40, half * 2), Vector3.new(half + 0.5, 20, cz) },
	} do
		block(root, "Boundary", wall[1], wall[2], COLORS.White, "SmoothPlastic", { Transparency = 1 })
	end
	-- Haies tout autour.
	for _, hedge in {
		{ Vector3.new(half * 2, 3, 2), Vector3.new(0, GROUND_TOP + 1.5, maxZ - 1) },
		{ Vector3.new(2, 3, half * 2 - 20), Vector3.new(-half + 1, GROUND_TOP + 1.5, cz + 10) },
		{ Vector3.new(2, 3, half * 2 - 20), Vector3.new(half - 1, GROUND_TOP + 1.5, cz + 10) },
	} do
		block(root, "Hedge", hedge[1], hedge[2], Color3.fromRGB(60, 110, 56), "Grass")
	end

	-- Façade de l'agence au nord de la place.
	local facadeZ = minZ + 1
	block(root, "Facade", Vector3.new(100, 30, 2), Vector3.new(0, 15, facadeZ), COLORS.Wall, "Plaster")
	for row = 0, 1 do
		for col = 0, 7 do
			local x = -42 + col * 12
			if math.abs(x) > 8 or row == 1 then
				block(root, "FacadeWindow", Vector3.new(8, 6, 0.3), Vector3.new(x, 8 + row * 10, facadeZ + 1.1), COLORS.Glass, "Glass", { Transparency = 0.3, CanCollide = false })
			end
		end
	end
	block(root, "EntranceGlass", Vector3.new(10, 8, 0.3), Vector3.new(0, GROUND_TOP + 4, facadeZ + 1.1), COLORS.Glass, "Glass", { Transparency = 0.4 })
	block(root, "Canopy", Vector3.new(16, 0.6, 6), Vector3.new(0, GROUND_TOP + 9.5, facadeZ + 3.5), COLORS.SignBlue, "Metal")
	newSign(root, "FacadeSign", string.upper(TidyConfig.AgencyName), Vector3.new(60, 5, 0.3), Vector3.new(0, 25.5, facadeZ + 1.2), Vector3.new(0, 0, 1), COLORS.SignBlue)
	for i, color in { Color3.fromRGB(52, 92, 160), Color3.fromRGB(240, 240, 236), Color3.fromRGB(176, 58, 50) } do
		createFlag(root, -12 + (i - 1) * 12, facadeZ + 10, color)
	end

	-- Fontaine au centre.
	local fountain = newModel(root, "Fountain")
	cylinder(fountain, "Basin", 1.6, 18, Vector3.new(0, GROUND_TOP + 0.8, cz), Color3.fromRGB(176, 172, 164), "Concrete")
	local water = cylinder(fountain, "Water", 0.2, 16.4, Vector3.new(0, GROUND_TOP + 1.55, cz), Color3.fromRGB(80, 150, 200), "Glass")
	water.Transparency = 0.25
	cylinder(fountain, "Column", 4, 2, Vector3.new(0, GROUND_TOP + 3.6, cz), Color3.fromRGB(190, 186, 178), "Marble")
	local bowl = cylinder(fountain, "Bowl", 0.6, 6, Vector3.new(0, GROUND_TOP + 5.6, cz), Color3.fromRGB(190, 186, 178), "Marble")
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Rate = 40
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.Speed = NumberRange.new(6, 9)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -18, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
	spray.Transparency = NumberSequence.new(0.3)
	spray.Size = NumberSequence.new(0.3)
	spray.Parent = bowl

	-- Portails.
	local portalZ = cz + 32
	createPortal(root, -24, portalZ, "Create", "CREATE ROOM", "Private game with friends", Color3.fromRGB(70, 140, 230))
	createPortal(root, 0, portalZ, "Play", "PLAY", "Tidy up the agency", Color3.fromRGB(80, 200, 120))
	createPortal(root, 24, portalZ, "Join", "JOIN ROOM", "Enter a friend's code", Color3.fromRGB(160, 100, 220))

	-- Panneaux : classement, règles, rangs, bonus quotidien.
	local leaderboard = createBoard(root, "Leaderboard", Vector3.new(-50, GROUND_TOP + 7, cz - 8), Vector3.new(1, 0, 0), "TOP TIDIERS", 10, Color3.fromRGB(26, 34, 52))
	local howTo = createBoard(root, "HowToPlay", Vector3.new(-50, GROUND_TOP + 7, cz + 14), Vector3.new(1, 0, 0), "HOW TO PLAY", 6, Color3.fromRGB(30, 52, 60))
	local ranks = createBoard(root, "RankBoard", Vector3.new(50, GROUND_TOP + 7, cz - 8), Vector3.new(-1, 0, 0), "RANKS", #TidyConfig.Ranks, Color3.fromRGB(46, 36, 60))
	local howToLines = {
		"Aim at an item and click to pick it up.",
		"Aim at its place and click to put it away.",
		"Books and parcels go to the matching color.",
		"Spend points to open new rooms and upgrades.",
		"Take the elevator to the upper floor.",
		"Your progress is saved. Come back daily!",
	}
	for i, text in howToLines do
		howTo:FindFirstChild("Line" .. i).Text = text
	end
	for i, rank in TidyConfig.Ranks do
		ranks:FindFirstChild("Line" .. i).Text = rank.Name .. "  -  " .. rank.Items .. " items"
	end

	-- Stand du bonus quotidien : cadeau sur un socle.
	local gift = newModel(root, "DailyBonusStand")
	block(gift, "Pedestal", Vector3.new(5, 2, 5), Vector3.new(48, GROUND_TOP + 1, cz + 14), Color3.fromRGB(60, 64, 72), "Slate")
	local box = block(gift, "GiftBox", Vector3.new(3, 3, 3), Vector3.new(48, GROUND_TOP + 3.5, cz + 14), Color3.fromRGB(196, 60, 60), "SmoothPlastic")
	block(gift, "RibbonA", Vector3.new(3.1, 3.1, 0.5), Vector3.new(48, GROUND_TOP + 3.5, cz + 14), Color3.fromRGB(250, 210, 80), "SmoothPlastic", { CanCollide = false })
	block(gift, "RibbonB", Vector3.new(0.5, 3.1, 3.1), Vector3.new(48, GROUND_TOP + 3.5, cz + 14), Color3.fromRGB(250, 210, 80), "SmoothPlastic", { CanCollide = false })
	local giftGlow = Instance.new("PointLight")
	giftGlow.Color = Color3.fromRGB(255, 210, 120)
	giftGlow.Range = 12
	giftGlow.Parent = box
	local giftLabel = Instance.new("BillboardGui")
	giftLabel.Name = "GiftLabel"
	giftLabel.Adornee = box
	giftLabel.Size = UDim2.fromOffset(240, 70)
	giftLabel.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	giftLabel.MaxDistance = 80
	giftLabel.Parent = gift
	local giftText = Instance.new("TextLabel")
	giftText.BackgroundTransparency = 1
	giftText.Size = UDim2.fromScale(1, 1)
	giftText.Font = Enum.Font.GothamBlack
	giftText.Text = "DAILY BONUS\nCome back every day!"
	giftText.TextColor3 = Color3.fromRGB(255, 230, 140)
	giftText.TextStrokeTransparency = 0.2
	giftText.TextScaled = true
	giftText.Parent = giftLabel

	-- Arbres, lampadaires, bancs, parterres de fleurs.
	for _, z in { cz - 45, cz - 25, cz + 34, cz + 52 } do
		createTree(root, -54, z, 1)
		createTree(root, 54, z, 1)
	end
	for _, p in { { -30, cz - 30 }, { 30, cz - 30 }, { -34, cz + 50 }, { 34, cz + 50 } } do
		createTree(root, p[1], p[2], 0.8)
	end
	for _, z in { cz - 30, cz - 12, cz + 12, cz + 48 } do
		createLampPost(root, -9, z)
		createLampPost(root, 9, z)
	end
	for _, b in { { 0, cz - 13, 0 }, { 0, cz + 13, math.pi }, { -13, cz, math.pi / 2 }, { 13, cz, -math.pi / 2 } } do
		local bench = newModel(root, "Bench")
		local base = CFrame.new(b[1], GROUND_TOP, b[2]) * CFrame.Angles(0, b[3], 0)
		newPart(bench, "Seat", Vector3.new(6, 0.3, 1.4), base * CFrame.new(0, 1.4, 0), COLORS.Wood, "Wood")
		newPart(bench, "Back", Vector3.new(6, 1.4, 0.25), base * CFrame.new(0, 2.2, 0.6), COLORS.Wood, "Wood")
		for _, side in { -1, 1 } do
			newPart(bench, "Leg", Vector3.new(0.3, 1.25, 1.2), base * CFrame.new(side * 2.6, 0.625, 0), COLORS.DarkMetal, "Metal")
		end
	end
	for _, bed in { { -24, cz - 18 }, { 24, cz - 18 }, { -24, cz + 8 }, { 24, cz + 8 } } do
		createFlowerBed(root, bed[1], bed[2], 12)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = CFrame.new(0, GROUND_TOP + 0.1, maxZ - 8)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = false
	spawn.CastShadow = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = true
	spawn.Parent = root

	root.Parent = Workspace
	return spawn, leaderboard
end

-- Dossier où vivent les objets qui traînent.
function AgencyBuilder.GetItemsFolder()
	return itemsFolder
end

-- Dimensions utiles au gestionnaire (lâcher un objet).
AgencyBuilder.FloorTop = FLOOR_TOP
AgencyBuilder.HalfX = HALF_X
AgencyBuilder.MinZ = MIN_Z
AgencyBuilder.MaxZ = MAX_Z

return AgencyBuilder
