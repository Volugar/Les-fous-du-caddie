-- AgencyBuilder (ModuleScript)
-- Emplacement : ServerScriptService
-- Construit le monde au lancement du jeu : le hall d'accueil (files d'attente, boutique)
-- et le niveau choisi (agence pour l'emploi, entrepôt de distribution ou siège social) :
-- murs, portes verrouillées, mobilier, décor, lumières, zones de rangement et objets éparpillés.
-- Style lumineux et chaleureux, objets très détaillés.
-- Il est utilisé par le script TidyManager. Il ne fait rien tout seul.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TidyConfig = require(ReplicatedStorage:WaitForChild("TidyConfig"))

local AgencyBuilder = {}

-- Intensité des lampes (réglable avec TidyConfig.LightLevel).
local LIGHT_LEVEL = TidyConfig.LightLevel or 1
local function lampPower(brightness)
	return brightness * LIGHT_LEVEL
end

---------------------------------------------------------------------------
-- Dimensions (en studs). L'intérieur de l'agence va de
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

-- Style des cloisons (change selon le niveau : plâtre clair, boiseries sombres...).
local PARTITION_STYLE = { Color = Color3.fromRGB(240, 232, 214), Material = "Plaster", Base = Color3.fromRGB(86, 170, 180) }

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
	ShoeBox = Vector3.new(1.6, 0.8, 1),
	Toy = Vector3.new(1.2, 1.4, 1),
	Bottle = Vector3.new(0.8, 1.4, 0.5),
	Can = Vector3.new(0.5, 0.65, 0.5),
	Gadget = Vector3.new(1, 1.2, 0.4),
	Tape = Vector3.new(0.9, 0.4, 0.9),
	Trophy = Vector3.new(0.8, 1.4, 0.6),
	Frame = Vector3.new(1.2, 0.95, 0.15),
	Binder = Vector3.new(0.4, 1.3, 1),
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
	ShoeBox = 0.4,
	Toy = 0.7,
	Bottle = 0.7,
	Can = 0.325,
	Gadget = 0.6,
	Tape = 0.2,
	Trophy = 0.7,
	Frame = 0.475,
	Binder = 0.65,
}

-- Objets qui peuvent être renversés : hauteur et rayon une fois couchés.
-- Axis = "X" : couché sur le dos (cadres) ; sinon couché sur le côté.
local TIPPED = {
	Chair = { Height = 1, Radius = 2.4 },
	Mug = { Height = 0.25, Radius = 0.6 },
	Plant = { Height = 0.6, Radius = 1.2 },
	Book = { Height = 0.15, Radius = 0.7, Always = true }, -- un livre qui traîne est posé à plat
	Toy = { Height = 0.6, Radius = 1.1 },
	Bottle = { Height = 0.4, Radius = 1 },
	Can = { Height = 0.25, Radius = 0.5 },
	Trophy = { Height = 0.4, Radius = 1 },
	Binder = { Height = 0.2, Radius = 0.9, Always = true },
	Frame = { Height = 0.075, Radius = 0.9, Always = true, Axis = "X" },
	Gadget = { Height = 0.5, Radius = 0.9 },
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
	ShoeBox = 1,
	Toy = 0.9,
	Bottle = 0.6,
	Can = 0.4,
	Gadget = 0.7,
	Tape = 0.6,
	Trophy = 0.6,
	Frame = 0.8,
	Binder = 0.8,
}

-- Palette lumineuse et chaleureuse.
local COLORS = {
	Wall = Color3.fromRGB(246, 238, 222),
	WallBand = Color3.fromRGB(70, 168, 182),
	Trim = Color3.fromRGB(255, 252, 244),
	Partition = Color3.fromRGB(240, 232, 214),
	Ceiling = Color3.fromRGB(250, 244, 232),
	Slat = Color3.fromRGB(222, 156, 96),
	CeilingGrid = Color3.fromRGB(222, 214, 200),
	Light = Color3.fromRGB(246, 232, 206),
	Tiles = Color3.fromRGB(240, 228, 206),
	MintTiles = Color3.fromRGB(206, 236, 222),
	Carpet = Color3.fromRGB(78, 126, 186),
	WarmCarpet = Color3.fromRGB(196, 96, 74),
	GreenCarpet = Color3.fromRGB(96, 166, 112),
	WoodFloor = Color3.fromRGB(226, 186, 136),
	Concrete = Color3.fromRGB(204, 202, 196),
	Wood = Color3.fromRGB(218, 170, 112),
	DarkWood = Color3.fromRGB(134, 88, 54),
	Walnut = Color3.fromRGB(104, 66, 42),
	Metal = Color3.fromRGB(196, 202, 210),
	DarkMetal = Color3.fromRGB(70, 76, 88),
	Black = Color3.fromRGB(30, 30, 34),
	White = Color3.fromRGB(250, 250, 248),
	OfficeChair = Color3.fromRGB(46, 86, 150),
	Rug = Color3.fromRGB(62, 116, 196),
	GreenRug = Color3.fromRGB(88, 172, 120),
	Paper = Color3.fromRGB(252, 252, 246),
	Cardboard = Color3.fromRGB(206, 158, 100),
	Tape = Color3.fromRGB(226, 188, 130),
	Glass = Color3.fromRGB(196, 232, 250),
	DoorGlass = Color3.fromRGB(176, 214, 236),
	Plant = Color3.fromRGB(70, 160, 72),
	Pot = Color3.fromRGB(236, 236, 232),
	Cork = Color3.fromRGB(196, 146, 96),
	SignBlue = Color3.fromRGB(38, 138, 168),
	BoothFabric = Color3.fromRGB(104, 150, 196),
	BookcaseWood = Color3.fromRGB(150, 98, 60),
	Sofa = Color3.fromRGB(60, 112, 186),
	Laptop = Color3.fromRGB(60, 64, 72),
	Bulb = Color3.fromRGB(255, 226, 170),
	Gold = Color3.fromRGB(236, 186, 70),
	Marble = Color3.fromRGB(244, 240, 232),
	RackOrange = Color3.fromRGB(240, 120, 36),
	RackBlue = Color3.fromRGB(40, 96, 176),
	Hazard = Color3.fromRGB(250, 204, 40),
	Ghost = Color3.fromRGB(90, 220, 130),
}

-- Couleurs des objets (vives, comme dans un magasin).
local FOLDER_COLORS = {
	Color3.fromRGB(236, 196, 120),
	Color3.fromRGB(64, 120, 210),
	Color3.fromRGB(210, 60, 60),
	Color3.fromRGB(60, 160, 96),
	Color3.fromRGB(150, 90, 200),
}
local CHAIR_COLORS = {
	Color3.fromRGB(46, 86, 150),
	Color3.fromRGB(200, 70, 60),
	Color3.fromRGB(60, 150, 110),
	Color3.fromRGB(70, 70, 80),
}
local STICKER_COLORS = {
	Color3.fromRGB(250, 250, 246),
	Color3.fromRGB(250, 220, 110),
}
local SHEET_COLORS = {
	Color3.fromRGB(252, 250, 242),
	Color3.fromRGB(236, 244, 252),
	Color3.fromRGB(252, 246, 222),
	Color3.fromRGB(255, 236, 240),
}
local MUG_COLORS = {
	Color3.fromRGB(250, 250, 246),
	Color3.fromRGB(230, 80, 70),
	Color3.fromRGB(60, 120, 210),
	Color3.fromRGB(250, 196, 60),
	Color3.fromRGB(80, 170, 110),
}
local CUSHION_COLORS = {
	Color3.fromRGB(236, 190, 110),
	Color3.fromRGB(210, 80, 70),
	Color3.fromRGB(80, 170, 160),
	Color3.fromRGB(240, 232, 214),
	Color3.fromRGB(150, 100, 200),
}
local POT_COLORS = {
	Color3.fromRGB(236, 236, 232),
	Color3.fromRGB(204, 120, 80),
	Color3.fromRGB(70, 74, 84),
	Color3.fromRGB(240, 196, 80),
}
local BRIGHT_COLORS = {
	Color3.fromRGB(232, 70, 60),
	Color3.fromRGB(46, 120, 226),
	Color3.fromRGB(250, 196, 40),
	Color3.fromRGB(60, 180, 96),
	Color3.fromRGB(240, 130, 40),
	Color3.fromRGB(160, 90, 210),
	Color3.fromRGB(40, 190, 200),
	Color3.fromRGB(240, 110, 170),
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
-- Un panneau flottant (style panneau de rayon) affiche le nom et le compteur.
local function makeZone(model, itemType, anchorPart, billboardHeight, categoryId)
	local room = TidyConfig.GetRoomAt(anchorPart.Position)
	local category = categoryId and TidyConfig.GetCategory(itemType, categoryId)
	local info = TidyConfig.ItemTypes[itemType]
	local zoneLabel = info.PlaceName
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

	-- Taille en studs : le panneau rapetisse avec la distance, comme un vrai panneau.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CategoryBillboard"
	billboard.Adornee = anchorPart
	billboard.Size = UDim2.fromScale(6, 1.7)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, billboardHeight, 0)
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.Parent = model

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = if category then category.Color else COLORS.SignBlue
	panel.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.Parent = panel

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.05, 0.06)
	label.Size = UDim2.fromScale(0.9, 0.88)
	label.Font = Enum.Font.FredokaOne
	label.Text = info.Icon .. " " .. zoneLabel
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Parent = panel

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

-- Plinthes (bas des murs) des deux côtés d'un segment de cloison, sans collision.
local function addBaseboards(parent, alongX, center, length)
	for _, side in { -1, 1 } do
		if alongX then
			block(parent, "Baseboard", Vector3.new(length, 0.5, 0.12), Vector3.new(center.X, FLOOR_TOP + 0.25, center.Z + side * 0.31), PARTITION_STYLE.Base, "SmoothPlastic", { CanCollide = false, CastShadow = false })
		else
			block(parent, "Baseboard", Vector3.new(0.12, 0.5, length), Vector3.new(center.X + side * 0.31, FLOOR_TOP + 0.25, center.Z), PARTITION_STYLE.Base, "SmoothPlastic", { CanCollide = false, CastShadow = false })
		end
	end
end

-- Encadrement blanc autour d'une ouverture de porte.
local function addDoorCasing(parent, alongX, center, length)
	local casingColor = COLORS.Trim
	local postHeight = DOOR_HEIGHT
	for _, side in { -1, 1 } do
		if alongX then
			block(parent, "DoorCasing", Vector3.new(0.3, postHeight, 0.7), Vector3.new(center.X + side * (length / 2 + 0.15), FLOOR_TOP + postHeight / 2, center.Z), casingColor, "SmoothPlastic", { CanCollide = false })
		else
			block(parent, "DoorCasing", Vector3.new(0.7, postHeight, 0.3), Vector3.new(center.X, FLOOR_TOP + postHeight / 2, center.Z + side * (length / 2 + 0.15)), casingColor, "SmoothPlastic", { CanCollide = false })
		end
	end
	if alongX then
		block(parent, "DoorCasingTop", Vector3.new(length + 0.6, 0.3, 0.7), Vector3.new(center.X, FLOOR_TOP + DOOR_HEIGHT + 0.15, center.Z), casingColor, "SmoothPlastic", { CanCollide = false })
	else
		block(parent, "DoorCasingTop", Vector3.new(0.7, 0.3, length + 0.6), Vector3.new(center.X, FLOOR_TOP + DOOR_HEIGHT + 0.15, center.Z), casingColor, "SmoothPlastic", { CanCollide = false })
	end
end

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
			local center = Vector3.new(segment[1] + length / 2, FLOOR_TOP + WALL_HEIGHT / 2, z)
			block(parent, "Partition", Vector3.new(length, WALL_HEIGHT, 0.5), center, PARTITION_STYLE.Color, PARTITION_STYLE.Material)
			addBaseboards(parent, true, center, length)
		end
	end
	for _, door in doors do
		local length = door.To - door.From
		local centerX = door.From + length / 2
		block(parent, "DoorLintel", Vector3.new(length, WALL_HEIGHT - DOOR_HEIGHT, 0.5), Vector3.new(centerX, FLOOR_TOP + DOOR_HEIGHT + (WALL_HEIGHT - DOOR_HEIGHT) / 2, z), PARTITION_STYLE.Color, PARTITION_STYLE.Material)
		addDoorCasing(parent, true, Vector3.new(centerX, 0, z), length)
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
			local center = Vector3.new(x, FLOOR_TOP + WALL_HEIGHT / 2, segment[1] + length / 2)
			block(parent, "Partition", Vector3.new(0.5, WALL_HEIGHT, length), center, PARTITION_STYLE.Color, PARTITION_STYLE.Material)
			addBaseboards(parent, false, center, length)
		end
	end
	for _, door in doors do
		local length = door.To - door.From
		local centerZ = door.From + length / 2
		block(parent, "DoorLintel", Vector3.new(0.5, WALL_HEIGHT - DOOR_HEIGHT, length), Vector3.new(x, FLOOR_TOP + DOOR_HEIGHT + (WALL_HEIGHT - DOOR_HEIGHT) / 2, centerZ), PARTITION_STYLE.Color, PARTITION_STYLE.Material)
		addDoorCasing(parent, false, Vector3.new(x, 0, centerZ), length)
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
	local text = room.Name .. "\nLOCKED\nOpens at " .. TidyConfig.FormatNumber(room.Unlock) .. " points earned"
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
-- Plafonds : dalle avec ouvertures (puits de lumière), lattes de bois, bandeaux lumineux
---------------------------------------------------------------------------

-- Dalle horizontale avec des trous rectangulaires (holes = liste de {minX, maxX, minZ, maxZ}).
local function slabWithHoles(parent, name, minX, maxX, minZ, maxZ, bottomY, thickness, holes, color, material)
	local edges = { minZ, maxZ }
	for _, hole in holes do
		table.insert(edges, hole[3])
		table.insert(edges, hole[4])
	end
	table.sort(edges)
	for i = 1, #edges - 1 do
		local z1, z2 = edges[i], edges[i + 1]
		if z2 - z1 > 0.01 then
			local cuts = {}
			for _, hole in holes do
				if hole[3] <= z1 + 0.001 and hole[4] >= z2 - 0.001 then
					table.insert(cuts, hole)
				end
			end
			table.sort(cuts, function(a, b)
				return a[1] < b[1]
			end)
			local cursor = minX
			local pieces = {}
			for _, cut in cuts do
				table.insert(pieces, { cursor, cut[1] })
				cursor = cut[2]
			end
			table.insert(pieces, { cursor, maxX })
			for _, piece in pieces do
				local length = piece[2] - piece[1]
				if length > 0.01 then
					block(parent, name, Vector3.new(length, thickness, z2 - z1), Vector3.new(piece[1] + length / 2, bottomY + thickness / 2, (z1 + z2) / 2), color, material)
				end
			end
		end
	end
end

-- Puits de lumière : verre en haut, cadre blanc et lumière douce vers le bas.
local function skylight(parent, hole, glassY)
	local cx, cz = (hole[1] + hole[2]) / 2, (hole[3] + hole[4]) / 2
	local sx, sz = hole[2] - hole[1], hole[4] - hole[3]
	block(parent, "SkylightGlass", Vector3.new(sx, 0.2, sz), Vector3.new(cx, glassY + 0.1, cz), COLORS.Glass, "Glass", { Transparency = 0.55, CastShadow = false })
	for _, offset in { -sx / 4, 0, sx / 4 } do
		block(parent, "SkylightMullion", Vector3.new(0.3, 0.4, sz), Vector3.new(cx + offset, glassY, cz), COLORS.Trim, "SmoothPlastic", { CanCollide = false, CastShadow = false })
	end
end

-- Plafond chaleureux : lattes de bois parallèles à X et bandeaux lumineux dans chaque pièce.
local function slatCeiling(parent, minX, maxX, minZ, maxZ, holes, rooms)
	local y = CEILING_BOTTOM - 0.15
	local z = minZ + 1.5
	while z < maxZ - 0.5 do
		local inHole = false
		for _, hole in holes do
			if z > hole[3] - 0.5 and z < hole[4] + 0.5 then
				inHole = true
			end
		end
		if not inHole then
			block(parent, "CeilingSlat", Vector3.new(maxX - minX, 0.3, 0.9), Vector3.new((minX + maxX) / 2, y, z), COLORS.Slat, "WoodPlanks", { CanCollide = false, CastShadow = false })
		else
			-- Les lattes passent quand même de chaque côté du puits de lumière.
			for _, hole in holes do
				if z > hole[3] - 0.5 and z < hole[4] + 0.5 then
					local left = hole[1] - minX
					local right = maxX - hole[2]
					if left > 0.5 then
						block(parent, "CeilingSlat", Vector3.new(left, 0.3, 0.9), Vector3.new(minX + left / 2, y, z), COLORS.Slat, "WoodPlanks", { CanCollide = false, CastShadow = false })
					end
					if right > 0.5 then
						block(parent, "CeilingSlat", Vector3.new(right, 0.3, 0.9), Vector3.new(hole[2] + right / 2, y, z), COLORS.Slat, "WoodPlanks", { CanCollide = false, CastShadow = false })
					end
					break
				end
			end
		end
		z += 2.5
	end
	-- Bandeaux lumineux (néon chaud), avec une lumière douce tous les 16 studs.
	for _, room in rooms do
		local stripZ = room.MinZ + 7.75
		while stripZ <= room.MaxZ - 5 do
			local blocked = false
			for _, hole in holes do
				if stripZ > hole[3] - 1 and stripZ < hole[4] + 1 and hole[2] > room.MinX and hole[1] < room.MaxX then
					blocked = true
				end
			end
			if blocked then
				stripZ += 12.5
				continue
			end
			local length = room.MaxX - room.MinX - 8
			local strip = block(parent, "LightStrip", Vector3.new(length, 0.15, 0.6), Vector3.new((room.MinX + room.MaxX) / 2, y - 0.25, stripZ), COLORS.Light, "Neon", { CanCollide = false, CastShadow = false, Transparency = 0.45 })
			local lightX = room.MinX + 10
			while lightX <= room.MaxX - 6 do
				local holder = block(parent, "LightPoint", Vector3.new(0.2, 0.1, 0.2), Vector3.new(lightX, y - 0.4, stripZ), COLORS.Light, "SmoothPlastic", { CanCollide = false, CastShadow = false, Transparency = 1 })
				local light = Instance.new("PointLight")
				light.Range = 14
				light.Brightness = lampPower(0.5)
				light.Color = Color3.fromRGB(255, 236, 206)
				light.Shadows = false
				light.Parent = holder
				lightX += 16
			end
			strip.Name = "LightStrip"
			stripZ += 12.5
		end
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

	-- Plafond : dalle claire, lattes de bois chaleureuses et bandeaux lumineux.
	block(parent, "Ceiling", Vector3.new(fullLengthX, 1, fullLengthZ), Vector3.new(0, CEILING_BOTTOM + 0.5, MID_Z), COLORS.Ceiling, "SmoothPlastic")
	local groundRooms = {}
	for _, room in TidyConfig.GetMapRooms("Agency") do
		if (room.Floor or 1) == 1 then
			table.insert(groundRooms, room)
		end
	end
	slatCeiling(parent, -HALF_X, HALF_X, MIN_Z, MAX_Z, {}, groundRooms)

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
	light.Brightness = lampPower(0.6)
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

	-- Plafond de l'étage avec de grands puits de lumière (le soleil entre dans les pièces).
	local holes = {
		{ -8, 8, 32, 48 },
		{ -60, -40, 32, 48 },
		{ 40, 56, 30, 38 },
		{ -8, 8, -40, -24 },
		{ 40, 60, -40, -32 },
		{ -60, -40, -40, -24 },
	}
	slabWithHoles(parent, "UpperCeiling", -HALF_X - 1, HALF_X + 1, -61, 61, CEILING_BOTTOM, 1, holes, COLORS.Ceiling, "SmoothPlastic")
	for _, hole in holes do
		skylight(parent, hole, CEILING_BOTTOM + 1)
		-- Cadre du puits de lumière.
		local cx, cz = (hole[1] + hole[2]) / 2, (hole[3] + hole[4]) / 2
		local sx, sz = hole[2] - hole[1], hole[4] - hole[3]
		for _, side in { -1, 1 } do
			block(parent, "SkylightFrame", Vector3.new(sx + 0.6, 0.4, 0.3), Vector3.new(cx, CEILING_BOTTOM - 0.2, cz + side * (sz / 2 + 0.15)), COLORS.Trim, "SmoothPlastic", { CanCollide = false })
			block(parent, "SkylightFrame", Vector3.new(0.3, 0.4, sz), Vector3.new(cx + side * (sx / 2 + 0.15), CEILING_BOTTOM - 0.2, cz), COLORS.Trim, "SmoothPlastic", { CanCollide = false })
		end
	end
	local upperRooms = {}
	for _, room in TidyConfig.GetMapRooms("Agency") do
		if (room.Floor or 1) == 2 then
			table.insert(upperRooms, room)
		end
	end
	slatCeiling(parent, -HALF_X, HALF_X, -60, 60, holes, upperRooms)
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
-- Chaque objet est fait de plusieurs pièces soudées pour être le plus détaillé possible.
local function buildItemParts(itemType, index, categoryId)
	local model = Instance.new("Model")
	model.Name = itemType .. index
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local size = ITEM_SIZES[itemType]
	local main = nil

	local function pick(list, offset)
		return list[(index - 1 + (offset or 0)) % #list + 1]
	end
	local function solidMain(color, material)
		main = newPart(model, "Main", size, CFrame.new(), color, material or "SmoothPlastic")
		return main
	end
	local function hiddenMain()
		main = newPart(model, "Main", size, CFrame.new(), COLORS.White, "SmoothPlastic", { Transparency = 1 })
		return main
	end
	-- Détail soudé à la pièce principale, sans collision.
	local function d(name, partSize, cframe, color, material, shape, options)
		local part = newPart(model, name, partSize, cframe, color, material or "SmoothPlastic", options)
		if shape then
			part.Shape = shape
		end
		part.CanCollide = false
		part.CastShadow = false
		weldToMain(main, part)
		return part
	end
	-- Cylindre vertical (axe Y).
	local function vcyl(name, height, diameter, center, color, material)
		return d(name, Vector3.new(height, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
	end
	-- Cylindre couché le long de X.
	local function xcyl(name, length, diameter, center, color, material)
		return d(name, Vector3.new(length, diameter, diameter), CFrame.new(center), color, material, Enum.PartType.Cylinder)
	end
	local function ball(name, diameter, center, color, material)
		return d(name, Vector3.new(diameter, diameter, diameter), CFrame.new(center), color, material, Enum.PartType.Ball)
	end
	local function barcode(origin, faceNormal)
		-- 4 traits noirs sur une étiquette (origin = centre de l'étiquette).
		for i = 0, 3 do
			local offset = (i - 1.5) * 0.06
			if faceNormal == "Z" then
				d("Barcode", Vector3.new(0.025 + (i % 2) * 0.02, 0.12, 0.01), CFrame.new(origin + Vector3.new(offset, -0.02, 0.006)), COLORS.Black)
			else
				d("Barcode", Vector3.new(0.025 + (i % 2) * 0.02, 0.01, 0.12), CFrame.new(origin + Vector3.new(offset, 0.006, 0.02)), COLORS.Black)
			end
		end
	end

	if itemType == "Folder" then
		hiddenMain()
		local color = pick(FOLDER_COLORS)
		d("BackCover", Vector3.new(1.3, 0.03, 1.6), CFrame.new(0, -0.06, 0), color)
		d("Papers", Vector3.new(1.22, 0.07, 1.5), CFrame.new(0.06, -0.01, 0.02), COLORS.Paper)
		d("PaperEdge", Vector3.new(1.18, 0.02, 1.46), CFrame.new(0.1, 0.025, -0.02) * CFrame.Angles(0, math.rad(3), 0), pick(SHEET_COLORS, 1))
		d("FrontCover", Vector3.new(1.3, 0.03, 1.6), CFrame.new(0, 0.055, 0), color)
		d("Tab", Vector3.new(0.45, 0.03, 0.16), CFrame.new(-0.3, 0.055, -0.87), color)
		d("Label", Vector3.new(0.7, 0.01, 0.4), CFrame.new(0, 0.075, 0.2), COLORS.Paper)
		d("LabelLine", Vector3.new(0.5, 0.012, 0.05), CFrame.new(0, 0.077, 0.2), COLORS.DarkMetal)
		d("Elastic", Vector3.new(1.33, 0.14, 0.06), CFrame.new(0, 0, 0.55), Color3.fromRGB(40, 40, 46), "Fabric")
	elseif itemType == "Paper" then
		hiddenMain()
		for layer = 0, 3 do
			local angle = ({ -4, 3, -2, 5 })[layer + 1]
			d("Sheets", Vector3.new(1.05, 0.055, 1.45), CFrame.new(((layer % 2) - 0.5) * 0.04, -0.095 + layer * 0.06, 0) * CFrame.Angles(0, math.rad(angle), 0), pick(SHEET_COLORS, layer))
		end
		d("TextLines", Vector3.new(0.7, 0.005, 0.6), CFrame.new(0, 0.11, 0.1) * CFrame.Angles(0, math.rad(5), 0), Color3.fromRGB(190, 196, 206))
		d("Clip", Vector3.new(0.3, 0.1, 0.12), CFrame.new(0, 0.1, -0.66), COLORS.Black, "Metal")
		d("ClipHandle", Vector3.new(0.04, 0.16, 0.22), CFrame.new(-0.08, 0.18, -0.72) * CFrame.Angles(math.rad(-30), 0, 0), COLORS.Metal, "Metal")
		d("ClipHandle", Vector3.new(0.04, 0.16, 0.22), CFrame.new(0.08, 0.18, -0.72) * CFrame.Angles(math.rad(-30), 0, 0), COLORS.Metal, "Metal")
	elseif itemType == "Chair" then
		-- La pièce principale est l'assise. La chaise regarde vers -Z.
		local chairColor = pick(CHAIR_COLORS)
		local cushion = chairColor:Lerp(Color3.new(1, 1, 1), 0.15)
		solidMain(COLORS.DarkMetal, "Metal")
		d("SeatCushion", Vector3.new(1.9, 0.2, 1.9), CFrame.new(0, 0.26, -0.02), cushion, "Fabric")
		d("BackFrame", Vector3.new(2, 2, 0.15), CFrame.new(0, 1.175, 0.92), COLORS.DarkMetal, "Metal")
		d("BackCushion", Vector3.new(1.8, 1.7, 0.2), CFrame.new(0, 1.2, 0.76), cushion, "Fabric")
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				d("Leg", Vector3.new(0.15, 1.625, 0.15), CFrame.new(0.85 * sx, -0.9875, 0.85 * sz), COLORS.Metal, "Metal")
				d("Foot", Vector3.new(0.2, 0.06, 0.2), CFrame.new(0.85 * sx, -1.77, 0.85 * sz), COLORS.Black)
			end
			d("Armrest", Vector3.new(0.15, 0.12, 1.4), CFrame.new(0.95 * sx, 0.75, 0.1), COLORS.Black)
			d("ArmPost", Vector3.new(0.12, 0.6, 0.12), CFrame.new(0.95 * sx, 0.45, 0.3), COLORS.Metal, "Metal")
		end
	elseif itemType == "Box" then
		solidMain(COLORS.Cardboard, "Cardboard")
		local half = size / 2
		d("TopTape", Vector3.new(size.X + 0.04, 0.02, 0.45), CFrame.new(0, half.Y + 0.005, 0), COLORS.Tape)
		d("FrontTape", Vector3.new(0.45, 0.45, 0.02), CFrame.new(0, half.Y - 0.22, -half.Z - 0.006), COLORS.Tape)
		d("BackTape", Vector3.new(0.45, 0.45, 0.02), CFrame.new(0, half.Y - 0.22, half.Z + 0.006), COLORS.Tape)
		d("FlapSeam", Vector3.new(0.02, 0.012, size.Z), CFrame.new(0, half.Y + 0.017, 0), Color3.fromRGB(150, 110, 70))
		d("Sticker", Vector3.new(0.9, 0.6, 0.02), CFrame.new(-0.4, -0.1, -half.Z - 0.01), pick(STICKER_COLORS))
		barcode(Vector3.new(-0.4, -0.2, -half.Z - 0.02), "Z")
		if index % 2 == 0 then
			d("Fragile", Vector3.new(0.02, 0.4, 0.9), CFrame.new(half.X + 0.01, 0.2, 0), Color3.fromRGB(220, 50, 46))
			d("FragileGlass", Vector3.new(0.025, 0.18, 0.12), CFrame.new(half.X + 0.012, 0.22, 0), COLORS.White)
		else
			d("ArrowUp", Vector3.new(0.02, 0.35, 0.08), CFrame.new(half.X + 0.01, 0.2, 0.2), COLORS.Black)
			d("ArrowUp", Vector3.new(0.02, 0.35, 0.08), CFrame.new(half.X + 0.01, 0.2, -0.2), COLORS.Black)
		end
	elseif itemType == "Mug" then
		hiddenMain()
		local mugColor = pick(MUG_COLORS)
		vcyl("Body", 0.55, 0.46, Vector3.new(0, 0, 0), mugColor, "SmoothPlastic")
		vcyl("Rim", 0.04, 0.47, Vector3.new(0, 0.26, 0), mugColor:Lerp(Color3.new(1, 1, 1), 0.3))
		if index % 2 == 0 then
			vcyl("Coffee", 0.02, 0.38, Vector3.new(0, 0.2, 0), Color3.fromRGB(90, 56, 34))
		end
		vcyl("Band", 0.1, 0.47, Vector3.new(0, -0.05, 0), pick(BRIGHT_COLORS, 2))
		d("HandleTop", Vector3.new(0.18, 0.06, 0.08), CFrame.new(0.3, 0.13, 0), mugColor)
		d("HandleSide", Vector3.new(0.06, 0.32, 0.08), CFrame.new(0.37, 0, 0), mugColor)
		d("HandleBottom", Vector3.new(0.18, 0.06, 0.08), CFrame.new(0.3, -0.13, 0), mugColor)
	elseif itemType == "Plant" then
		hiddenMain()
		local potColor = pick(POT_COLORS)
		vcyl("Pot", 0.8, 0.85, Vector3.new(0, -0.55, 0), potColor, "SmoothPlastic")
		vcyl("PotRim", 0.14, 0.95, Vector3.new(0, -0.1, 0), potColor:Lerp(Color3.new(0, 0, 0), 0.1))
		vcyl("Soil", 0.05, 0.8, Vector3.new(0, -0.06, 0), Color3.fromRGB(96, 66, 44), "Ground")
		local greens = { Color3.fromRGB(62, 150, 64), Color3.fromRGB(96, 186, 80), Color3.fromRGB(46, 120, 60) }
		local style = index % 3
		if style == 0 then
			-- Plante touffue.
			ball("Leaves", 1, Vector3.new(0, 0.35, 0), greens[1], "Grass")
			ball("Leaves", 0.6, Vector3.new(0.25, 0.7, 0.15), greens[2], "Grass")
			ball("Leaves", 0.55, Vector3.new(-0.25, 0.6, -0.2), greens[3], "Grass")
			ball("Leaves", 0.45, Vector3.new(0.05, 0.85, -0.15), greens[2], "Grass")
		elseif style == 1 then
			-- Fougère : feuilles allongées en étoile.
			vcyl("Stem", 0.5, 0.08, Vector3.new(0, 0.15, 0), Color3.fromRGB(80, 120, 60))
			for k = 0, 5 do
				local angle = math.rad(k * 60)
				d("Frond", Vector3.new(0.18, 0.06, 0.9), CFrame.new(0, 0.45, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.1, -0.35) * CFrame.Angles(math.rad(25), 0, 0), greens[(k % 3) + 1], "Grass")
			end
			ball("Heart", 0.35, Vector3.new(0, 0.55, 0), greens[2], "Grass")
		else
			-- Plante en fleurs.
			ball("Leaves", 0.8, Vector3.new(0, 0.3, 0), greens[1], "Grass")
			ball("Leaves", 0.5, Vector3.new(0, 0.65, 0), greens[3], "Grass")
			for k = 0, 3 do
				local angle = math.rad(k * 90 + 45)
				ball("Flower", 0.18, Vector3.new(math.cos(angle) * 0.3, 0.68, math.sin(angle) * 0.3), pick(BRIGHT_COLORS, k), "SmoothPlastic")
			end
		end
	elseif itemType == "Book" then
		hiddenMain()
		local category = TidyConfig.GetCategory("Book", categoryId) or TidyConfig.Categories.Book[1]
		local shade = 0.8 + (index % 3) * 0.1
		local color = Color3.new(math.min(1, category.Color.R * shade), math.min(1, category.Color.G * shade), math.min(1, category.Color.B * shade))
		d("CoverLeft", Vector3.new(0.04, 1.1, 0.8), CFrame.new(-0.13, 0, 0), color)
		d("CoverRight", Vector3.new(0.04, 1.1, 0.8), CFrame.new(0.13, 0, 0), color)
		d("Spine", Vector3.new(0.3, 1.1, 0.05), CFrame.new(0, 0, -0.375), color)
		d("Pages", Vector3.new(0.22, 1.04, 0.74), CFrame.new(0, 0, 0.02), Color3.fromRGB(250, 246, 232))
		d("SpineBand", Vector3.new(0.31, 0.05, 0.02), CFrame.new(0, 0.38, -0.405), COLORS.Gold, "Foil")
		d("SpineBand", Vector3.new(0.31, 0.05, 0.02), CFrame.new(0, -0.38, -0.405), COLORS.Gold, "Foil")
		d("SpineTitle", Vector3.new(0.18, 0.4, 0.02), CFrame.new(0, 0.05, -0.405), COLORS.White)
		d("CoverPicture", Vector3.new(0.02, 0.4, 0.45), CFrame.new(0.155, 0.15, 0.05), COLORS.White)
	elseif itemType == "Laptop" then
		hiddenMain()
		local shell = pick({ COLORS.Laptop, Color3.fromRGB(196, 200, 208), Color3.fromRGB(70, 90, 130) })
		d("Base", Vector3.new(1.2, 0.05, 0.9), CFrame.new(0, -0.025, 0), shell, "Metal")
		d("Lid", Vector3.new(1.18, 0.04, 0.88), CFrame.new(0, 0.02, 0.005), shell:Lerp(Color3.new(1, 1, 1), 0.12), "Metal")
		d("Logo", Vector3.new(0.18, 0.012, 0.18), CFrame.new(0, 0.045, 0), Color3.fromRGB(240, 244, 250), "Neon")
		xcyl("Hinge", 1, 0.07, Vector3.new(0, 0, 0.45), COLORS.Black)
		d("Notch", Vector3.new(0.25, 0.03, 0.02), CFrame.new(0, 0, -0.455), COLORS.Black)
		d("StatusLed", Vector3.new(0.04, 0.02, 0.02), CFrame.new(0.4, -0.02, -0.455), Color3.fromRGB(80, 230, 120), "Neon")
		d("Sticker", Vector3.new(0.2, 0.012, 0.14), CFrame.new(-0.35, 0.045, 0.25), pick(BRIGHT_COLORS))
	elseif itemType == "Cushion" then
		local color = pick(CUSHION_COLORS)
		solidMain(color, "Fabric")
		d("Piping", Vector3.new(1.25, 0.06, 1.25), CFrame.new(), color:Lerp(Color3.new(1, 1, 1), 0.35), "Fabric")
		d("TopPuff", Vector3.new(1.05, 0.08, 1.05), CFrame.new(0, 0.2, 0), color:Lerp(Color3.new(1, 1, 1), 0.08), "Fabric")
		ball("Button", 0.12, Vector3.new(0, 0.25, 0), color:Lerp(Color3.new(0, 0, 0), 0.25), "Fabric")
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				ball("Tassel", 0.14, Vector3.new(sx * 0.62, 0, sz * 0.62), COLORS.Gold, "Fabric")
			end
		end
	elseif itemType == "Parcel" then
		local category = TidyConfig.GetCategory("Parcel", categoryId) or TidyConfig.Categories.Parcel[1]
		solidMain(COLORS.Cardboard, "Cardboard")
		local half = size / 2
		d("TapeX", Vector3.new(size.X + 0.02, 0.015, 0.2), CFrame.new(0, half.Y + 0.004, 0), COLORS.Tape)
		d("TapeZ", Vector3.new(0.2, 0.016, size.Z + 0.02), CFrame.new(0, half.Y + 0.005, 0), COLORS.Tape)
		d("TopLabel", Vector3.new(0.42, 0.02, 0.3), CFrame.new(0.15, half.Y + 0.012, 0.2), category.Color)
		d("TopLabelWhite", Vector3.new(0.3, 0.022, 0.12), CFrame.new(0.15, half.Y + 0.014, 0.22), COLORS.White)
		d("FrontLabel", Vector3.new(0.5, 0.3, 0.02), CFrame.new(0, 0, half.Z + 0.01), category.Color)
		d("FrontLabelWhite", Vector3.new(0.36, 0.14, 0.022), CFrame.new(0, -0.03, half.Z + 0.012), COLORS.White)
		barcode(Vector3.new(0, -0.01, half.Z + 0.02), "Z")
	elseif itemType == "ShoeBox" then
		local bodyColor = pick({ Color3.fromRGB(240, 120, 40), Color3.fromRGB(40, 110, 220), Color3.fromRGB(34, 34, 38), Color3.fromRGB(220, 50, 50), Color3.fromRGB(250, 250, 246), Color3.fromRGB(60, 170, 100) })
		local lidColor = if bodyColor.R + bodyColor.G + bodyColor.B > 2.5 then Color3.fromRGB(230, 60, 60) else Color3.fromRGB(250, 250, 246)
		solidMain(bodyColor, "SmoothPlastic")
		d("Lid", Vector3.new(1.66, 0.24, 1.06), CFrame.new(0, 0.29, 0), lidColor)
		d("Swoosh", Vector3.new(0.7, 0.07, 0.02), CFrame.new(0.05, -0.1, 0.51) * CFrame.Angles(0, 0, math.rad(12)), lidColor)
		d("SwooshTail", Vector3.new(0.3, 0.06, 0.02), CFrame.new(-0.36, -0.15, 0.51) * CFrame.Angles(0, 0, math.rad(-25)), lidColor)
		d("SizeLabel", Vector3.new(0.02, 0.36, 0.6), CFrame.new(0.81, -0.08, 0), COLORS.White)
		d("SizeNumber", Vector3.new(0.025, 0.12, 0.2), CFrame.new(0.812, -0.02, -0.15), COLORS.Black)
		d("Barcode", Vector3.new(0.025, 0.12, 0.25), CFrame.new(0.812, -0.16, 0.12), COLORS.Black)
		d("LidBrand", Vector3.new(0.5, 0.02, 0.3), CFrame.new(0, 0.42, 0), bodyColor)
	elseif itemType == "Toy" then
		hiddenMain()
		local style = (index - 1) % 4
		if style == 0 then
			-- Ours en peluche.
			local fur = pick({ Color3.fromRGB(176, 120, 72), Color3.fromRGB(240, 170, 190), Color3.fromRGB(120, 170, 230), Color3.fromRGB(246, 240, 226) }, math.floor(index / 4))
			local light = fur:Lerp(Color3.new(1, 1, 1), 0.4)
			ball("Body", 0.9, Vector3.new(0, -0.2, 0), fur, "Fabric")
			ball("Belly", 0.55, Vector3.new(0, -0.22, 0.22), light, "Fabric")
			ball("Head", 0.75, Vector3.new(0, 0.38, 0), fur, "Fabric")
			for _, sx in { -1, 1 } do
				ball("Ear", 0.3, Vector3.new(sx * 0.3, 0.7, -0.02), fur, "Fabric")
				ball("InnerEar", 0.16, Vector3.new(sx * 0.3, 0.7, 0.08), light, "Fabric")
				ball("Eye", 0.1, Vector3.new(sx * 0.14, 0.47, 0.32), COLORS.Black)
				ball("Arm", 0.36, Vector3.new(sx * 0.48, -0.08, 0.1), fur, "Fabric")
				ball("Leg", 0.42, Vector3.new(sx * 0.27, -0.5, 0.22), fur, "Fabric")
				ball("Paw", 0.22, Vector3.new(sx * 0.27, -0.52, 0.42), light, "Fabric")
			end
			ball("Snout", 0.3, Vector3.new(0, 0.32, 0.32), light, "Fabric")
			ball("Nose", 0.12, Vector3.new(0, 0.37, 0.46), COLORS.Black)
			d("Bow", Vector3.new(0.4, 0.14, 0.1), CFrame.new(0, 0.06, 0.34), Color3.fromRGB(220, 40, 50), "Fabric")
		elseif style == 1 then
			-- Petite voiture.
			local paint = pick(BRIGHT_COLORS, math.floor(index / 4))
			d("Body", Vector3.new(1.1, 0.35, 0.6), CFrame.new(0, -0.43, 0), paint, "SmoothPlastic", nil, { Reflectance = 0.15 })
			d("Cabin", Vector3.new(0.6, 0.3, 0.55), CFrame.new(-0.05, -0.12, 0), paint, "SmoothPlastic", nil, { Reflectance = 0.15 })
			d("WindowFront", Vector3.new(0.02, 0.22, 0.5), CFrame.new(0.26, -0.12, 0), COLORS.Glass, "Glass", nil, { Transparency = 0.2 })
			d("WindowSide", Vector3.new(0.45, 0.2, 0.57), CFrame.new(-0.05, -0.1, 0), COLORS.Glass, "Glass", nil, { Transparency = 0.3 })
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local wheel = Vector3.new(sx * 0.36, -0.53, sz * 0.31)
					d("Wheel", Vector3.new(0.12, 0.34, 0.34), CFrame.new(wheel) * CFrame.Angles(0, math.rad(90), 0), COLORS.Black, "SmoothPlastic", Enum.PartType.Cylinder)
					d("Hubcap", Vector3.new(0.13, 0.16, 0.16), CFrame.new(wheel) * CFrame.Angles(0, math.rad(90), 0), COLORS.Metal, "Metal", Enum.PartType.Cylinder)
				end
				d("Headlight", Vector3.new(0.02, 0.08, 0.12), CFrame.new(0.555, -0.4, sx * 0.18), Color3.fromRGB(255, 240, 180), "Neon")
			end
		elseif style == 2 then
			-- Ballon de plage.
			local colors = { Color3.fromRGB(232, 60, 56), Color3.fromRGB(250, 210, 40), Color3.fromRGB(46, 120, 226), Color3.fromRGB(60, 180, 96) }
			ball("Ball", 1.05, Vector3.new(0, 0, 0), COLORS.White)
			for k = 1, 4 do
				d("Stripe", Vector3.new(0.12, 1.07, 1.07), CFrame.Angles(0, math.rad(k * 45), 0) * CFrame.Angles(0, 0, 0), colors[k], "SmoothPlastic", Enum.PartType.Cylinder)
			end
			ball("Cap", 0.2, Vector3.new(0, 0.5, 0), COLORS.White)
		else
			-- Robot jouet.
			local metal = pick({ Color3.fromRGB(200, 206, 216), Color3.fromRGB(80, 150, 230), Color3.fromRGB(240, 120, 40) }, math.floor(index / 4))
			d("Torso", Vector3.new(0.6, 0.5, 0.4), CFrame.new(0, -0.15, 0), metal, "Metal")
			d("Chest", Vector3.new(0.3, 0.2, 0.02), CFrame.new(0, -0.1, 0.21), Color3.fromRGB(60, 220, 240), "Neon")
			d("Head", Vector3.new(0.45, 0.35, 0.38), CFrame.new(0, 0.3, 0), metal, "Metal")
			for _, sx in { -1, 1 } do
				d("Eye", Vector3.new(0.1, 0.1, 0.02), CFrame.new(sx * 0.1, 0.33, 0.2), Color3.fromRGB(255, 80, 60), "Neon")
				d("Arm", Vector3.new(0.14, 0.45, 0.14), CFrame.new(sx * 0.38, -0.15, 0), metal:Lerp(Color3.new(0, 0, 0), 0.2), "Metal")
				d("Leg", Vector3.new(0.18, 0.3, 0.2), CFrame.new(sx * 0.15, -0.55, 0), metal:Lerp(Color3.new(0, 0, 0), 0.3), "Metal")
			end
			vcyl("Antenna", 0.25, 0.04, Vector3.new(0, 0.6, 0), COLORS.DarkMetal)
			ball("AntennaTip", 0.1, Vector3.new(0, 0.7, 0), Color3.fromRGB(255, 60, 60), "Neon")
		end
	elseif itemType == "Bottle" then
		hiddenMain()
		local style = (index - 1) % 4
		local liquid = pick({ Color3.fromRGB(60, 140, 230), Color3.fromRGB(250, 196, 50), Color3.fromRGB(80, 200, 220), Color3.fromRGB(230, 120, 200), Color3.fromRGB(120, 210, 90) }, math.floor(index / 4))
		if style == 0 or style == 3 then
			-- Bidon de lessive avec poignée.
			d("Jug", Vector3.new(0.72, 1.0, 0.46), CFrame.new(0, -0.18, 0), liquid, "SmoothPlastic")
			d("Shoulder", Vector3.new(0.5, 0.18, 0.42), CFrame.new(-0.08, 0.4, 0), liquid, "SmoothPlastic")
			d("Handle", Vector3.new(0.1, 0.36, 0.2), CFrame.new(0.27, 0.42, 0), liquid, "SmoothPlastic")
			d("HandleTop", Vector3.new(0.32, 0.08, 0.2), CFrame.new(0.15, 0.6, 0), liquid, "SmoothPlastic")
			vcyl("Cap", 0.16, 0.24, Vector3.new(-0.15, 0.57, 0), COLORS.White)
			d("Label", Vector3.new(0.56, 0.5, 0.02), CFrame.new(0, -0.15, 0.24), COLORS.White)
			d("LabelStripe", Vector3.new(0.56, 0.12, 0.022), CFrame.new(0, -0.05, 0.245), pick(BRIGHT_COLORS, 3))
			ball("LabelBubble", 0.14, Vector3.new(0.12, -0.25, 0.24), liquid:Lerp(Color3.new(1, 1, 1), 0.4))
		elseif style == 1 then
			-- Liquide vaisselle : bouteille haute.
			vcyl("BottleBody", 1.0, 0.42, Vector3.new(0, -0.2, 0), liquid, "Glass")
			vcyl("Neck", 0.22, 0.24, Vector3.new(0, 0.4, 0), liquid, "Glass")
			vcyl("Cap", 0.16, 0.18, Vector3.new(0, 0.6, 0), Color3.fromRGB(240, 240, 240))
			d("Label", Vector3.new(0.3, 0.45, 0.02), CFrame.new(0, -0.2, 0.21), COLORS.White)
			ball("Lemon", 0.14, Vector3.new(0, -0.15, 0.22), Color3.fromRGB(250, 220, 60))
		else
			-- Spray nettoyant.
			d("SprayBody", Vector3.new(0.5, 0.9, 0.36), CFrame.new(0, -0.25, 0), liquid, "Glass", nil, { Transparency = 0.15 })
			vcyl("Collar", 0.12, 0.26, Vector3.new(0, 0.26, 0), COLORS.White)
			d("Trigger", Vector3.new(0.4, 0.2, 0.2), CFrame.new(0.08, 0.42, 0), COLORS.White)
			d("Nozzle", Vector3.new(0.14, 0.1, 0.12), CFrame.new(0.32, 0.45, 0), Color3.fromRGB(230, 60, 60))
			d("Lever", Vector3.new(0.06, 0.24, 0.1), CFrame.new(0.18, 0.26, 0), COLORS.White)
			d("Label", Vector3.new(0.38, 0.4, 0.02), CFrame.new(0, -0.25, 0.19), COLORS.White)
		end
	elseif itemType == "Can" then
		hiddenMain()
		local labelColor = pick({ Color3.fromRGB(220, 50, 46), Color3.fromRGB(60, 140, 70), Color3.fromRGB(250, 196, 40), Color3.fromRGB(240, 220, 150), Color3.fromRGB(250, 150, 60) })
		vcyl("Tin", 0.65, 0.48, Vector3.new(0, 0, 0), COLORS.Metal, "Metal")
		vcyl("Label", 0.44, 0.495, Vector3.new(0, -0.01, 0), labelColor)
		vcyl("LabelStripe", 0.08, 0.5, Vector3.new(0, 0.12, 0), COLORS.White)
		vcyl("TopRim", 0.04, 0.5, Vector3.new(0, 0.31, 0), Color3.fromRGB(220, 224, 230), "Metal")
		vcyl("BottomRim", 0.04, 0.5, Vector3.new(0, -0.31, 0), Color3.fromRGB(220, 224, 230), "Metal")
		d("PullTab", Vector3.new(0.12, 0.02, 0.08), CFrame.new(0, 0.335, 0.1), Color3.fromRGB(200, 204, 210), "Metal")
		d("Picture", Vector3.new(0.18, 0.18, 0.02), CFrame.new(0, -0.05, 0.25), labelColor:Lerp(Color3.new(1, 1, 1), 0.5))
	elseif itemType == "Gadget" then
		local boxColor = pick({ COLORS.White, Color3.fromRGB(30, 32, 38), COLORS.White, Color3.fromRGB(220, 50, 60) })
		solidMain(boxColor, "SmoothPlastic")
		local ink = if boxColor.R + boxColor.G + boxColor.B > 1.5 then Color3.fromRGB(30, 32, 38) else COLORS.White
		local style = (index - 1) % 4
		local face = 0.21
		if style == 0 then
			-- Casque audio dessiné sur la boîte.
			d("Band", Vector3.new(0.5, 0.06, 0.02), CFrame.new(0, 0.32, face), ink)
			d("BandSide", Vector3.new(0.06, 0.3, 0.02), CFrame.new(-0.25, 0.17, face), ink)
			d("BandSide", Vector3.new(0.06, 0.3, 0.02), CFrame.new(0.25, 0.17, face), ink)
			d("EarCup", Vector3.new(0.18, 0.24, 0.025), CFrame.new(-0.25, 0, face), pick(BRIGHT_COLORS))
			d("EarCup", Vector3.new(0.18, 0.24, 0.025), CFrame.new(0.25, 0, face), pick(BRIGHT_COLORS))
		elseif style == 1 then
			-- Smartphone.
			d("Phone", Vector3.new(0.36, 0.66, 0.025), CFrame.new(0, 0.05, face), Color3.fromRGB(20, 20, 24))
			d("Screen", Vector3.new(0.3, 0.56, 0.03), CFrame.new(0, 0.06, face), pick({ Color3.fromRGB(80, 160, 250), Color3.fromRGB(240, 120, 200), Color3.fromRGB(100, 220, 160) }), "Neon")
		elseif style == 2 then
			-- Manette de jeu.
			d("Pad", Vector3.new(0.6, 0.26, 0.025), CFrame.new(0, 0.05, face), Color3.fromRGB(60, 64, 72))
			d("Grip", Vector3.new(0.16, 0.22, 0.025), CFrame.new(-0.24, -0.12, face) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(60, 64, 72))
			d("Grip", Vector3.new(0.16, 0.22, 0.025), CFrame.new(0.24, -0.12, face) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(60, 64, 72))
			d("Buttons", Vector3.new(0.1, 0.1, 0.03), CFrame.new(0.15, 0.07, face), Color3.fromRGB(240, 70, 70), "Neon")
		else
			-- Enceinte connectée.
			d("Speaker", Vector3.new(0.4, 0.6, 0.025), CFrame.new(0, 0.05, face), Color3.fromRGB(70, 74, 84))
			d("Ring", Vector3.new(0.3, 0.05, 0.03), CFrame.new(0, 0.3, face), Color3.fromRGB(70, 200, 250), "Neon")
		end
		d("BrandStrip", Vector3.new(1.0, 0.16, 0.02), CFrame.new(0, -0.45, face), pick(BRIGHT_COLORS, 4))
		d("TopFlap", Vector3.new(1.0, 0.012, 0.02), CFrame.new(0, 0.6, 0.12), ink)
		d("SideSticker", Vector3.new(0.02, 0.2, 0.3), CFrame.new(0.51, 0.3, 0), COLORS.Gold, "Foil")
	elseif itemType == "Tape" then
		hiddenMain()
		local style = (index - 1) % 3
		local tapeColor = ({ Color3.fromRGB(226, 176, 110), Color3.fromRGB(230, 60, 50), Color3.fromRGB(240, 226, 186) })[style + 1]
		vcyl("Roll", 0.36, 0.9, Vector3.new(0, 0, 0), tapeColor, "SmoothPlastic")
		vcyl("Core", 0.38, 0.52, Vector3.new(0, 0, 0), Color3.fromRGB(176, 130, 84), "Cardboard")
		vcyl("Hole", 0.4, 0.4, Vector3.new(0, 0, 0), Color3.fromRGB(60, 44, 30))
		if style == 1 then
			vcyl("FragileBand", 0.12, 0.91, Vector3.new(0, 0, 0), COLORS.White)
		end
		d("LooseEnd", Vector3.new(0.3, 0.3, 0.02), CFrame.new(0.15, -0.05, 0.455), tapeColor)
	elseif itemType == "Trophy" then
		hiddenMain()
		local metal = pick({ Color3.fromRGB(250, 196, 50), Color3.fromRGB(210, 214, 222), Color3.fromRGB(206, 130, 70), Color3.fromRGB(250, 196, 50) })
		d("Base", Vector3.new(0.7, 0.25, 0.5), CFrame.new(0, -0.575, 0), Color3.fromRGB(30, 30, 34), "Marble")
		d("Plaque", Vector3.new(0.4, 0.12, 0.02), CFrame.new(0, -0.575, 0.26), COLORS.Gold, "Foil")
		d("Step", Vector3.new(0.45, 0.14, 0.32), CFrame.new(0, -0.38, 0), Color3.fromRGB(40, 40, 46), "Marble")
		vcyl("Stem", 0.32, 0.12, Vector3.new(0, -0.15, 0), metal, "Metal")
		ball("Knot", 0.2, Vector3.new(0, -0.02, 0), metal, "Metal")
		ball("Cup", 0.6, Vector3.new(0, 0.28, 0), metal, "Metal")
		vcyl("CupRim", 0.12, 0.64, Vector3.new(0, 0.5, 0), metal, "Metal")
		for _, sx in { -1, 1 } do
			d("HandleOut", Vector3.new(0.06, 0.32, 0.06), CFrame.new(sx * 0.4, 0.3, 0), metal, "Metal")
			d("HandleTop", Vector3.new(0.12, 0.06, 0.06), CFrame.new(sx * 0.35, 0.45, 0), metal, "Metal")
			d("HandleLow", Vector3.new(0.12, 0.06, 0.06), CFrame.new(sx * 0.35, 0.15, 0), metal, "Metal")
		end
		d("Star", Vector3.new(0.14, 0.14, 0.02), CFrame.new(0, 0.28, 0.3) * CFrame.Angles(0, 0, math.rad(45)), COLORS.White, "Neon")
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Material == Enum.Material.Metal then
				part.Reflectance = 0.25
			end
		end
	elseif itemType == "Frame" then
		hiddenMain()
		local border = pick({ COLORS.Gold, COLORS.Walnut, COLORS.Black, COLORS.White })
		d("Back", Vector3.new(1.2, 0.95, 0.05), CFrame.new(0, 0, -0.04), Color3.fromRGB(70, 56, 44))
		d("BorderTop", Vector3.new(1.2, 0.08, 0.1), CFrame.new(0, 0.435, 0), border, if border == COLORS.Gold then "Foil" else "Wood")
		d("BorderBottom", Vector3.new(1.2, 0.08, 0.1), CFrame.new(0, -0.435, 0), border, if border == COLORS.Gold then "Foil" else "Wood")
		d("BorderLeft", Vector3.new(0.08, 0.79, 0.1), CFrame.new(-0.56, 0, 0), border, if border == COLORS.Gold then "Foil" else "Wood")
		d("BorderRight", Vector3.new(0.08, 0.79, 0.1), CFrame.new(0.56, 0, 0), border, if border == COLORS.Gold then "Foil" else "Wood")
		local style = (index - 1) % 4
		local z = 0.0
		if style == 0 then
			-- Photo d'équipe.
			d("Sky", Vector3.new(1.04, 0.79, 0.02), CFrame.new(0, 0, z), Color3.fromRGB(150, 210, 250))
			for k = -1, 1 do
				ball("Head", 0.16, Vector3.new(k * 0.28, 0.08, z + 0.02), Color3.fromRGB(240, 196, 160))
				d("Shirt", Vector3.new(0.24, 0.26, 0.02), CFrame.new(k * 0.28, -0.16, z + 0.015), pick(BRIGHT_COLORS, k + 2))
			end
		elseif style == 1 then
			-- Paysage.
			d("Sky", Vector3.new(1.04, 0.79, 0.02), CFrame.new(0, 0, z), Color3.fromRGB(130, 200, 250))
			d("Hill", Vector3.new(1.04, 0.3, 0.025), CFrame.new(0, -0.245, z), Color3.fromRGB(90, 180, 80))
			d("Hill2", Vector3.new(0.6, 0.2, 0.03), CFrame.new(0.2, -0.13, z) * CFrame.Angles(0, 0, math.rad(10)), Color3.fromRGB(70, 150, 70))
			d("Sun", Vector3.new(0.16, 0.16, 0.03), CFrame.new(-0.3, 0.2, z), Color3.fromRGB(255, 220, 80), "Neon")
		elseif style == 2 then
			-- Diplôme.
			d("Paper", Vector3.new(1.04, 0.79, 0.02), CFrame.new(0, 0, z), Color3.fromRGB(250, 244, 220))
			for line = 0, 2 do
				d("TextLine", Vector3.new(0.7 - line * 0.15, 0.04, 0.025), CFrame.new(0, 0.22 - line * 0.13, z), Color3.fromRGB(120, 100, 80))
			end
			d("Seal", Vector3.new(0.025, 0.2, 0.2), CFrame.new(0.3, -0.22, z) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(210, 50, 50), "SmoothPlastic", Enum.PartType.Cylinder)
		else
			-- Portrait.
			d("Backdrop", Vector3.new(1.04, 0.79, 0.02), CFrame.new(0, 0, z), Color3.fromRGB(110, 120, 140))
			ball("Head", 0.26, Vector3.new(0, 0.1, z + 0.02), Color3.fromRGB(236, 190, 150))
			d("Suit", Vector3.new(0.5, 0.26, 0.02), CFrame.new(0, -0.24, z + 0.015), Color3.fromRGB(40, 44, 60))
			d("Tie", Vector3.new(0.05, 0.18, 0.025), CFrame.new(0, -0.22, z + 0.02), Color3.fromRGB(200, 40, 50))
		end
		d("Stand", Vector3.new(0.12, 0.7, 0.05), CFrame.new(0, -0.15, -0.2) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(70, 56, 44))
	elseif itemType == "Binder" then
		hiddenMain()
		local category = TidyConfig.GetCategory("Binder", categoryId) or TidyConfig.Categories.Binder[1]
		d("CoverLeft", Vector3.new(0.04, 1.3, 1.0), CFrame.new(-0.18, 0, 0), category.Color)
		d("CoverRight", Vector3.new(0.04, 1.3, 1.0), CFrame.new(0.18, 0, 0), category.Color)
		d("Spine", Vector3.new(0.4, 1.3, 0.05), CFrame.new(0, 0, -0.475), category.Color)
		d("Pages", Vector3.new(0.3, 1.22, 0.9), CFrame.new(0, 0, 0.03), Color3.fromRGB(250, 248, 240))
		d("SpineLabel", Vector3.new(0.3, 0.42, 0.02), CFrame.new(0, 0.25, -0.505), COLORS.White)
		d("SpineText", Vector3.new(0.2, 0.05, 0.022), CFrame.new(0, 0.3, -0.508), COLORS.Black)
		d("SpineText", Vector3.new(0.16, 0.05, 0.022), CFrame.new(0, 0.2, -0.508), COLORS.Black)
		d("FingerHole", Vector3.new(0.022, 0.16, 0.16), CFrame.new(0, -0.4, -0.505) * CFrame.Angles(0, math.rad(90), 0), COLORS.Black, "SmoothPlastic", Enum.PartType.Cylinder)
		d("Ring", Vector3.new(0.04, 0.5, 0.04), CFrame.new(-0.12, 0.25, -0.42), COLORS.Metal, "Metal")
	else
		error("Unknown item type: " .. tostring(itemType))
	end

	-- Les petits objets ne bloquent pas les joueurs (on peut marcher au milieu du désordre).
	if itemType ~= "Chair" and itemType ~= "Box" then
		main.CanCollide = false
	end
	model.PrimaryPart = main
	return model, main
end

local function createItem(parent, itemType, index, homeCFrame, roomId, categoryId)
	local model = buildItemParts(itemType, index, categoryId)
	model:PivotTo(homeCFrame)
	model:SetAttribute("ItemType", itemType)
	model:SetAttribute("ItemName", TidyConfig.GetVariantName(itemType, index))
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

---------------------------------------------------------------------------
-- Placement au hasard des objets : grille pour aller vite même avec des milliers d'objets
---------------------------------------------------------------------------
local GRID_SIZE = 8

local function gridCells(minX, maxX, minZ, maxZ)
	return math.floor(minX / GRID_SIZE), math.floor(maxX / GRID_SIZE), math.floor(minZ / GRID_SIZE), math.floor(maxZ / GRID_SIZE)
end

local function gridInsert(grid, minX, maxX, minZ, maxZ, entry)
	local x1, x2, z1, z2 = gridCells(minX, maxX, minZ, maxZ)
	for cx = x1, x2 do
		for cz = z1, z2 do
			local key = cx * 65536 + cz
			local list = grid[key]
			if not list then
				list = {}
				grid[key] = list
			end
			table.insert(list, entry)
		end
	end
end

-- Grille des obstacles d'un étage (meubles, murs).
local function buildObstacleGrid(floorTop)
	local grid = {}
	for _, o in obstacles do
		if o[5] == floorTop then
			gridInsert(grid, o[1], o[2], o[3], o[4], o)
		end
	end
	return grid
end

local function overlapsObstacle(grid, x, z, radius)
	local x1, x2, z1, z2 = gridCells(x - radius, x + radius, z - radius, z + radius)
	for cx = x1, x2 do
		for cz = z1, z2 do
			local list = grid[cx * 65536 + cz]
			if list then
				for _, o in list do
					if x + radius > o[1] and x - radius < o[2] and z + radius > o[3] and z - radius < o[4] then
						return true
					end
				end
			end
		end
	end
	return false
end

local function overlapsItems(grid, x, z, radius)
	local x1, x2, z1, z2 = gridCells(x - radius - 2.5, x + radius + 2.5, z - radius - 2.5, z + radius + 2.5)
	for cx = x1, x2 do
		for cz = z1, z2 do
			local list = grid[cx * 65536 + cz]
			if list then
				for _, p in list do
					local dx, dz = p[1] - x, p[2] - z
					if dx * dx + dz * dz < (p[3] + radius) ^ 2 then
						return true
					end
				end
			end
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Éclairage (lumineux, couleurs vives) et point d'apparition
---------------------------------------------------------------------------
local function setupLighting()
	-- Lumière douce : soleil et ambiance modérés, pas d'effet "brûlé".
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 1.6 * LIGHT_LEVEL
	Lighting.ExposureCompensation = -0.35 + (LIGHT_LEVEL - 1) * 0.5
	Lighting.Ambient = Color3.fromRGB(96, 92, 88)
	Lighting.OutdoorAmbient = Color3.fromRGB(118, 114, 108)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.45
	Lighting.GlobalShadows = true

	local colorCorrection = Lighting:FindFirstChild("AgencyColorCorrection")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "AgencyColorCorrection"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Brightness = -0.04
	colorCorrection.Saturation = 0.15
	colorCorrection.Contrast = 0.1
	colorCorrection.TintColor = Color3.fromRGB(255, 248, 238)

	local atmosphere = Lighting:FindFirstChild("AgencyAtmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "AgencyAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.25
	atmosphere.Haze = 0.2
	atmosphere.Glare = 0
	atmosphere.Color = Color3.fromRGB(205, 218, 232)
	atmosphere.Decay = Color3.fromRGB(150, 175, 210)

	local bloom = Lighting:FindFirstChild("AgencyBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "AgencyBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.12
	bloom.Size = 18
	bloom.Threshold = 2.4
end

local function createSpawn(parent, name, position)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0))
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
-- Décor commun : lustres, suspensions, palmiers, panneaux suspendus, tableaux
---------------------------------------------------------------------------
local Deco = {}

-- Lustre doré avec bras, ampoules et pampilles.
function Deco.Chandelier(parent, x, ceilingY, z, scale)
	scale = scale or 1
	local model = newModel(parent, "Chandelier")
	local y = ceilingY - 2.6 * scale
	block(model, "Chain", Vector3.new(0.12, ceilingY - y, 0.12), Vector3.new(x, (ceilingY + y) / 2, z), COLORS.Gold, "Metal", { CanCollide = false })
	local ring = cylinder(model, "Ring", 0.25 * scale, 3.4 * scale, Vector3.new(x, y, z), COLORS.Gold, "Metal")
	ring.CanCollide = false
	ring.Reflectance = 0.3
	local core = block(model, "Core", Vector3.new(0.7, 1.4, 0.7) * scale, Vector3.new(x, y - 0.4 * scale, z), COLORS.Gold, "Metal", { CanCollide = false })
	core.Shape = Enum.PartType.Ball
	for k = 0, 7 do
		local angle = math.rad(k * 45)
		local px, pz = x + math.cos(angle) * 1.7 * scale, z + math.sin(angle) * 1.7 * scale
		local bulb = block(model, "Bulb", Vector3.new(0.4, 0.4, 0.4) * scale, Vector3.new(px, y + 0.35 * scale, pz), COLORS.Bulb, "Neon", { CanCollide = false, CastShadow = false })
		bulb.Shape = Enum.PartType.Ball
		local crystal = block(model, "Crystal", Vector3.new(0.18, 0.5, 0.18) * scale, Vector3.new(px, y - 0.45 * scale, pz), Color3.fromRGB(230, 244, 255), "Glass", { CanCollide = false, CastShadow = false, Transparency = 0.25 })
		crystal.Reflectance = 0.4
	end
	local light = Instance.new("PointLight")
	light.Range = 22 * scale
	light.Brightness = lampPower(0.8)
	light.Color = Color3.fromRGB(255, 220, 170)
	light.Shadows = false
	light.Parent = core
	return model
end

-- Suspension (lampe qui pend du plafond). withLight = false pour économiser les lumières.
function Deco.Pendant(parent, x, ceilingY, z, drop, shadeColor, withLight)
	local model = newModel(parent, "PendantLamp")
	local y = ceilingY - drop
	block(model, "Cable", Vector3.new(0.06, drop, 0.06), Vector3.new(x, ceilingY - drop / 2, z), COLORS.Black, "SmoothPlastic", { CanCollide = false, CastShadow = false })
	local shade = cylinder(model, "Shade", 0.9, 2.2, Vector3.new(x, y - 0.3, z), shadeColor, "Metal")
	shade.CanCollide = false
	local top = cylinder(model, "ShadeTop", 0.5, 1, Vector3.new(x, y + 0.35, z), shadeColor, "Metal")
	top.CanCollide = false
	local bulb = block(model, "Bulb", Vector3.new(0.7, 0.7, 0.7), Vector3.new(x, y - 0.8, z), COLORS.Bulb, "Neon", { CanCollide = false, CastShadow = false })
	bulb.Shape = Enum.PartType.Ball
	if withLight ~= false then
		local light = Instance.new("PointLight")
		light.Range = 18
		light.Brightness = lampPower(0.6)
		light.Color = Color3.fromRGB(255, 226, 180)
		light.Shadows = false
		light.Parent = bulb
	end
	return model
end

-- Palmier en pot (hall d'accueil, siège social).
function Deco.Palm(parent, x, z, scale)
	scale = scale or 1
	local model = newModel(parent, "PalmTree")
	local potTop = FLOOR_TOP + 2.2 * scale
	cylinder(model, "Planter", 2.2 * scale, 3.4 * scale, Vector3.new(x, FLOOR_TOP + 1.1 * scale, z), COLORS.White, "SmoothPlastic")
	cylinder(model, "PlanterRim", 0.3 * scale, 3.7 * scale, Vector3.new(x, potTop, z), COLORS.Gold, "Metal")
	cylinder(model, "Soil", 0.1, 3.1 * scale, Vector3.new(x, potTop + 0.1, z), Color3.fromRGB(96, 66, 44), "Ground")
	local trunkHeight = 7 * scale
	for i = 0, 5 do
		local segment = cylinder(model, "Trunk", trunkHeight / 6 + 0.1, (0.9 - i * 0.07) * scale, Vector3.new(x + i * 0.12 * scale, potTop + (i + 0.5) * trunkHeight / 6, z), Color3.fromRGB(150 - i * 4, 110 - i * 3, 70), "Wood")
		segment.CanCollide = i < 2
	end
	local crown = Vector3.new(x + 0.7 * scale, potTop + trunkHeight, z)
	for k = 0, 7 do
		local angle = math.rad(k * 45 + 10)
		local leaf = newPart(model, "Leaf", Vector3.new(0.9 * scale, 0.12, 4.2 * scale), CFrame.new(crown) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -2 * scale) * CFrame.Angles(math.rad(-22), 0, 0), if k % 2 == 0 then Color3.fromRGB(70, 160, 70) else Color3.fromRGB(96, 186, 80), "Grass", { CanCollide = false })
		leaf.CastShadow = true
	end
	local coconut = block(model, "Coconuts", Vector3.new(0.8, 0.8, 0.8) * scale, crown - Vector3.new(0, 0.4 * scale, 0), Color3.fromRGB(110, 76, 44), "SmoothPlastic", { CanCollide = false })
	coconut.Shape = Enum.PartType.Ball
	return model
end

-- Panneau suspendu de rayon (style magasin) : texte blanc sur fond coloré, avec 2 câbles.
function Deco.HangingSign(parent, text, position, facing, width, color, ceilingY)
	local model = newModel(parent, "HangingSign")
	local height = math.max(2, width * 0.22)
	local board = newPart(model, "Board", Vector3.new(width, height, 0.4), CFrame.lookAt(position, position + facing), color, "SmoothPlastic", { CanCollide = false })
	newPart(model, "Border", Vector3.new(width + 0.4, height + 0.4, 0.3), CFrame.lookAt(position, position + facing), COLORS.White, "SmoothPlastic", { CanCollide = false })
	addSignText(board, Enum.NormalId.Front, text, COLORS.White).Font = Enum.Font.FredokaOne
	addSignText(board, Enum.NormalId.Back, text, COLORS.White).Font = Enum.Font.FredokaOne
	if ceilingY then
		local wire = ceilingY - (position.Y + height / 2)
		for _, side in { -1, 1 } do
			local top = position + board.CFrame.RightVector * side * (width / 2 - 0.6)
			block(model, "Wire", Vector3.new(0.06, wire, 0.06), Vector3.new(top.X, position.Y + height / 2 + wire / 2, top.Z), COLORS.DarkMetal, "Metal", { CanCollide = false, CastShadow = false })
		end
	end
	return model
end

-- Lambris (boiserie basse) contre un mur, avec une baguette dorée.
function Deco.Wainscot(parent, from, to, facing, height, color)
	local center = (from + to) / 2
	local length = (to - from).Magnitude
	local base = CFrame.lookAt(center + Vector3.new(0, FLOOR_TOP + height / 2 - center.Y, 0), center + Vector3.new(0, FLOOR_TOP + height / 2 - center.Y, 0) + facing)
	newPart(parent, "Wainscot", Vector3.new(length, height, 0.15), base, color, "Wood", { CanCollide = false })
	newPart(parent, "WainscotRail", Vector3.new(length, 0.2, 0.25), base * CFrame.new(0, height / 2, 0), COLORS.Gold, "Foil", { CanCollide = false })
	local panels = math.max(1, math.floor(length / 3))
	for i = 0, panels - 1 do
		local x = -length / 2 + (i + 0.5) * (length / panels)
		newPart(parent, "WainscotPanel", Vector3.new(length / panels - 0.6, height - 1, 0.06), base * CFrame.new(x, 0, -0.1), color:Lerp(Color3.new(0, 0, 0), 0.15), "Wood", { CanCollide = false })
	end
end

-- Pilastre (demi-colonne) contre un mur, avec chapiteau doré.
function Deco.Pilaster(parent, position, facing, height)
	local base = CFrame.lookAt(position, position + facing)
	newPart(parent, "Pilaster", Vector3.new(1.2, height, 0.5), base * CFrame.new(0, 0, -0.25), COLORS.Marble, "Marble", { CanCollide = false })
	newPart(parent, "PilasterCap", Vector3.new(1.6, 0.5, 0.7), base * CFrame.new(0, height / 2 - 0.25, -0.3), COLORS.Gold, "Foil", { CanCollide = false })
	newPart(parent, "PilasterBase", Vector3.new(1.6, 0.6, 0.7), base * CFrame.new(0, -height / 2 + 0.3, -0.3), COLORS.Gold, "Foil", { CanCollide = false })
end

-- Palette avec des cartons empilés (décor d'entrepôt).
function Deco.PalletStack(parent, x, z, layers, color)
	local model = newModel(parent, "PalletStack")
	block(model, "Pallet", Vector3.new(4, 0.5, 4), Vector3.new(x, FLOOR_TOP + 0.25, z), Color3.fromRGB(196, 150, 96), "WoodPlanks")
	for layer = 0, layers - 1 do
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				block(model, "StockBox", Vector3.new(1.9, 1.3, 1.9), Vector3.new(x + sx * 0.97, FLOOR_TOP + 0.5 + 0.65 + layer * 1.3, z + sz * 0.97), color or COLORS.Cardboard, "Cardboard")
			end
		end
	end
	block(model, "Wrap", Vector3.new(4.05, layers * 1.3, 4.05), Vector3.new(x, FLOOR_TOP + 0.5 + layers * 0.65, z), Color3.fromRGB(230, 240, 250), "Glass", { Transparency = 0.75, CanCollide = false, CastShadow = false })
	return model
end

---------------------------------------------------------------------------
-- Niveau 1 : agence pour l'emploi (décor supplémentaire)
---------------------------------------------------------------------------
local function decorateAgency(parent)
	setFloor(GROUND_TOP)
	-- Accueil : mur de lattes de bois derrière le comptoir, avec bandeau lumineux.
	local slats = newFolder(parent, "ReceptionSlatWall")
	local x = -29
	while x <= 10 do
		if x < -7.6 then
			block(slats, "WallSlat", Vector3.new(0.4, 11.4, 0.25), Vector3.new(x, FLOOR_TOP + 0.6 + 5.7, 20.42), COLORS.Wood, "Wood", { CanCollide = false })
		end
		x += 0.9
	end
	block(slats, "SlatLed", Vector3.new(21, 0.15, 0.1), Vector3.new(-18.5, FLOOR_TOP + 11.6, 20.6), Color3.fromRGB(255, 220, 160), "Neon", { CanCollide = false })

	-- Salle de pause : crédence en carreaux colorés et suspensions au-dessus des tables.
	local tiles = newFolder(parent, "Backsplash")
	local tileColors = { Color3.fromRGB(80, 180, 190), Color3.fromRGB(250, 250, 246), Color3.fromRGB(240, 200, 80) }
	for row = 0, 2 do
		for col = 0, 10 do
			block(tiles, "Tile", Vector3.new(0.85, 0.85, 0.06), Vector3.new(-48.5 + col * 0.9, FLOOR_TOP + 4.6 + row * 0.9, 20.32), tileColors[(row + col) % 3 + 1], "CeramicTiles", { CanCollide = false })
		end
	end
	for _, p in { { -66, 34 }, { -50, 34 }, { -66, 48 }, { -50, 48 } } do
		Deco.Pendant(parent, p[1], CEILING_BOTTOM - 0.3, p[2], 4, Color3.fromRGB(240, 120, 60), true)
	end

	-- Réserve : bandes jaunes au sol et palettes.
	for _, z in { -52.4, -41.2, -30.2 } do
		block(parent, "HazardLine", Vector3.new(28, 0.02, 0.4), Vector3.new(65, FLOOR_TOP + 0.01, z), COLORS.Hazard, "SmoothPlastic", { CanCollide = false })
	end
	Deco.PalletStack(parent, 58, -16, 2, COLORS.Cardboard)

	-- Courrier : lignes de circulation au sol.
	for _, z in { -90, -72 } do
		block(parent, "FloorLine", Vector3.new(48, 0.02, 0.35), Vector3.new(55, FLOOR_TOP + 0.01, z), COLORS.Hazard, "SmoothPlastic", { CanCollide = false })
	end

	-- Bibliothèque : style luxueux (lambris, pilastres dorés, lustres).
	Deco.Wainscot(parent, Vector3.new(-19.55, 0, -99.6), Vector3.new(-19.55, 0, -85.2), Vector3.new(1, 0, 0), 3.5, COLORS.Walnut)
	Deco.Wainscot(parent, Vector3.new(-19.55, 0, -74.8), Vector3.new(-19.55, 0, -60.4), Vector3.new(1, 0, 0), 3.5, COLORS.Walnut)
	Deco.Wainscot(parent, Vector3.new(29.55, 0, -60.4), Vector3.new(29.55, 0, -74.8), Vector3.new(-1, 0, 0), 3.5, COLORS.Walnut)
	Deco.Wainscot(parent, Vector3.new(29.55, 0, -85.2), Vector3.new(29.55, 0, -99.6), Vector3.new(-1, 0, 0), 3.5, COLORS.Walnut)
	for _, px in { -18.6, 28.6 } do
		Deco.Pilaster(parent, Vector3.new(px, FLOOR_TOP + 6, -99.5), Vector3.new(0, 0, 1), 12)
	end
	Deco.Chandelier(parent, 5, CEILING_BOTTOM - 0.3, -86, 0.9)
	Deco.Chandelier(parent, 5, CEILING_BOTTOM - 0.3, -70, 0.9)

	-- Étage : bureau du directeur luxueux.
	setFloor(UPPER_TOP)
	Deco.Wainscot(parent, Vector3.new(-79.4, 0, 19.6), Vector3.new(-79.4, 0, -59.6), Vector3.new(1, 0, 0), 2.8, COLORS.Walnut)
	Deco.Chandelier(parent, -50, CEILING_BOTTOM - 0.3, -16, 1)
	for _, pz in { -55, -20, 15 } do
		Deco.Pilaster(parent, Vector3.new(-79.5, FLOOR_TOP + 6, pz), Vector3.new(1, 0, 0), 12)
	end
	-- Salon des recruteurs : suspensions colorées.
	for _, p in { { -65, 30 }, { -35, 30 }, { -65, 50 }, { -35, 50 } } do
		Deco.Pendant(parent, p[1], CEILING_BOTTOM - 0.3, p[2], 3.5, Color3.fromRGB(60, 150, 200), false)
	end
	setFloor(GROUND_TOP)
end

local function buildAgency(root)
	PARTITION_STYLE = { Color = COLORS.Partition, Material = "Plaster", Base = COLORS.WallBand }
	local structure = newFolder(root, "Building")
	local furniture = newFolder(root, "Furniture")
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

	decorateAgency(newFolder(root, "Decor"))
	-- Endroit laissé libre : arrivée du joueur.
	addObstacle(-5, 5, 48, HALF_Z)
end

---------------------------------------------------------------------------
-- Niveau 2 : entrepôt de distribution (immense hall, sections sans murs)
---------------------------------------------------------------------------
local WH = {}
WH.MinX, WH.MaxX, WH.MinZ, WH.MaxZ = 820, 1180, -120, 120
WH.Height = 30

WH.SectionColors = {
	WReceiving = Color3.fromRGB(70, 168, 182),
	WFootwear = Color3.fromRGB(232, 96, 60),
	WToys = Color3.fromRGB(230, 70, 140),
	WHousehold = Color3.fromRGB(60, 150, 220),
	WPantry = Color3.fromRGB(80, 170, 80),
	WElectronics = Color3.fromRGB(110, 90, 210),
	WPackaging = Color3.fromRGB(214, 160, 60),
	WOutbound = Color3.fromRGB(40, 140, 160),
	WReturns = Color3.fromRGB(200, 80, 70),
}

-- Nombre d'objets de chaque type (et couleur) à prévoir sur les étagères d'un niveau.
local function countNeeded(mapId)
	local needed = {}
	local counters = {}
	for _, room in TidyConfig.GetMapRooms(mapId) do
		for _, itemType in TidyConfig.TypeOrder do
			for _ = 1, room.Items[itemType] or 0 do
				counters[itemType] = (counters[itemType] or 0) + 1
				local categories = TidyConfig.Categories[itemType]
				local key = itemType
				if categories then
					key = itemType .. "|" .. categories[(counters[itemType] - 1) % #categories + 1].Id
				end
				needed[key] = (needed[key] or 0) + 1
			end
		end
	end
	return needed
end

-- Étagère double face (allée des deux côtés), le long de Z. Crée "perSlots" places.
function WH.Rack(parent, name, cx, z1, z2, itemType, categoryId, perSlots, accent)
	local model = newModel(parent, name)
	local length = z2 - z1
	local cz = (z1 + z2) / 2
	local size = ITEM_SIZES[itemType]
	local rackHeight = 10
	local levelGap = math.max(1.5, size.Y + 0.75)
	local levels = math.clamp(math.floor((rackHeight - 0.6) / levelGap), 1, 6)
	local step = size.X + 0.3
	local perSide = math.floor((length - 0.8) / step)

	-- Montants bleus et lisses orange (style rayonnage industriel).
	local segments = math.max(1, math.ceil(length / 9))
	for i = 0, segments do
		local z = z1 + i * (length / segments)
		for _, side in { -1, 1 } do
			block(model, "Upright", Vector3.new(0.3, rackHeight, 0.3), Vector3.new(cx + side * 2.05, FLOOR_TOP + rackHeight / 2, math.clamp(z, z1 + 0.15, z2 - 0.15)), COLORS.RackBlue, "Metal")
		end
	end
	local anchor = nil
	for level = 0, levels - 1 do
		local boardTop = FLOOR_TOP + 0.4 + level * levelGap
		local board = block(model, "ShelfBoard", Vector3.new(4.2, 0.12, length), Vector3.new(cx, boardTop - 0.06, cz), Color3.fromRGB(214, 180, 130), "WoodPlanks")
		for _, side in { -1, 1 } do
			block(model, "Beam", Vector3.new(0.12, 0.3, length), Vector3.new(cx + side * 2.16, boardTop - 0.15, cz), COLORS.RackOrange, "Metal", { CanCollide = false })
		end
		if level == math.floor((levels - 1) / 2) then
			anchor = board
		end
	end
	block(model, "TopBoard", Vector3.new(4.2, 0.15, length), Vector3.new(cx, FLOOR_TOP + rackHeight - 0.075, cz), Color3.fromRGB(214, 180, 130), "WoodPlanks")
	block(model, "BackMesh", Vector3.new(0.08, rackHeight - 0.6, length - 0.4), Vector3.new(cx, FLOOR_TOP + rackHeight / 2, cz), COLORS.DarkMetal, "Metal", { Transparency = 0.55 })
	-- Stock emballé posé en haut de l'étagère.
	for i = 0, 2 do
		local z = z1 + length * (0.2 + i * 0.3)
		block(model, "TopStock", Vector3.new(3.4, 1.6, 3.4), Vector3.new(cx, FLOOR_TOP + rackHeight + 0.8, z), if i == 1 then accent else COLORS.Cardboard, "Cardboard")
	end

	local spots = makeZone(model, itemType, anchor, rackHeight - (anchor.Position.Y - FLOOR_TOP) + 3.2, categoryId)
	local created = 0
	for level = 0, levels - 1 do
		local boardTop = FLOOR_TOP + 0.4 + level * levelGap
		for i = 0, perSide - 1 do
			for _, side in { 1, -1 } do
				if created >= perSlots then
					return model
				end
				local z = z1 + 0.4 + step / 2 + i * step
				local yaw = if side == 1 then math.rad(90) else math.rad(-90)
				createSlot(spots, itemType, CFrame.new(cx + side * 1.05, boardTop + REST_HEIGHTS[itemType], z) * CFrame.Angles(0, yaw, 0), categoryId)
				created += 1
			end
		end
	end
	if created < perSlots then
		warn("[AgencyBuilder] Rack " .. name .. " is too small: " .. created .. " / " .. perSlots)
	end
	return model
end

-- Clôture grillagée autour d'une section verrouillée (disparaît quand elle s'ouvre).
function WH.Fence(parent, room)
	local model = newModel(parent, "Fence_" .. room.Id)
	local inset = 0.8
	local minX, maxX, minZ, maxZ = room.MinX + inset, room.MaxX - inset, room.MinZ + inset, room.MaxZ - inset
	local height = 9.5 -- plus haut qu'un saut
	local text = "LOCKED\n" .. string.upper(room.Name) .. "\nOpens at " .. TidyConfig.FormatNumber(room.Unlock) .. " points earned"
	local function side(from, to)
		local center = (from + to) / 2
		local length = (to - from).Magnitude
		local base = CFrame.lookAt(center + Vector3.new(0, FLOOR_TOP + height / 2, 0), center + Vector3.new(0, FLOOR_TOP + height / 2, 0) + (to - from).Unit:Cross(Vector3.new(0, 1, 0)))
		local mesh = newPart(model, "FenceMesh", Vector3.new(length, height, 0.15), base, Color3.fromRGB(120, 126, 136), "Metal", { Transparency = 0.45 })
		local rail = newPart(model, "FenceRail", Vector3.new(length, 0.35, 0.3), base * CFrame.new(0, height / 2, 0), COLORS.Hazard, "SmoothPlastic", { CanCollide = false })
		local footer = newPart(model, "FenceFooter", Vector3.new(length, 0.5, 0.3), base * CFrame.new(0, -height / 2 + 0.25, 0), COLORS.Hazard, "SmoothPlastic", { CanCollide = false })
		for _, part in { mesh, rail, footer } do
			part:SetAttribute("Room", room.Id)
			CollectionService:AddTag(part, TidyConfig.DoorTag)
			table.insert(allDoors, part)
		end
		local posts = math.max(1, math.floor(length / 10))
		for i = 0, posts do
			local post = newPart(model, "FencePost", Vector3.new(0.3, height + 0.4, 0.3), base * CFrame.new(-length / 2 + i * (length / posts), 0.2, 0), COLORS.DarkMetal, "Metal", { CanCollide = false })
			post:SetAttribute("Room", room.Id)
			table.insert(allDoors, post)
		end
		-- Panneau "verrouillé" au milieu, lisible des deux côtés.
		local sign = newPart(model, "LockedSign", Vector3.new(9, 3, 0.2), base * CFrame.new(0, -0.3, 0), Color3.fromRGB(30, 34, 44), "SmoothPlastic")
		addSignText(sign, Enum.NormalId.Front, text, COLORS.Hazard).Font = Enum.Font.FredokaOne
		addSignText(sign, Enum.NormalId.Back, text, COLORS.Hazard).Font = Enum.Font.FredokaOne
		sign:SetAttribute("Room", room.Id)
		CollectionService:AddTag(sign, TidyConfig.DoorTag)
		table.insert(allDoors, sign)
	end
	side(Vector3.new(minX, 0, maxZ), Vector3.new(maxX, 0, maxZ))
	side(Vector3.new(maxX, 0, minZ), Vector3.new(minX, 0, minZ))
	side(Vector3.new(minX, 0, minZ), Vector3.new(minX, 0, maxZ))
	side(Vector3.new(maxX, 0, maxZ), Vector3.new(maxX, 0, minZ))
end

-- Chariot élévateur (décor).
function WH.Forklift(parent, x, z, yaw)
	local model = newModel(parent, "Forklift")
	local base = CFrame.new(x, FLOOR_TOP, z) * CFrame.Angles(0, yaw, 0)
	newPart(model, "Body", Vector3.new(3, 2, 4.4), base * CFrame.new(0, 1.4, 0.4), COLORS.Hazard, "SmoothPlastic")
	newPart(model, "Counterweight", Vector3.new(3, 1.6, 1), base * CFrame.new(0, 1.2, 2.8), COLORS.DarkMetal, "Metal")
	newPart(model, "Seat", Vector3.new(1.4, 0.4, 1.2), base * CFrame.new(0, 2.6, 1), COLORS.Black, "Fabric", { CanCollide = false })
	newPart(model, "SeatBack", Vector3.new(1.4, 1.2, 0.3), base * CFrame.new(0, 3.2, 1.6), COLORS.Black, "Fabric", { CanCollide = false })
	newPart(model, "Steering", Vector3.new(0.8, 0.1, 0.8), base * CFrame.new(0, 3.4, -0.2) * CFrame.Angles(math.rad(30), 0, 0), COLORS.Black, "SmoothPlastic", { CanCollide = false })
	for _, sx in { -1, 1 } do
		newPart(model, "CagePost", Vector3.new(0.2, 3.6, 0.2), base * CFrame.new(sx * 1.4, 4.2, -0.6), COLORS.Black, "Metal", { CanCollide = false })
		newPart(model, "CagePost", Vector3.new(0.2, 3.6, 0.2), base * CFrame.new(sx * 1.4, 4.2, 2), COLORS.Black, "Metal", { CanCollide = false })
		newPart(model, "Mast", Vector3.new(0.3, 6, 0.3), base * CFrame.new(sx * 1, 3.4, -2), COLORS.DarkMetal, "Metal")
		newPart(model, "Fork", Vector3.new(0.4, 0.15, 3), base * CFrame.new(sx * 0.8, 0.3, -3.6), COLORS.DarkMetal, "Metal")
		for _, wz in { -1.2, 2.2 } do
			local wheel = newPart(model, "Wheel", Vector3.new(0.6, 1.4, 1.4), base * CFrame.new(sx * 1.55, 0.7, wz), COLORS.Black, "SmoothPlastic", { CanCollide = false })
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	newPart(model, "Roof", Vector3.new(3, 0.2, 2.8), base * CFrame.new(0, 6, 0.7), COLORS.Black, "Metal", { CanCollide = false })
	newPart(model, "Beacon", Vector3.new(0.4, 0.4, 0.4), base * CFrame.new(0, 6.3, 1.6), Color3.fromRGB(255, 150, 30), "Neon", { CanCollide = false })
	return model
end

-- Tapis roulant (décor) le long de X.
function WH.Conveyor(parent, x1, x2, z)
	local model = newModel(parent, "Conveyor")
	local length = x2 - x1
	local cx = (x1 + x2) / 2
	block(model, "Frame", Vector3.new(length, 0.6, 3), Vector3.new(cx, FLOOR_TOP + 2.6, z), COLORS.Metal, "Metal")
	block(model, "Belt", Vector3.new(length, 0.1, 2.6), Vector3.new(cx, FLOOR_TOP + 2.95, z), Color3.fromRGB(40, 42, 48), "Rubber")
	for _, side in { -1, 1 } do
		block(model, "Rail", Vector3.new(length, 0.4, 0.15), Vector3.new(cx, FLOOR_TOP + 3.1, z + side * 1.5), COLORS.Hazard, "SmoothPlastic", { CanCollide = false })
	end
	local legs = math.floor(length / 6)
	for i = 0, legs do
		for _, side in { -1, 1 } do
			block(model, "Leg", Vector3.new(0.3, 2.3, 0.3), Vector3.new(x1 + 0.3 + i * ((length - 0.6) / legs), FLOOR_TOP + 1.15, z + side * 1.2), COLORS.DarkMetal, "Metal")
		end
	end
	for i = 0, math.floor(length / 8) - 1 do
		block(model, "BeltBox", Vector3.new(1.4, 1, 1.2), Vector3.new(x1 + 4 + i * 8, FLOOR_TOP + 3.5, z), COLORS.Cardboard, "Cardboard", { CanCollide = false })
	end
	return model
end

-- Table de travail (retours, emballage).
function WH.WorkTable(parent, cx, cz, alongZ)
	local model = newModel(parent, "WorkTable")
	local size = if alongZ then Vector3.new(3, 0.2, 10) else Vector3.new(10, 0.2, 3)
	block(model, "Top", size, Vector3.new(cx, FLOOR_TOP + 3, cz), Color3.fromRGB(226, 196, 150), "WoodPlanks")
	for _, s in { -1, 1 } do
		local offset = if alongZ then Vector3.new(0, 0, s * 4.5) else Vector3.new(s * 4.5, 0, 0)
		block(model, "Leg", if alongZ then Vector3.new(2.6, 2.9, 0.3) else Vector3.new(0.3, 2.9, 2.6), Vector3.new(cx, FLOOR_TOP + 1.45, cz) + offset, COLORS.DarkMetal, "Metal")
	end
	block(model, "TapeDispenser", Vector3.new(0.6, 0.6, 0.4), Vector3.new(cx, FLOOR_TOP + 3.4, cz), Color3.fromRGB(220, 50, 50), "SmoothPlastic", { CanCollide = false })
	return model
end

-- Grand bac (retours).
function WH.Bin(parent, x, z, color)
	local model = newModel(parent, "ReturnBin")
	block(model, "Bin", Vector3.new(4, 3, 4), Vector3.new(x, FLOOR_TOP + 1.5, z), color, "SmoothPlastic")
	block(model, "Rim", Vector3.new(4.2, 0.3, 4.2), Vector3.new(x, FLOOR_TOP + 3.1, z), color:Lerp(Color3.new(0, 0, 0), 0.2), "SmoothPlastic", { CanCollide = false })
	block(model, "Content", Vector3.new(3.6, 0.2, 3.6), Vector3.new(x, FLOOR_TOP + 2.7, z), COLORS.Cardboard, "Cardboard", { CanCollide = false })
	return model
end

function WH.Build(root)
	setFloor(1)
	local savedHeight = WALL_HEIGHT
	WALL_HEIGHT = WH.Height
	setFloor(1)
	PARTITION_STYLE = { Color = COLORS.Wall, Material = "Concrete", Base = COLORS.WallBand }
	local structure = newFolder(root, "Building")
	local furniture = newFolder(root, "Furniture")
	local minX, maxX, minZ, maxZ = WH.MinX, WH.MaxX, WH.MinZ, WH.MaxZ
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local width, depth = maxX - minX, maxZ - minZ
	local top = CEILING_BOTTOM

	-- Sol époxy clair.
	block(structure, "Floor", Vector3.new(width, 1, depth), Vector3.new(cx, FLOOR_TOP - 0.5, cz), Color3.fromRGB(228, 224, 214), "SmoothPlastic", { Reflectance = 0.06 })

	-- Murs : bandeau bas coloré, crème au milieu, bande de fenêtres en haut.
	local function wall(name, size, position)
		local alongX = size.X > size.Z
		local lowH, midH, glassH = 3, 16, 6
		local topH = top - (FLOOR_TOP + lowH + midH + glassH)
		local function piece(suffix, h, y, color, material, options)
			local s = if alongX then Vector3.new(size.X, h, size.Z) else Vector3.new(size.X, h, size.Z)
			block(structure, name .. suffix, s, Vector3.new(position.X, y, position.Z), color, material, options)
		end
		piece("Low", lowH + FLOOR_TOP, (lowH + FLOOR_TOP) / 2, COLORS.WallBand, "SmoothPlastic")
		piece("Mid", midH, FLOOR_TOP + lowH + midH / 2, COLORS.Wall, "Concrete")
		piece("Glass", glassH, FLOOR_TOP + lowH + midH + glassH / 2, COLORS.Glass, "Glass", { Transparency = 0.5 })
		piece("Top", topH, FLOOR_TOP + lowH + midH + glassH + topH / 2, COLORS.Wall, "Concrete")
	end
	wall("NorthWall", Vector3.new(width + 2, 0, 1), Vector3.new(cx, 0, minZ - 0.5))
	wall("SouthWall", Vector3.new(width + 2, 0, 1), Vector3.new(cx, 0, maxZ + 0.5))
	wall("WestWall", Vector3.new(1, 0, depth), Vector3.new(minX - 0.5, 0, cz))
	wall("EastWall", Vector3.new(1, 0, depth), Vector3.new(maxX + 0.5, 0, cz))

	-- Portes de quai (décor) sur le mur sud, avec butoirs jaunes.
	for i, dx in { -120, -60, 60, 120 } do
		local doorX = cx + dx
		block(structure, "DockDoor", Vector3.new(12, 12, 0.3), Vector3.new(doorX, FLOOR_TOP + 6, maxZ - 0.15), Color3.fromRGB(176, 182, 190), "DiamondPlate", { CanCollide = false })
		for k = 0, 7 do
			block(structure, "DockDoorRib", Vector3.new(12, 0.12, 0.1), Vector3.new(doorX, FLOOR_TOP + 1 + k * 1.4, maxZ - 0.35), Color3.fromRGB(130, 136, 146), "Metal", { CanCollide = false })
		end
		for _, side in { -1, 1 } do
			block(structure, "DockBumper", Vector3.new(0.8, 2, 0.8), Vector3.new(doorX + side * 6.8, FLOOR_TOP + 1, maxZ - 0.5), COLORS.Hazard, "SmoothPlastic")
		end
		newSign(structure, "DockSign", "DOCK " .. i, Vector3.new(5, 1.4, 0.1), Vector3.new(doorX, FLOOR_TOP + 13.5, maxZ - 0.1), Vector3.new(0, 0, -1), COLORS.SignBlue)
	end

	-- Toit avec 3 longs puits de lumière, plafond de lattes de bois et bandeaux lumineux.
	local holes = { { 850, 1150, -78, -62 }, { 850, 1150, -8, 8 }, { 850, 1150, 52, 68 } }
	slabWithHoles(structure, "Roof", minX - 1, maxX + 1, minZ - 1, maxZ + 1, top, 1, holes, COLORS.Ceiling, "SmoothPlastic")
	for _, hole in holes do
		skylight(structure, hole, top + 1)
		for _, side in { -1, 1 } do
			block(structure, "SkylightTrim", Vector3.new(hole[2] - hole[1], 0.6, 0.4), Vector3.new((hole[1] + hole[2]) / 2, top - 0.3, (side == 1 and hole[4] or hole[3]) + side * 0.2), COLORS.Trim, "SmoothPlastic", { CanCollide = false })
		end
	end
	slatCeiling(structure, minX, maxX, minZ, maxZ, holes, {})
	for z = minZ + 12, maxZ - 8, 24 do
		local free = true
		for _, hole in holes do
			if z > hole[3] - 1.5 and z < hole[4] + 1.5 then
				free = false
			end
		end
		if free then
			block(structure, "LightStrip", Vector3.new(width - 8, 0.15, 0.6), Vector3.new(cx, top - 0.4, z), COLORS.Light, "Neon", { CanCollide = false, CastShadow = false, Transparency = 0.45 })
		end
	end
	-- Grandes poutres porteuses.
	for x = minX + 40, maxX - 40, 40 do
		block(structure, "RoofBeam", Vector3.new(1.2, 1.6, depth), Vector3.new(x, top - 1.1, cz), COLORS.Trim, "SmoothPlastic", { CanCollide = false })
	end

	-- Suspensions industrielles au-dessus des allées.
	local n = 0
	for x = minX + 20, maxX - 20, 40 do
		for z = minZ + 15, maxZ - 10, 30 do
			n += 1
			local lamp = Deco.Pendant(structure, x, top - 1.9, z, 7, COLORS.DarkMetal, n % 2 == 0)
			local light = lamp:FindFirstChild("Bulb") and lamp.Bulb:FindFirstChildOfClass("PointLight")
			if light then
				light.Range = 38
				light.Brightness = lampPower(0.7)
			end
		end
	end

	-- Sections : marquage au sol coloré et grand panneau suspendu.
	local rooms = TidyConfig.GetMapRooms("Warehouse")
	for _, room in rooms do
		local color = WH.SectionColors[room.Id] or COLORS.SignBlue
		local rcx, rcz = (room.MinX + room.MaxX) / 2, (room.MinZ + room.MaxZ) / 2
		local w, d = room.MaxX - room.MinX, room.MaxZ - room.MinZ
		for _, s in { -1, 1 } do
			block(structure, "FloorMark", Vector3.new(w - 2, 0.02, 0.5), Vector3.new(rcx, FLOOR_TOP + 0.01, rcz + s * (d / 2 - 1.5)), color, "SmoothPlastic", { CanCollide = false })
			block(structure, "FloorMark", Vector3.new(0.5, 0.02, d - 2), Vector3.new(rcx + s * (w / 2 - 1.5), FLOOR_TOP + 0.01, rcz), color, "SmoothPlastic", { CanCollide = false })
		end
		local signZ = if room.Id == "WReceiving" then rcz - 6 else room.MaxZ - 10
		local signX = if room.Id == "WReceiving" then rcx - 80 else rcx
		Deco.HangingSign(structure, string.upper(room.Name), Vector3.new(signX, top - 9, signZ), Vector3.new(0, 0, 1), 22, color, top - 0.6)
		if room.Unlock > 0 then
			WH.Fence(structure, room)
		end
	end

	-- Étagères de chaque section.
	local needed = countNeeded("Warehouse")
	local sectionType = {
		WFootwear = "ShoeBox",
		WToys = "Toy",
		WHousehold = "Bottle",
		WPantry = "Can",
		WElectronics = "Gadget",
		WPackaging = "Tape",
	}
	for _, room in rooms do
		local folder = newFolder(furniture, room.Id)
		local itemType = sectionType[room.Id]
		local color = WH.SectionColors[room.Id]
		local midZ = (room.MinZ + room.MaxZ) / 2
		if itemType then
			local per = math.ceil((needed[itemType] or 0) / 6) + 3
			local index = 0
			for _, offset in { 22.5, 45, 67.5 } do
				for _, range in { { room.MinZ + 12, midZ - 3 }, { midZ + 3, room.MaxZ - 12 } } do
					index += 1
					WH.Rack(folder, itemType .. "Rack" .. index, room.MinX + offset, range[1], range[2], itemType, nil, per, color)
				end
			end
			Deco.PalletStack(folder, room.MinX + 8, room.MinZ + 8, 2, color:Lerp(COLORS.Cardboard, 0.6))
		elseif room.Id == "WOutbound" then
			local cats = TidyConfig.Categories.Parcel
			local index = 0
			for _, offset in { 25, 50 } do
				for _, range in { { room.MinZ + 12, midZ - 3 }, { midZ + 3, room.MaxZ - 12 } } do
					index += 1
					local category = cats[index]
					WH.Rack(folder, "ParcelRack" .. index, room.MinX + offset, range[1], range[2], "Parcel", category.Id, (needed["Parcel|" .. category.Id] or 0) + 3, category.Color)
				end
			end
			WH.WorkTable(folder, room.MinX + 75, midZ - 20, true)
			WH.WorkTable(folder, room.MinX + 75, midZ + 20, true)
		elseif room.Id == "WReturns" then
			WH.WorkTable(folder, room.MinX + 25, midZ - 20, true)
			WH.WorkTable(folder, room.MinX + 25, midZ + 20, true)
			WH.WorkTable(folder, room.MinX + 60, midZ, false)
			for i, p in { { 12, -40 }, { 12, 40 }, { 80, -40 }, { 80, 40 } } do
				WH.Bin(folder, room.MinX + p[1], midZ + p[2], BRIGHT_COLORS[i])
			end
		elseif room.Id == "WReceiving" then
			local per = math.ceil((needed.Box or 0) / 4) + 3
			local index = 0
			for _, x in { minX + 14, minX + 34, maxX - 34, maxX - 14 } do
				index += 1
				WH.Rack(folder, "BoxRack" .. index, x, room.MinZ + 5, room.MaxZ - 6, "Box", nil, per, color)
			end
			WH.Conveyor(folder, 890, 960, room.MinZ + 18)
			WH.Forklift(folder, 1050, room.MinZ + 22, math.rad(30))
			for _, x in { cx - 120, cx - 60, cx + 60, cx + 120 } do
				Deco.PalletStack(folder, x, maxZ - 6, if x < cx then 2 else 3, nil)
			end
			-- Petit bureau vitré du chef de quai.
			local office = newModel(folder, "DockOffice")
			local ox, oz = 1095, room.MinZ + 22
			block(office, "OfficeBase", Vector3.new(14, 0.4, 10), Vector3.new(ox, FLOOR_TOP + 0.2, oz), COLORS.Wood, "WoodPlanks")
			for _, s in { -1, 1 } do
				block(office, "OfficeGlass", Vector3.new(14, 7, 0.2), Vector3.new(ox, FLOOR_TOP + 3.9, oz + s * 4.9), COLORS.Glass, "Glass", { Transparency = 0.5 })
				block(office, "OfficeGlass", Vector3.new(0.2, 7, 9.6), Vector3.new(ox + s * 6.9, FLOOR_TOP + 3.9, oz), COLORS.Glass, "Glass", { Transparency = 0.5 })
			end
			block(office, "OfficeRoof", Vector3.new(14.4, 0.4, 10.4), Vector3.new(ox, FLOOR_TOP + 7.6, oz), COLORS.WallBand, "SmoothPlastic")
			newSign(office, "OfficeSign", "DOCK OFFICE", Vector3.new(6, 1.2, 0.1), Vector3.new(ox, FLOOR_TOP + 8.6, oz - 5.25), Vector3.new(0, 0, -1), COLORS.SignBlue)
			-- Sol vert du quai : chemin piéton.
			block(structure, "Walkway", Vector3.new(60, 0.02, 4), Vector3.new(cx, FLOOR_TOP + 0.012, room.MinZ + 8), Color3.fromRGB(80, 180, 110), "SmoothPlastic", { CanCollide = false })
		end
	end

	-- Panneau d'accueil au-dessus de l'arrivée.
	Deco.HangingSign(structure, "DISTRIBUTION WAREHOUSE", Vector3.new(cx, top - 6, maxZ - 20), Vector3.new(0, 0, 1), 30, Color3.fromRGB(240, 130, 40), top - 0.6)
	addObstacle(cx - 6, cx + 6, maxZ - 14, maxZ)

	WALL_HEIGHT = savedHeight
	setFloor(1)
end

---------------------------------------------------------------------------
-- Niveau 3 : siège social (bureaux de direction luxueux)
---------------------------------------------------------------------------
local HQ = {}
HQ.MinX, HQ.MaxX, HQ.MinZ, HQ.MaxZ = -1180, -880, -100, 100
HQ.WallHeight = 16

-- Repère d'un meuble posé au sol à (x, z) et tourné vers "facing".
local function facingBase(x, z, facing)
	local origin = Vector3.new(x, FLOOR_TOP, z)
	return CFrame.lookAt(origin, origin + facing)
end

-- Grand comptoir d'accueil en marbre et or, avec 4 bacs à documents. Il regarde vers +Z.
function HQ.ReceptionDesk(parent, cx, cz)
	local model = newModel(parent, "GrandReception")
	local top = FLOOR_TOP + COUNTER_HEIGHT
	block(model, "DeskBody", Vector3.new(16, COUNTER_HEIGHT - 0.3, 3), Vector3.new(cx, FLOOR_TOP + (COUNTER_HEIGHT - 0.3) / 2, cz), COLORS.Walnut, "Wood")
	local counterTop = block(model, "DeskTop", Vector3.new(16.6, 0.3, 3.5), Vector3.new(cx, top - 0.15, cz), COLORS.Marble, "Marble", { Reflectance = 0.1 })
	block(model, "GoldBand", Vector3.new(16.1, 0.3, 0.1), Vector3.new(cx, FLOOR_TOP + 2.6, cz + 1.53), COLORS.Gold, "Foil", { CanCollide = false })
	block(model, "GoldBase", Vector3.new(16.1, 0.3, 0.1), Vector3.new(cx, FLOOR_TOP + 0.15, cz + 1.53), COLORS.Gold, "Foil", { CanCollide = false })
	newSign(model, "DeskLogo", "APEX HOLDINGS", Vector3.new(6, 1, 0.05), Vector3.new(cx, FLOOR_TOP + 1.5, cz + 1.53), Vector3.new(0, 0, 1), COLORS.Walnut, COLORS.Gold)
	for _, offset in { -3, 3 } do
		block(model, "MonitorStand", Vector3.new(0.4, 0.5, 0.3), Vector3.new(cx + offset, top + 0.25, cz - 0.8), COLORS.Black, "SmoothPlastic")
		block(model, "Monitor", Vector3.new(2.2, 1.3, 0.1), Vector3.new(cx + offset, top + 1.15, cz - 0.8), COLORS.Black, "SmoothPlastic")
		createOfficeChair(model, Vector3.new(cx + offset, FLOOR_TOP, cz - 3.2), math.pi)
	end
	local orchid = block(model, "Orchid", Vector3.new(0.8, 0.8, 0.8), Vector3.new(cx, top + 0.5, cz), Color3.fromRGB(240, 150, 220), "SmoothPlastic", { CanCollide = false })
	orchid.Shape = Enum.PartType.Ball
	local spots = makeZone(model, "Paper", counterTop, 3.2)
	for _, offset in { -6.5, -4.6, 4.6, 6.5 } do
		createTray(model, spots, Vector3.new(cx + offset, top, cz))
	end
end

-- Vitrine à trophées : 4 étagères de 7 trophées derrière une vitre.
function HQ.TrophyCabinet(parent, index, x, z, facing)
	local model = newModel(parent, "TrophyCabinet" .. index)
	local base = facingBase(x, z, facing)
	local function at(px, py, pz)
		return base * CFrame.new(px, py, pz)
	end
	local height = 8.6
	local back = newPart(model, "BackPanel", Vector3.new(6.4, height, 0.2), at(0, height / 2, 0.7), COLORS.Walnut, "Wood")
	for _, side in { -1, 1 } do
		newPart(model, "SidePanel", Vector3.new(0.2, height, 1.6), at(side * 3.1, height / 2, 0), COLORS.Walnut, "Wood")
	end
	newPart(model, "Plinth", Vector3.new(6.4, 0.6, 1.6), at(0, 0.3, 0), COLORS.Walnut, "Wood")
	newPart(model, "Crown", Vector3.new(6.8, 0.4, 1.9), at(0, height + 0.2, 0), COLORS.Gold, "Foil")
	local shelves = { 0.6, 2.5, 4.4, 6.3 }
	for _, y in shelves do
		newPart(model, "GlassShelf", Vector3.new(6, 0.1, 1.3), at(0, y - 0.05, 0.05), COLORS.Glass, "Glass", { Transparency = 0.4 })
	end
	newPart(model, "FrontGlass", Vector3.new(6, height - 0.8, 0.08), at(0, height / 2 + 0.2, -0.76), COLORS.Glass, "Glass", { Transparency = 0.75, CastShadow = false })
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 8
	light.Brightness = lampPower(0.5)
	light.Color = Color3.fromRGB(255, 236, 200)
	light.Parent = newPart(model, "CabinetLight", Vector3.new(5.6, 0.1, 0.3), at(0, height - 0.2, 0), COLORS.Light, "Neon", { CanCollide = false })
	local spots = makeZone(model, "Trophy", back, 5.5)
	for _, y in shelves do
		for i = 0, 6 do
			createSlot(spots, "Trophy", at(-2.55 + i * 0.85, y + REST_HEIGHTS.Trophy, 0.05) * CFrame.Angles(0, math.pi, 0))
		end
	end
end

-- Étagère murale à cadres : 4 tablettes de 5 cadres.
function HQ.FrameShelf(parent, index, x, z, facing)
	local model = newModel(parent, "FrameShelf" .. index)
	local base = facingBase(x, z, facing)
	local function at(px, py, pz)
		return base * CFrame.new(px, py, pz)
	end
	local back = newPart(model, "BackBoard", Vector3.new(7, 7.6, 0.2), at(0, 4.4, 0.45), Color3.fromRGB(236, 228, 212), "SmoothPlastic", { CanCollide = false })
	newPart(model, "BackTrim", Vector3.new(7.2, 0.25, 0.3), at(0, 8.3, 0.4), COLORS.Gold, "Foil", { CanCollide = false })
	local ledges = { 1.4, 3.1, 4.8, 6.5 }
	for _, y in ledges do
		newPart(model, "Ledge", Vector3.new(7, 0.12, 0.7), at(0, y - 0.06, 0.05), COLORS.Walnut, "Wood")
		newPart(model, "LedgeLip", Vector3.new(7, 0.2, 0.06), at(0, y + 0.04, -0.28), COLORS.Gold, "Foil", { CanCollide = false })
	end
	local spots = makeZone(model, "Frame", back, 5.4)
	for _, y in ledges do
		for i = 0, 4 do
			createSlot(spots, "Frame", at(-2.6 + i * 1.3, y + REST_HEIGHTS.Frame, 0.12) * CFrame.Angles(0, math.pi, 0))
		end
	end
end

-- Étagère à classeurs (archives) avec étiquette de couleur. Le dos est côté -Z.
function HQ.RecordsShelf(parent, index, cx, cz, categoryId)
	local category = TidyConfig.GetCategory("Binder", categoryId)
	local model = newModel(parent, "RecordsShelf" .. index)
	local width, depth, height = 6.4, 1.2, 7.4
	local back = block(model, "BackPanel", Vector3.new(width, height, 0.1), Vector3.new(cx, FLOOR_TOP + height / 2, cz - 0.55), Color3.fromRGB(70, 76, 88), "Metal")
	for _, side in { -1, 1 } do
		block(model, "SidePanel", Vector3.new(0.2, height, depth - 0.1), Vector3.new(cx + side * (width / 2 - 0.1), FLOOR_TOP + height / 2, cz + 0.05), Color3.fromRGB(70, 76, 88), "Metal")
	end
	local levels = { 0.3, 2.1, 3.9, 5.7 }
	for _, y in levels do
		block(model, "Shelf", Vector3.new(width - 0.4, 0.12, depth - 0.1), Vector3.new(cx, FLOOR_TOP + y - 0.06, cz + 0.05), Color3.fromRGB(90, 96, 108), "Metal")
	end
	block(model, "TopShelf", Vector3.new(width - 0.4, 0.12, depth - 0.1), Vector3.new(cx, FLOOR_TOP + height - 0.06, cz + 0.05), Color3.fromRGB(90, 96, 108), "Metal")
	for i = 0, 3 do
		block(model, "ArchiveBox", Vector3.new(1.3, 1.2, 1), Vector3.new(cx - 2.2 + i * 1.45, FLOOR_TOP + levels[4] + 0.6, cz + 0.05), category.Color:Lerp(COLORS.White, 0.5), "Cardboard")
	end
	newSign(model, "CategoryLabel", string.upper(category.Name), Vector3.new(6, 0.6, 0.05), Vector3.new(cx, FLOOR_TOP + height + 0.4, cz + 0.55), Vector3.new(0, 0, 1), category.Color)
	local spots = makeZone(model, "Binder", back, 5.5, categoryId)
	for level = 1, 3 do
		for i = 0, 10 do
			createSlot(spots, "Binder", CFrame.new(cx - 2.6 + i * 0.52, FLOOR_TOP + levels[level] + REST_HEIGHTS.Binder, cz + 0.05), categoryId)
		end
	end
end

-- Fontaine en marbre avec jets d'eau.
function HQ.Fountain(parent, x, z)
	local model = newModel(parent, "Fountain")
	cylinder(model, "Basin", 1.6, 14, Vector3.new(x, FLOOR_TOP + 0.8, z), COLORS.Marble, "Marble")
	cylinder(model, "BasinRim", 0.3, 14.6, Vector3.new(x, FLOOR_TOP + 1.75, z), COLORS.Gold, "Foil")
	local water = cylinder(model, "Water", 0.1, 13, Vector3.new(x, FLOOR_TOP + 1.65, z), Color3.fromRGB(90, 190, 240), "Glass")
	water.Transparency = 0.2
	water.Reflectance = 0.2
	water.CanCollide = false
	cylinder(model, "Column", 3, 1.6, Vector3.new(x, FLOOR_TOP + 3.1, z), COLORS.Marble, "Marble")
	cylinder(model, "Bowl", 0.8, 6, Vector3.new(x, FLOOR_TOP + 4.8, z), COLORS.Marble, "Marble")
	local bowlWater = cylinder(model, "BowlWater", 0.1, 5.4, Vector3.new(x, FLOOR_TOP + 5.25, z), Color3.fromRGB(90, 190, 240), "Glass")
	bowlWater.Transparency = 0.2
	bowlWater.CanCollide = false
	local spout = block(model, "Spout", Vector3.new(0.8, 0.8, 0.8), Vector3.new(x, FLOOR_TOP + 5.7, z), COLORS.Gold, "Foil", { CanCollide = false })
	spout.Shape = Enum.PartType.Ball
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Rate = 40
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.Speed = NumberRange.new(6, 8)
	spray.SpreadAngle = Vector2.new(12, 12)
	spray.Acceleration = Vector3.new(0, -18, 0)
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 236, 255))
	spray.Size = NumberSequence.new(0.25)
	spray.Transparency = NumberSequence.new(0.3)
	spray.LightEmission = 0.4
	spray.Parent = spout
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(120, 200, 255)
	glow.Range = 12
	glow.Brightness = lampPower(0.6)
	glow.Parent = water
	return model
end

-- Plafond à caissons : grille dorée et dalles lumineuses (pièces de prestige).
function HQ.Coffers(parent, room)
	local y = CEILING_BOTTOM - 0.2
	local w, d = room.MaxX - room.MinX, room.MaxZ - room.MinZ
	local cx, cz = (room.MinX + room.MaxX) / 2, (room.MinZ + room.MaxZ) / 2
	for x = room.MinX + 10, room.MaxX - 5, 10 do
		block(parent, "CofferBeam", Vector3.new(0.6, 0.4, d), Vector3.new(x, y, cz), COLORS.Gold, "Foil", { CanCollide = false, CastShadow = false })
	end
	for z = room.MinZ + 10, room.MaxZ - 5, 10 do
		block(parent, "CofferBeam", Vector3.new(w, 0.4, 0.6), Vector3.new(cx, y, z), COLORS.Gold, "Foil", { CanCollide = false, CastShadow = false })
	end
	for x = room.MinX + 5, room.MaxX - 5, 10 do
		for z = room.MinZ + 5, room.MaxZ - 5, 10 do
			block(parent, "CofferLight", Vector3.new(4, 0.1, 4), Vector3.new(x, CEILING_BOTTOM - 0.05, z), COLORS.Light, "Neon", { CanCollide = false, CastShadow = false, Transparency = 0.55 })
		end
	end
end

function HQ.Build(root)
	local savedHeight = WALL_HEIGHT
	WALL_HEIGHT = HQ.WallHeight
	setFloor(1)
	PARTITION_STYLE = { Color = Color3.fromRGB(240, 232, 216), Material = "Plaster", Base = COLORS.Walnut }
	local structure = newFolder(root, "Building")
	local furniture = newFolder(root, "Furniture")
	local minX, maxX, minZ, maxZ = HQ.MinX, HQ.MaxX, HQ.MinZ, HQ.MaxZ
	local cx = (minX + maxX) / 2
	local top = CEILING_BOTTOM

	-- Sols de chaque pièce.
	local floors = {
		HLobby = { Color3.fromRGB(246, 240, 228), "Marble" },
		HAtrium = { Color3.fromRGB(236, 232, 226), "Marble" },
		HOpenOffice = { Color3.fromRGB(226, 190, 140), "WoodPlanks" },
		HCafe = { Color3.fromRGB(238, 214, 180), "CeramicTiles" },
		HTrophy = { Color3.fromRGB(150, 40, 46), "Carpet" },
		HBoard = { Color3.fromRGB(124, 82, 54), "WoodPlanks" },
		HArchive = { Color3.fromRGB(92, 104, 126), "Carpet" },
		HExecutive = { Color3.fromRGB(110, 70, 44), "WoodPlanks" },
		HServer = { Color3.fromRGB(190, 194, 200), "Concrete" },
	}
	local rooms = TidyConfig.GetMapRooms("Headquarters")
	for _, room in rooms do
		local style = floors[room.Id]
		block(structure, room.Id .. "Floor", Vector3.new(room.MaxX - room.MinX, 1, room.MaxZ - room.MinZ), Vector3.new((room.MinX + room.MaxX) / 2, FLOOR_TOP - 0.5, (room.MinZ + room.MaxZ) / 2), style[1], style[2], { Reflectance = if style[2] == "Marble" then 0.08 else 0 })
	end
	-- Incrustations du hall : bordure noire et rosace dorée.
	block(structure, "LobbyInlay", Vector3.new(60, 0.02, 1), Vector3.new(-1030, FLOOR_TOP + 0.01, 30), Color3.fromRGB(40, 40, 46), "Marble", { CanCollide = false })
	local rosette = cylinder(structure, "LobbyRosette", 0.02, 10, Vector3.new(-1030, FLOOR_TOP + 0.01, 80), COLORS.Gold, "Foil")
	rosette.CanCollide = false

	-- Murs extérieurs : façade vitrée au sud (entrée), fenêtres ailleurs.
	local wallTop = top
	block(structure, "NorthWall", Vector3.new(maxX - minX + 2, wallTop, 1), Vector3.new(cx, wallTop / 2, minZ - 0.5), Color3.fromRGB(240, 232, 216), "Plaster")
	for x = minX + 20, maxX - 20, 30 do
		block(structure, "NorthWindow", Vector3.new(12, 7, 0.04), Vector3.new(x, FLOOR_TOP + 9, minZ + 0.03), Color3.fromRGB(170, 214, 240), "Glass", { Reflectance = 0.2, CanCollide = false })
	end
	-- Façade sud : verre et montants dorés, porte d'entrée au milieu du hall.
	local doorX = -1030
	for _, piece in { { minX, doorX - 5 }, { doorX + 5, maxX } } do
		local length = piece[2] - piece[1]
		local mid = (piece[1] + piece[2]) / 2
		block(structure, "SouthBase", Vector3.new(length, 1.5, 1), Vector3.new(mid, FLOOR_TOP + 0.25, maxZ + 0.5), COLORS.Walnut, "Wood")
		block(structure, "SouthGlass", Vector3.new(length, wallTop - FLOOR_TOP - 1, 0.4), Vector3.new(mid, FLOOR_TOP + 1 + (wallTop - FLOOR_TOP - 1) / 2, maxZ + 0.5), COLORS.Glass, "Glass", { Transparency = 0.45 })
		for x = piece[1] + 5, piece[2] - 1, 6 do
			block(structure, "Mullion", Vector3.new(0.4, wallTop - FLOOR_TOP, 0.6), Vector3.new(x, FLOOR_TOP + (wallTop - FLOOR_TOP) / 2, maxZ + 0.5), COLORS.Gold, "Foil", { CanCollide = false })
		end
	end
	block(structure, "EntranceLintel", Vector3.new(10, wallTop - FLOOR_TOP - 9, 1), Vector3.new(doorX, FLOOR_TOP + 9 + (wallTop - FLOOR_TOP - 9) / 2, maxZ + 0.5), COLORS.Walnut, "Wood")
	for _, side in { -1, 1 } do
		block(structure, "EntranceDoor", Vector3.new(4.9, 9, 0.3), Vector3.new(doorX + side * 2.5, FLOOR_TOP + 4.5, maxZ + 0.6), COLORS.Glass, "Glass", { Transparency = 0.6 })
	end
	windowedSideWall(structure, "WestWall", minX - 0.5, { { -90, -70 }, { -60, -44 }, { -30, -10 }, { 30, 50 }, { 64, 90 } }, 1, minZ, maxZ, 0)
	windowedSideWall(structure, "EastWall", maxX + 0.5, { { -90, -70 }, { -60, -44 }, { -30, -10 }, { 30, 50 }, { 64, 90 } }, -1, minZ, maxZ, 0)

	-- Cloisons et portes (les portes des pièces fermées sont vitrées et verrouillées).
	local doors = {}
	local function door(from, to, room)
		local d = { From = from, To = to, Room = room }
		if room then
			table.insert(doors, d)
		end
		return d
	end
	interiorWallAlongZ(structure, -1080, minZ, maxZ, { door(52, 60, "HOpenOffice"), door(-14, -6, "HTrophy"), door(-74, -66, "HExecutive") })
	interiorWallAlongZ(structure, -980, minZ, maxZ, { door(52, 60, "HCafe"), door(-14, -6, "HBoard"), door(-74, -66, "HServer") })
	interiorWallAlongX(structure, 20, minX, maxX, { door(-1134, -1126, "HTrophy"), door(-1042, -1018, nil), door(-934, -926, "HBoard") })
	interiorWallAlongX(structure, -40, minX, maxX, { door(-1134, -1126, "HArchive"), door(-1034, -1026, "HExecutive"), door(-934, -926, "HServer") })
	for _, d in doors do
		createLockedDoor(structure, d)
	end
	local signY = FLOOR_TOP + DOOR_HEIGHT + 1.6
	for _, sign in {
		{ "OPEN OFFICE", Vector3.new(-1080.3, signY, 56), Vector3.new(1, 0, 0) },
		{ "EXECUTIVE CAFÉ", Vector3.new(-979.7, signY, 56), Vector3.new(-1, 0, 0) },
		{ "ATRIUM", Vector3.new(-1030, signY + 2, 20.3), Vector3.new(0, 0, 1) },
		{ "HALL OF FAME", Vector3.new(-1080.3, signY, -10), Vector3.new(1, 0, 0) },
		{ "BOARDROOM", Vector3.new(-979.7, signY, -10), Vector3.new(-1, 0, 0) },
		{ "CEO SUITE", Vector3.new(-1030, signY, -39.7), Vector3.new(0, 0, 1) },
		{ "RECORDS VAULT", Vector3.new(-1130, signY, -39.7), Vector3.new(0, 0, 1) },
		{ "SERVER HUB", Vector3.new(-930, signY, -39.7), Vector3.new(0, 0, 1) },
	} do
		newSign(structure, "RoomSign", sign[1], Vector3.new(8, 1.3, 0.1), sign[2], sign[3], COLORS.Walnut, COLORS.Gold)
	end

	-- Toit avec une grande verrière au-dessus de l'atrium.
	local holes = { { -1066, -994, -28, 8 } }
	slabWithHoles(structure, "Roof", minX - 1, maxX + 1, minZ - 1, maxZ + 1, top, 1, holes, COLORS.Ceiling, "SmoothPlastic")
	skylight(structure, holes[1], top + 1)
	for _, room in rooms do
		if room.Id == "HOpenOffice" or room.Id == "HCafe" or room.Id == "HServer" or room.Id == "HArchive" then
			slatCeiling(structure, room.MinX, room.MaxX, room.MinZ, room.MaxZ, {}, { room })
		elseif room.Id ~= "HAtrium" then
			HQ.Coffers(structure, room)
		end
	end

	local f = {}
	for _, room in rooms do
		f[room.Id] = newFolder(furniture, room.Id)
	end

	-- Grand hall.
	local lobby = f.HLobby
	HQ.ReceptionDesk(lobby, -1030, 60)
	createChairRug(lobby, "LobbySeatingWest", Vector2.new(-1062, 82), Vector2.new(18, 16), { -1068, -1064, -1060, -1056 }, { 76, 80, 84, 88 }, 0, Color3.fromRGB(150, 40, 46), 6)
	createChairRug(lobby, "LobbySeatingEast", Vector2.new(-998, 82), Vector2.new(18, 16), { -1004, -1000, -996, -992 }, { 76, 80, 84, 88 }, 0, Color3.fromRGB(150, 40, 46), 6)
	createCredenza(lobby, 101, -1078.6, 30)
	createCredenza(lobby, 102, -1078.6, 40)
	createCredenza(lobby, 103, -1078.6, 70)
	createCredenza(lobby, 104, -981.4, 30)
	for i, x in { -1070, -1060, -1000, -990 } do
		createPlanter(lobby, 100 + i, x, 96)
	end
	for _, p in { { -1072, 24 }, { -988, 24 }, { -1046, 94 }, { -1014, 94 } } do
		Deco.Palm(lobby, p[1], p[2], 0.9)
	end
	for _, p in { { -1055, 45 }, { -1005, 45 }, { -1062, 82 }, { -998, 82 } } do
		Deco.Chandelier(lobby, p[1], top - 0.4, p[2], 1)
	end
	newSign(lobby, "CompanyLogo", "APEX HOLDINGS", Vector3.new(26, 4, 0.3), Vector3.new(-1061, FLOOR_TOP + 11, 20.45), Vector3.new(0, 0, 1), COLORS.Walnut, COLORS.Gold)
	newSign(lobby, "CompanyMotto", "EXCELLENCE IN EVERY DETAIL", Vector3.new(26, 4, 0.3), Vector3.new(-999, FLOOR_TOP + 11, 20.45), Vector3.new(0, 0, 1), COLORS.Walnut, COLORS.Gold)
	Deco.Wainscot(lobby, Vector3.new(-1079.45, 0, 74), Vector3.new(-1079.45, 0, 99.6), Vector3.new(1, 0, 0), 3.5, COLORS.Walnut)
	Deco.Wainscot(lobby, Vector3.new(-980.55, 0, 99.6), Vector3.new(-980.55, 0, 64), Vector3.new(-1, 0, 0), 3.5, COLORS.Walnut)

	-- Atrium.
	local atrium = f.HAtrium
	HQ.Fountain(atrium, -1030, -10)
	createPlanter(atrium, 111, -1030, -24.5)
	createPlanter(atrium, 112, -1030, 4.5)
	createPlanter(atrium, 113, -1062, -10)
	createPlanter(atrium, 114, -998, -10)
	createCredenza(atrium, 111, -1078.6, -30)
	createCredenza(atrium, 112, -1078.6, -22)
	createCredenza(atrium, 113, -1078.6, 2)
	createCredenza(atrium, 114, -1078.6, 10)
	HQ.FrameShelf(atrium, 1, -980.95, 4, Vector3.new(-1, 0, 0))
	for _, p in { { -1072, 14 }, { -988, 14 }, { -988, -32 } } do
		Deco.Palm(atrium, p[1], p[2], 0.9)
	end
	createBench(atrium, -1048, -30)
	createBench(atrium, -1012, -30)
	Deco.Chandelier(atrium, -1030, top - 0.4, -34, 1)
	Deco.Chandelier(atrium, -1030, top - 0.4, 14, 1)

	-- Bureau paysager.
	local office = f.HOpenOffice
	local index = 100
	for _, z in { 30, 42, 54, 66 } do
		for _, x in { -1168, -1156, -1144, -1132, -1120 } do
			index += 1
			createHotDesk(office, index, x, z)
		end
	end
	createPrinterStation(office, 101, -1104, 26)
	createPrinterStation(office, 102, -1096, 26)
	createPrinterStation(office, 103, -1104, 92)
	createPrinterStation(office, 104, -1096, 92)
	createCredenza(office, 121, -1178.6, 80)
	createCredenza(office, 122, -1178.6, 90)
	for i, x in { -1176, -1169, -1162, -1155 } do
		createCupboard(office, 100 + i, x, 21.2)
	end
	createChairRug(office, "OfficeLounge", Vector2.new(-1095, 60), Vector2.new(22, 28), { -1102, -1098, -1094, -1090 }, { 48, 52, 56, 60, 64, 68 }, 0, COLORS.Rug, 6)
	for _, p in { { -1176, 96 }, { -1120, 96 }, { -1086, 24 } } do
		createPlant(office, p[1], p[2])
	end
	newSign(office, "OfficeScreen", "Q3 TARGETS: TIDY EVERYTHING", Vector3.new(10, 3, 0.2), Vector3.new(-1150, FLOOR_TOP + 7, 99.7), Vector3.new(0, 0, -1), COLORS.Black, Color3.fromRGB(120, 220, 160))

	-- Café.
	local cafe = f.HCafe
	for i, x in { -976, -969, -962, -955, -948, -941, -918 } do
		createCupboard(cafe, 110 + i, x, 21.2)
	end
	createKitchenCounter(cafe, -900, 20.4)
	index = 100
	for _, z in { 40, 54 } do
		for _, x in { -968, -952, -936 } do
			index += 1
			createCafeTable(cafe, index, x, z)
		end
	end
	index = 100
	for _, center in { { -968, 82 }, { -948, 82 }, { -928, 82 }, { -908, 82 }, { -908, 48 } } do
		index += 1
		createSofa(cafe, index, center[1], center[2] - 3.6, math.pi)
		index += 1
		createSofa(cafe, index, center[1], center[2] + 3.6, 0)
		createCoffeeTable(cafe, center[1], center[2])
	end
	for _, p in { { -968, 40 }, { -952, 40 }, { -936, 40 }, { -968, 54 }, { -952, 54 }, { -936, 54 } } do
		Deco.Pendant(cafe, p[1], top - 0.3, p[2], 5, Color3.fromRGB(240, 150, 60), p[1] == -952)
	end

	-- Galerie des trophées.
	local trophy = f.HTrophy
	index = 0
	for _, z in { -31, -24, -17, -10, -3 } do
		index += 1
		HQ.TrophyCabinet(trophy, index, minX + 1.5, z, Vector3.new(1, 0, 0))
	end
	for _, x in { -1160, -1152 } do
		index += 1
		HQ.TrophyCabinet(trophy, index, x, -40 + 1.22, Vector3.new(0, 0, 1))
	end
	index = 10
	for _, z in { -34, -27, 6, 13 } do
		index += 1
		HQ.FrameShelf(trophy, index, -1080.95, z, Vector3.new(-1, 0, 0))
	end
	for _, x in { -1110, -1100 } do
		index += 1
		HQ.FrameShelf(trophy, index, x, -40 + 0.95, Vector3.new(0, 0, 1))
	end
	block(trophy, "RedRunner", Vector3.new(50, 0.04, 5), Vector3.new(-1130, FLOOR_TOP + 0.02, -10), Color3.fromRGB(196, 40, 46), "Fabric", { CanCollide = false })
	for _, x in { -1150, -1130, -1110 } do
		local pedestal = newModel(trophy, "Pedestal")
		cylinder(pedestal, "Column", 3, 1.6, Vector3.new(x, FLOOR_TOP + 1.5, 6), COLORS.Marble, "Marble")
		local cup = block(pedestal, "BigCup", Vector3.new(1.4, 1.4, 1.4), Vector3.new(x, FLOOR_TOP + 3.9, 6), COLORS.Gold, "Foil", { CanCollide = false })
		cup.Shape = Enum.PartType.Ball
		cup.Reflectance = 0.3
	end
	Deco.Chandelier(trophy, -1130, top - 0.4, -25, 1)
	Deco.Chandelier(trophy, -1130, top - 0.4, 5, 1)

	-- Salle du conseil.
	local board = f.HBoard
	index = 100
	for _, center in { { -955, -25 }, { -912, -25 }, { -955, 2 }, { -912, 2 } } do
		index += 1
		createConferenceTable(board, index, center[1], center[2])
	end
	index = 130
	for _, z in { -34, -26, -18, -10, -2, 6, 14 } do
		index += 1
		createCredenza(board, index, -881.4, z)
	end
	for _, z in { -34, -26, 2, 10 } do
		index += 1
		createCredenza(board, index, -978.6, z)
	end
	index = 100
	for _, x in { -970, -962, -954, -918, -910 } do
		index += 1
		createLaptopCart(board, index, x, -38.6)
	end
	newSign(board, "BoardScreen", "ANNUAL RESULTS: +250%", Vector3.new(12, 4, 0.2), Vector3.new(-955, FLOOR_TOP + 9, 19.65), Vector3.new(0, 0, -1), COLORS.Black, Color3.fromRGB(120, 200, 255))
	Deco.Chandelier(board, -955, top - 0.4, -12, 1)
	Deco.Chandelier(board, -912, top - 0.4, -12, 1)

	-- Salle des archives.
	local archive = f.HArchive
	local binderCats = { "Finance", "Legal", "HR", "Marketing" }
	for i, x in { -1174, -1166, -1158, -1150, -1142, -1134, -1126, -1118 } do
		HQ.RecordsShelf(archive, i, x, -99.3, binderCats[(i - 1) % 4 + 1])
	end
	for i, x in { -1172, -1164, -1156, -1148, -1140, -1132, -1124 } do
		createArchiveShelf(archive, 100 + i, x, -75)
	end
	local vault = newModel(archive, "VaultDoor")
	local vaultDoor = newPart(vault, "Door", Vector3.new(0.6, 9, 9), CFrame.new(-1080.6, FLOOR_TOP + 5, -88), Color3.fromRGB(150, 156, 166), "DiamondPlate", { CanCollide = false })
	vaultDoor.Shape = Enum.PartType.Cylinder
	block(vault, "Wheel", Vector3.new(0.4, 2.4, 0.3), Vector3.new(-1081, FLOOR_TOP + 5, -88), COLORS.Gold, "Foil", { CanCollide = false })
	block(vault, "Wheel", Vector3.new(0.4, 0.3, 2.4), Vector3.new(-1081, FLOOR_TOP + 5, -88), COLORS.Gold, "Foil", { CanCollide = false })
	createFilingCabinet(archive, -1108, -99.9)
	createFilingCabinet(archive, -1105.9, -99.9)

	-- Suite du PDG.
	local exec = f.HExecutive
	for i, x in { -1072, -1064, -1056, -1004, -996, -988 } do
		createArchiveShelf(exec, 120 + i, x, -98.9)
	end
	for i, z in { -94, -86, -56, -48 } do
		HQ.FrameShelf(exec, 20 + i, -1079.05, z, Vector3.new(1, 0, 0))
	end
	index = 200
	for _, gx in { -1060, -1030, -1000 } do
		index += 1
		createSofa(exec, index, gx, -58 - 3.6, math.pi)
		index += 1
		createSofa(exec, index, gx, -58 + 3.6, 0)
		createCoffeeTable(exec, gx, -58)
	end
	createPlanter(exec, 121, -1040, -98.6)
	createPlanter(exec, 122, -1020, -98.6)
	local ceoDesk = newModel(exec, "CEODesk")
	buildDesk(ceoDesk, -1030, -82)
	createOfficeChair(ceoDesk, Vector3.new(-1030, FLOOR_TOP, -84.4), math.pi)
	block(exec, "CEORug", Vector3.new(16, 0.04, 12), Vector3.new(-1030, FLOOR_TOP + 0.02, -80), Color3.fromRGB(170, 40, 46), "Fabric", { CanCollide = false })
	Deco.Chandelier(exec, -1030, top - 0.4, -80, 1.1)
	Deco.Chandelier(exec, -1030, top - 0.4, -56, 0.9)
	Deco.Wainscot(exec, Vector3.new(-1052, 0, -99.6), Vector3.new(-1008, 0, -99.6), Vector3.new(0, 0, 1), 3.5, COLORS.Walnut)

	-- Salle des serveurs.
	local server = f.HServer
	index = 200
	for _, z in { -92, -62 } do
		for _, x in { -968, -960, -952, -944, -936, -928 } do
			index += 1
			createLaptopCart(server, index, x, z)
		end
	end
	for i = 0, 9 do
		createServerRack(server, -883, -96 + i * 3.2)
	end
	index = 200
	for _, x in { -970, -962, -954, -946, -916, -908, -900 } do
		index += 1
		createStorageShelf(server, index, x, -50)
	end
	createFireExtinguisher(server, Vector3.new(-979.7, FLOOR_TOP + 1.2, -50), Vector3.new(1, 0, 0))

	-- Endroit laissé libre : arrivée du joueur.
	addObstacle(doorX - 6, doorX + 6, 86, maxZ)
	WALL_HEIGHT = savedHeight
	setFloor(1)
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

---------------------------------------------------------------------------
-- Hall d'accueil (lobby intérieur) : verrière, néons, colonnes, palmiers,
-- 6 files d'attente pour partir à plusieurs, boutique avec assistant et vitrines.
---------------------------------------------------------------------------
local Hub = {}
Hub.Center = Vector3.new(0, 1, 690)
Hub.MinX, Hub.MaxX, Hub.MinZ, Hub.MaxZ = -70, 70, 620, 760
Hub.PadColors = {
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(120, 230, 120),
	Color3.fromRGB(255, 190, 60),
	Color3.fromRGB(170, 120, 255),
	Color3.fromRGB(255, 100, 90),
}

-- Coin triangulaire (pignon de la verrière). highToward = direction où le coin est le plus haut.
local function wedge(parent, name, size, center, highToward, color, material)
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = CFrame.lookAt(center, center - highToward)
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	setMaterial(part, material)
	part.Parent = parent
	return part
end

-- Personnage de l'assistant derrière le comptoir de la boutique (fait de pièces).
function Hub.Assistant(parent, x, z)
	local model = newModel(parent, "ShopAssistant")
	local skin = Color3.fromRGB(240, 196, 160)
	local shirt = Color3.fromRGB(40, 170, 190)
	for _, side in { -1, 1 } do
		block(model, "Leg", Vector3.new(0.9, 2.2, 0.9), Vector3.new(x + side * 0.5, FLOOR_TOP + 1.1, z), Color3.fromRGB(50, 56, 80), "SmoothPlastic")
		block(model, "Arm", Vector3.new(0.8, 2.1, 0.8), Vector3.new(x + side * 1.45, FLOOR_TOP + 3.25, z), shirt, "SmoothPlastic")
		block(model, "Hand", Vector3.new(0.7, 0.6, 0.7), Vector3.new(x + side * 1.45, FLOOR_TOP + 1.95, z), skin, "SmoothPlastic")
		block(model, "Eye", Vector3.new(0.2, 0.25, 0.05), Vector3.new(x + side * 0.28, FLOOR_TOP + 5.15, z + 0.63), COLORS.Black, "SmoothPlastic", { CanCollide = false })
	end
	block(model, "Torso", Vector3.new(2.1, 2.2, 1.1), Vector3.new(x, FLOOR_TOP + 3.3, z), shirt, "SmoothPlastic")
	block(model, "NameTag", Vector3.new(0.7, 0.3, 0.05), Vector3.new(x + 0.5, FLOOR_TOP + 3.9, z + 0.57), COLORS.White, "SmoothPlastic", { CanCollide = false })
	block(model, "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(x, FLOOR_TOP + 5, z), skin, "SmoothPlastic")
	block(model, "Smile", Vector3.new(0.5, 0.08, 0.05), Vector3.new(x, FLOOR_TOP + 4.75, z + 0.63), Color3.fromRGB(150, 60, 60), "SmoothPlastic", { CanCollide = false })
	block(model, "Hair", Vector3.new(1.3, 0.4, 1.3), Vector3.new(x, FLOOR_TOP + 5.75, z - 0.05), Color3.fromRGB(90, 56, 30), "SmoothPlastic", { CanCollide = false })
	block(model, "Cap", Vector3.new(1.35, 0.3, 1.35), Vector3.new(x, FLOOR_TOP + 6.05, z), Color3.fromRGB(240, 130, 40), "SmoothPlastic", { CanCollide = false })
	block(model, "CapVisor", Vector3.new(1.2, 0.12, 0.7), Vector3.new(x, FLOOR_TOP + 5.95, z + 0.9), Color3.fromRGB(240, 130, 40), "SmoothPlastic", { CanCollide = false })
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "AssistantLabel"
	billboard.Size = UDim2.fromScale(8, 1.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 7.6, 0)
	billboard.Adornee = model:FindFirstChild("Head")
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Parent = model
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.Text = "ASSISTANT"
	label.TextColor3 = Color3.fromRGB(255, 214, 90)
	label.TextStrokeColor3 = Color3.fromRGB(90, 50, 10)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = billboard
	return model
end

-- Petite icône 3D d'un pass (dans la vitrine).
function Hub.PassIcon(parent, passId, center)
	local model = newModel(parent, "Icon_" .. passId)
	local gold, red = COLORS.Gold, Color3.fromRGB(220, 50, 50)
	if passId == "Carry5" or passId == "Carry15" then
		local basket = cylinder(model, "Basket", 1, 1.8, center - Vector3.new(0, 0.3, 0), if passId == "Carry5" then Color3.fromRGB(80, 170, 240) else red, "SmoothPlastic")
		basket.CanCollide = false
		block(model, "Handle", Vector3.new(1.6, 0.15, 0.15), center + Vector3.new(0, 0.6, 0), COLORS.DarkMetal, "Metal", { CanCollide = false })
		for _, side in { -1, 1 } do
			block(model, "HandleSide", Vector3.new(0.15, 0.9, 0.15), center + Vector3.new(side * 0.75, 0.2, 0), COLORS.DarkMetal, "Metal", { CanCollide = false })
		end
		block(model, "Goods", Vector3.new(0.6, 0.5, 0.6), center + Vector3.new(0.2, 0.2, 0), Color3.fromRGB(250, 200, 60), "SmoothPlastic", { CanCollide = false })
	elseif passId == "MaxSpeed" then
		newPart(model, "Bolt", Vector3.new(0.4, 1.4, 0.3), CFrame.new(center + Vector3.new(0.15, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(255, 220, 40), "Neon", { CanCollide = false })
		newPart(model, "Bolt", Vector3.new(0.4, 1.4, 0.3), CFrame.new(center + Vector3.new(-0.15, -0.45, 0)) * CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(255, 220, 40), "Neon", { CanCollide = false })
	elseif passId == "InfiniteMagnet" then
		block(model, "MagnetBase", Vector3.new(1.6, 0.4, 0.4), center - Vector3.new(0, 0.5, 0), red, "SmoothPlastic", { CanCollide = false })
		for _, side in { -1, 1 } do
			block(model, "MagnetArm", Vector3.new(0.4, 1.1, 0.4), center + Vector3.new(side * 0.6, 0.15, 0), red, "SmoothPlastic", { CanCollide = false })
			block(model, "MagnetTip", Vector3.new(0.42, 0.3, 0.42), center + Vector3.new(side * 0.6, 0.85, 0), COLORS.Metal, "Metal", { CanCollide = false })
		end
	elseif passId == "DoublePoints" then
		for i = 0, 3 do
			local coin = cylinder(model, "Coin", 0.2, 1.2, center + Vector3.new(0, -0.6 + i * 0.22, 0), gold, "Foil")
			coin.CanCollide = false
		end
		local coin = newPart(model, "Coin", Vector3.new(0.2, 1.2, 1.2), CFrame.new(center + Vector3.new(0.5, 0.4, 0)) * CFrame.Angles(0, math.rad(90), 0), gold, "Foil", { CanCollide = false })
		coin.Shape = Enum.PartType.Cylinder
	else
		local ring = cylinder(model, "CrownRing", 0.6, 1.6, center - Vector3.new(0, 0.3, 0), gold, "Foil")
		ring.CanCollide = false
		for k = 0, 4 do
			local angle = math.rad(k * 72)
			block(model, "CrownSpike", Vector3.new(0.25, 0.6, 0.25), center + Vector3.new(math.cos(angle) * 0.65, 0.25, math.sin(angle) * 0.65), gold, "Foil", { CanCollide = false })
			local gem = block(model, "Gem", Vector3.new(0.2, 0.2, 0.2), center + Vector3.new(math.cos(angle) * 0.65, 0.6, math.sin(angle) * 0.65), Color3.fromRGB(230, 40, 80), "Neon", { CanCollide = false })
			gem.Shape = Enum.PartType.Ball
		end
	end
	return model
end

-- Vitrine d'un pass : socle, cage de verre, icône, panneau avec nom et prix.
function Hub.DisplayStand(parent, pass, x, z)
	local model = newModel(parent, "PassStand_" .. pass.Id)
	local pedestal = block(model, "Pedestal", Vector3.new(3, 3.4, 3), Vector3.new(x, FLOOR_TOP + 1.7, z), COLORS.White, "SmoothPlastic")
	block(model, "PedestalTrim", Vector3.new(3.2, 0.3, 3.2), Vector3.new(x, FLOOR_TOP + 3.45, z), COLORS.Gold, "Foil", { CanCollide = false })
	block(model, "Case", Vector3.new(2.6, 2.8, 2.6), Vector3.new(x, FLOOR_TOP + 5, z), COLORS.Glass, "Glass", { Transparency = 0.7, CastShadow = false })
	block(model, "CaseTop", Vector3.new(2.8, 0.2, 2.8), Vector3.new(x, FLOOR_TOP + 6.5, z), COLORS.Gold, "Foil", { CanCollide = false })
	Hub.PassIcon(model, pass.Id, Vector3.new(x, FLOOR_TOP + 5, z))
	local light = Instance.new("PointLight")
	light.Range = 7
	light.Brightness = lampPower(0.6)
	light.Color = Color3.fromRGB(255, 230, 180)
	light.Parent = pedestal
	local sign = newSign(model, "PriceSign", pass.Icon .. " " .. pass.Name .. "\nR$ " .. pass.Price, Vector3.new(2.8, 1.8, 0.1), Vector3.new(x, FLOOR_TOP + 2, z + 1.56), Vector3.new(0, 0, 1), Color3.fromRGB(30, 34, 50), Color3.fromRGB(255, 214, 90))
	sign:FindFirstChild("SignGuiFront").Text.Font = Enum.Font.FredokaOne
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "View"
	prompt.ObjectText = pass.Name .. " - R$ " .. pass.Price
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("PassId", pass.Id)
	prompt.Parent = pedestal
	return model
end

-- File d'attente : plateforme lumineuse, arche avec écran, panneau d'état au-dessus.
function Hub.QueuePad(parent, index, x, z, wallSide)
	local color = Hub.PadColors[index]
	local model = newModel(parent, "QueuePad" .. index)
	local platform = cylinder(model, "Platform", 0.6, 12, Vector3.new(x, FLOOR_TOP + 0.3, z), Color3.fromRGB(40, 44, 60), "SmoothPlastic")
	local ring = cylinder(model, "GlowRing", 0.25, 12.8, Vector3.new(x, FLOOR_TOP + 0.125, z), color, "Neon")
	ring.CanCollide = false
	local pad = cylinder(model, "Pad", 0.08, 10, Vector3.new(x, FLOOR_TOP + 0.64, z), color, "Neon")
	pad.Transparency = 0.35
	pad.CanCollide = false
	pad:SetAttribute("QueueIndex", index)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 12
	glow.Brightness = lampPower(0.7)
	glow.Parent = pad
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	sparkles.Speed = NumberRange.new(1.5, 3)
	sparkles.SpreadAngle = Vector2.new(40, 40)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Color = ColorSequence.new(color)
	sparkles.Size = NumberSequence.new(0.3)
	sparkles.LightEmission = 0.8
	sparkles.Parent = pad

	-- Arche contre le mur avec un écran "QUEUE n".
	local archX = x + wallSide * 7.5
	for _, side in { -1, 1 } do
		block(model, "ArchPost", Vector3.new(1, 12, 1), Vector3.new(archX, FLOOR_TOP + 6, z + side * 6), Color3.fromRGB(40, 44, 60), "Metal")
		block(model, "ArchGlow", Vector3.new(0.3, 11.6, 0.3), Vector3.new(archX - wallSide * 0.6, FLOOR_TOP + 6, z + side * 6), color, "Neon", { CanCollide = false })
	end
	block(model, "ArchTop", Vector3.new(1, 1.2, 13), Vector3.new(archX, FLOOR_TOP + 12.6, z), Color3.fromRGB(40, 44, 60), "Metal")
	local screen = newSign(model, "QueueScreen", "QUEUE " .. index, Vector3.new(10, 3, 0.2), Vector3.new(archX - wallSide * 0.4, FLOOR_TOP + 9.5, z), Vector3.new(-wallSide, 0, 0), Color3.fromRGB(20, 24, 36), color)
	screen:FindFirstChild("SignGuiFront").Text.Font = Enum.Font.LuckiestGuy

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "QueueBillboard"
	billboard.Adornee = pad
	billboard.Size = UDim2.fromScale(9, 3.4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	billboard.MaxDistance = 120
	billboard.LightInfluence = 0
	billboard.Parent = model
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.55)
	title.Font = Enum.Font.LuckiestGuy
	title.Text = "EMPTY"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeColor3 = color:Lerp(Color3.new(0, 0, 0), 0.5)
	title.TextStrokeTransparency = 0
	title.TextScaled = true
	title.Parent = billboard
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0, 0.55)
	status.Size = UDim2.fromScale(1, 0.45)
	status.Font = Enum.Font.FredokaOne
	status.Text = "Step on to play"
	status.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5)
	status.TextStrokeTransparency = 0.3
	status.TextScaled = true
	status.Parent = billboard
	return { Index = index, Pad = pad, Center = Vector3.new(x, FLOOR_TOP, z), Radius = 5.5, Title = title, Status = status }
end

function Hub.Build(root)
	setFloor(1)
	local minX, maxX, minZ, maxZ = Hub.MinX, Hub.MaxX, Hub.MinZ, Hub.MaxZ
	local cx, cz = 0, (minZ + maxZ) / 2
	local width, depth = maxX - minX, maxZ - minZ
	local wallTop = 24.5
	local ridgeY = 40
	local structure = newFolder(root, "HallStructure")
	local decor = newFolder(root, "HallDecor")

	-- Sol en marbre clair, rosace bleue au centre, tapis vers la boutique.
	block(structure, "HallFloor", Vector3.new(width, 1, depth), Vector3.new(cx, FLOOR_TOP - 0.5, cz), Color3.fromRGB(240, 240, 246), "Marble", { Reflectance = 0.12 })
	local inlay = cylinder(structure, "FloorInlay", 0.02, 26, Vector3.new(cx, FLOOR_TOP + 0.01, cz), Color3.fromRGB(60, 110, 200), "Marble")
	inlay.CanCollide = false
	local inlayInner = cylinder(structure, "FloorInlayInner", 0.03, 22, Vector3.new(cx, FLOOR_TOP + 0.015, cz), Color3.fromRGB(240, 240, 246), "Marble")
	inlayInner.CanCollide = false
	block(structure, "RunnerSouth", Vector3.new(8, 0.04, 44), Vector3.new(cx, FLOOR_TOP + 0.02, 734), Color3.fromRGB(50, 70, 150), "Fabric", { CanCollide = false })
	block(structure, "RunnerNorth", Vector3.new(8, 0.04, 26), Vector3.new(cx, FLOOR_TOP + 0.02, 657), Color3.fromRGB(50, 70, 150), "Fabric", { CanCollide = false })

	-- Murs : soubassement bleu nuit avec néon cyan, partie haute claire, néon rose en haut.
	local function wall(name, size, position)
		block(structure, name .. "Low", Vector3.new(size.X, 4 + FLOOR_TOP, size.Z), Vector3.new(position.X, (4 + FLOOR_TOP) / 2, position.Z), Color3.fromRGB(36, 44, 80), "SmoothPlastic")
		block(structure, name .. "High", Vector3.new(size.X, wallTop - 4 - FLOOR_TOP, size.Z), Vector3.new(position.X, 4 + FLOOR_TOP + (wallTop - 4 - FLOOR_TOP) / 2, position.Z), Color3.fromRGB(236, 240, 250), "Plaster")
	end
	wall("NorthWall", Vector3.new(width + 2, 0, 1), Vector3.new(cx, 0, minZ - 0.5))
	wall("WestWall", Vector3.new(1, 0, depth), Vector3.new(minX - 0.5, 0, cz))
	wall("EastWall", Vector3.new(1, 0, depth), Vector3.new(maxX + 0.5, 0, cz))
	for _, piece in { { minX - 1, -6 }, { 6, maxX + 1 } } do
		local length = piece[2] - piece[1]
		wall("SouthWall", Vector3.new(length, 0, 1), Vector3.new((piece[1] + piece[2]) / 2, 0, maxZ + 0.5))
	end
	block(structure, "EntranceLintel", Vector3.new(12, wallTop - FLOOR_TOP - 10, 1), Vector3.new(0, FLOOR_TOP + 10 + (wallTop - FLOOR_TOP - 10) / 2, maxZ + 0.5), Color3.fromRGB(236, 240, 250), "Plaster")
	for _, side in { -1, 1 } do
		block(structure, "EntranceDoor", Vector3.new(5.9, 10, 0.3), Vector3.new(side * 3, FLOOR_TOP + 5, maxZ + 0.6), COLORS.Glass, "Glass", { Transparency = 0.5 })
	end
	local neonCyan = Color3.fromRGB(80, 230, 255)
	local neonPink = Color3.fromRGB(255, 90, 200)
	for _, line in {
		{ Vector3.new(width, 0.3, 0.2), Vector3.new(cx, FLOOR_TOP + 4.2, minZ + 0.1) },
		{ Vector3.new(0.2, 0.3, depth), Vector3.new(minX + 0.1, FLOOR_TOP + 4.2, cz) },
		{ Vector3.new(0.2, 0.3, depth), Vector3.new(maxX - 0.1, FLOOR_TOP + 4.2, cz) },
		{ Vector3.new(width, 0.4, 0.2), Vector3.new(cx, wallTop - 0.4, minZ + 0.1) },
		{ Vector3.new(0.2, 0.4, depth), Vector3.new(minX + 0.1, wallTop - 0.4, cz) },
		{ Vector3.new(0.2, 0.4, depth), Vector3.new(maxX - 0.1, wallTop - 0.4, cz) },
	} do
		block(structure, "NeonTrim", line[1], line[2], if line[2].Y > 10 then neonPink else neonCyan, "Neon", { CanCollide = false, CastShadow = false })
	end

	-- Verrière en voûte : deux pans de verre, nervures blanches, pignons.
	local rise = ridgeY - wallTop
	local run = width / 2
	local slopeLength = math.sqrt(rise * rise + run * run)
	local angle = math.atan2(rise, run)
	for _, side in { -1, 1 } do
		local center = Vector3.new(side * run / 2, (wallTop + ridgeY) / 2, cz)
		newPart(structure, "RoofGlass", Vector3.new(slopeLength, 0.4, depth + 2), CFrame.new(center) * CFrame.Angles(0, 0, -side * angle), Color3.fromRGB(190, 230, 255), "Glass", { Transparency = 0.6, CastShadow = false })
		for z = minZ, maxZ, 10 do
			newPart(structure, "RoofRib", Vector3.new(slopeLength, 0.9, 0.6), CFrame.new(Vector3.new(center.X, center.Y - 0.6, z)) * CFrame.Angles(0, 0, -side * angle), COLORS.White, "SmoothPlastic", { CanCollide = false, CastShadow = false })
		end
		for _, endZ in { minZ - 0.5, maxZ + 0.5 } do
			wedge(structure, "Gable", Vector3.new(1, rise, run), Vector3.new(side * run / 2, wallTop + rise / 2, endZ), Vector3.new(-side, 0, 0), Color3.fromRGB(236, 240, 250), "Plaster")
		end
	end
	block(structure, "RidgeBeam", Vector3.new(1.2, 1.2, depth + 2), Vector3.new(0, ridgeY - 0.4, cz), COLORS.White, "SmoothPlastic", { CanCollide = false })
	block(structure, "RidgeNeon", Vector3.new(0.4, 0.3, depth), Vector3.new(0, ridgeY - 1.1, cz), neonPink, "Neon", { CanCollide = false, CastShadow = false })

	-- Suspensions sous la verrière.
	for _, x in { -30, 30 } do
		local hangY = wallTop + (run - math.abs(x)) * rise / run - 0.8
		for z = minZ + 15, maxZ - 10, 20 do
			Deco.Pendant(decor, x, hangY, z, hangY - 18, Color3.fromRGB(250, 250, 250), true)
		end
	end

	-- Colonnes de marbre à bagues dorées.
	for _, x in { -46, 46 } do
		for _, z in { 640, 672, 708, 740 } do
			local column = newModel(decor, "Column")
			cylinder(column, "Shaft", wallTop - FLOOR_TOP, 3, Vector3.new(x, FLOOR_TOP + (wallTop - FLOOR_TOP) / 2, z), COLORS.Marble, "Marble")
			for _, y in { FLOOR_TOP + 0.4, FLOOR_TOP + 4.2, wallTop - 0.6 } do
				local ringPart = cylinder(column, "GoldRing", 0.6, 3.6, Vector3.new(x, y, z), COLORS.Gold, "Foil")
				ringPart.CanCollide = false
			end
		end
	end

	-- Fontaine au centre, palmiers, bancs.
	HQ.Fountain(decor, 0, cz)
	for _, p in { { -64, 628 }, { 64, 628 }, { -64, 752 }, { 64, 752 }, { -16, cz }, { 16, cz }, { -34, 706 }, { 34, 706 } } do
		Deco.Palm(decor, p[1], p[2], 1)
	end
	for _, p in { { -20, 716 }, { 20, 716 }, { -20, 664 }, { 20, 664 } } do
		createBench(decor, p[1], p[2])
	end

	-- Boutique : comptoir, assistant, étagères colorées et grande enseigne.
	local shop = newModel(decor, "ShopCounter")
	local counter = block(shop, "Counter", Vector3.new(30, 4, 3), Vector3.new(0, FLOOR_TOP + 2, 633), Color3.fromRGB(250, 250, 250), "SmoothPlastic")
	block(shop, "CounterTop", Vector3.new(30.6, 0.3, 3.6), Vector3.new(0, FLOOR_TOP + 4.15, 633), COLORS.Gold, "Foil")
	block(shop, "CounterStripe", Vector3.new(30.1, 0.5, 0.1), Vector3.new(0, FLOOR_TOP + 2.5, 634.55), neonPink, "Neon", { CanCollide = false })
	local cash = block(shop, "CashRegister", Vector3.new(2, 1, 1.4), Vector3.new(-8, FLOOR_TOP + 4.8, 633), COLORS.DarkMetal, "Metal", { CanCollide = false })
	cash.CanCollide = false
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "ShopPrompt"
	shopPrompt.ActionText = "Open Shop"
	shopPrompt.ObjectText = "Shop"
	shopPrompt.HoldDuration = 0
	shopPrompt.MaxActivationDistance = 12
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = counter
	Hub.Assistant(shop, 4, 628.5)
	for i = 0, 3 do
		local shelfX = -24 + i * 16
		block(shop, "BackShelf", Vector3.new(12, 0.3, 2), Vector3.new(shelfX, FLOOR_TOP + 4, 621.2), COLORS.Wood, "Wood")
		block(shop, "BackShelf", Vector3.new(12, 0.3, 2), Vector3.new(shelfX, FLOOR_TOP + 7, 621.2), COLORS.Wood, "Wood")
		for k = 0, 4 do
			for _, y in { 4.15, 7.15 } do
				block(shop, "Goods", Vector3.new(1.4, 1.6, 1.2), Vector3.new(shelfX - 4.5 + k * 2.25, FLOOR_TOP + y + 0.8, 621.2), BRIGHT_COLORS[(i * 5 + k + (y > 5 and 3 or 0)) % #BRIGHT_COLORS + 1], "SmoothPlastic", { CanCollide = false })
			end
		end
	end
	local shopSign = newSign(shop, "ShopSign", "SHOP", Vector3.new(16, 4.5, 0.4), Vector3.new(0, FLOOR_TOP + 11.5, minZ + 0.3), Vector3.new(0, 0, 1), Color3.fromRGB(255, 90, 170), COLORS.White)
	shopSign:FindFirstChild("SignGuiFront").Text.Font = Enum.Font.LuckiestGuy
	shopSign.Material = Enum.Material.Neon
	local title = newSign(shop, "GameTitle", string.upper(TidyConfig.GameTitle), Vector3.new(60, 5, 0.4), Vector3.new(0, FLOOR_TOP + 18.5, minZ + 0.3), Vector3.new(0, 0, 1), Color3.fromRGB(36, 44, 80), Color3.fromRGB(255, 214, 90))
	title:FindFirstChild("SignGuiFront").Text.Font = Enum.Font.LuckiestGuy

	-- Vitrines des pass devant la boutique.
	for i, pass in TidyConfig.GamePasses do
		Hub.DisplayStand(decor, pass, -25 + (i - 1) * 10, 646)
	end

	-- Files d'attente le long des murs est et ouest.
	local pads = {}
	local index = 0
	for _, side in { -1, 1 } do
		for _, z in { 655, 690, 725 } do
			index += 1
			table.insert(pads, Hub.QueuePad(decor, index, side * 59, z, side))
		end
	end

	-- Classement, rangs et borne "rejoindre un ami".
	local leaderboard = createBoard(decor, "LeaderboardBoard", Vector3.new(-30, FLOOR_TOP + 9, 754), Vector3.new(0, 0, -1), "TOP TIDIERS", 10, Color3.fromRGB(36, 44, 80))
	local ranksBoard = createBoard(decor, "RanksBoard", Vector3.new(30, FLOOR_TOP + 9, 754), Vector3.new(0, 0, -1), "RANKS", #TidyConfig.Ranks, Color3.fromRGB(36, 44, 80))
	for i, rank in TidyConfig.Ranks do
		local line = ranksBoard:FindFirstChild("Line" .. i)
		if line then
			line.Text = rank.Name .. "  -  " .. TidyConfig.FormatNumber(rank.Items) .. " items"
		end
	end
	local kiosk = newModel(decor, "JoinKiosk")
	block(kiosk, "KioskBase", Vector3.new(3, 1, 2), Vector3.new(14, FLOOR_TOP + 0.5, 744), Color3.fromRGB(36, 44, 80), "SmoothPlastic")
	local kioskBody = block(kiosk, "KioskBody", Vector3.new(2.4, 5, 1.4), Vector3.new(14, FLOOR_TOP + 3.5, 744), Color3.fromRGB(250, 250, 250), "SmoothPlastic")
	block(kiosk, "KioskScreen", Vector3.new(2, 2.4, 0.1), Vector3.new(14, FLOOR_TOP + 4.4, 744.75), Color3.fromRGB(80, 200, 255), "Neon", { CanCollide = false })
	newSign(kiosk, "KioskSign", "JOIN A FRIEND", Vector3.new(4, 1, 0.1), Vector3.new(14, FLOOR_TOP + 6.7, 744.75), Vector3.new(0, 0, 1), Color3.fromRGB(255, 90, 170), COLORS.White)
	local kioskPrompt = Instance.new("ProximityPrompt")
	kioskPrompt.Name = "JoinPrompt"
	kioskPrompt.ActionText = "Enter a code"
	kioskPrompt.ObjectText = "Join a friend"
	kioskPrompt.HoldDuration = 0
	kioskPrompt.MaxActivationDistance = 10
	kioskPrompt.RequiresLineOfSight = false
	kioskPrompt.Parent = kioskBody

	local spawn = createSpawn(root, "HubSpawn", Vector3.new(0, FLOOR_TOP, 750))
	return spawn, pads, leaderboard
end

---------------------------------------------------------------------------
-- Fonctions principales
---------------------------------------------------------------------------
local itemsFolder = nil
local currentItems = {}
local currentMap = nil

-- Limites de chaque niveau (pour lâcher les objets à l'intérieur).
local MAP_BOUNDS = {
	Agency = { -HALF_X, HALF_X, MIN_Z, MAX_Z },
	Warehouse = { WH.MinX, WH.MaxX, WH.MinZ, WH.MaxZ },
	Headquarters = { HQ.MinX, HQ.MaxX, HQ.MinZ, HQ.MaxZ },
}

-- Supprime le point d'apparition du modèle Baseplate (les joueurs apparaissent dans le hall).
function AgencyBuilder.ClearTemplate()
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

-- Construit un niveau (bâtiment, mobilier, zones). Remplace le niveau précédent s'il y en a un.
function AgencyBuilder.Build(mapId)
	mapId = mapId or "Agency"
	local map = TidyConfig.GetMap(mapId)
	assert(map, "Unknown map: " .. tostring(mapId))
	local old = Workspace:FindFirstChild("TidyLevel")
	if old then
		old:Destroy()
	end
	table.clear(obstacles)
	table.clear(allSlots)
	table.clear(allZones)
	table.clear(allDoors)
	table.clear(currentItems)

	setupLighting()
	local root = Instance.new("Model")
	root.Name = "TidyLevel"
	root:SetAttribute("Map", mapId)
	itemsFolder = newFolder(root, "MisplacedItems")

	collectObstacles = true
	if mapId == "Agency" then
		buildAgency(root)
	elseif mapId == "Warehouse" then
		WH.Build(root)
	else
		HQ.Build(root)
	end
	collectObstacles = false
	setFloor(GROUND_TOP)

	local spawn = createSpawn(root, "LevelSpawn", map.Spawn)
	root.Parent = Workspace
	currentMap = mapId
	return {
		Root = root,
		Map = mapId,
		Zones = table.clone(allZones),
		Slots = table.clone(allSlots),
		Doors = table.clone(allDoors),
		Spawn = spawn,
	}
end

-- Éparpille de nouveaux objets dans chaque pièce du niveau. Supprime ceux de la partie précédente.
-- Renvoie la liste des objets créés.
function AgencyBuilder.ScatterItems(seed)
	for _, item in currentItems do
		item:Destroy()
	end
	table.clear(currentItems)
	for _, slot in allSlots do
		slot:SetAttribute("Occupied", false)
	end
	if not currentMap then
		return {}
	end

	local rng = Random.new(seed)
	local counters = {}
	local obstacleGrids = {}
	local placedGrids = {}
	for _, room in TidyConfig.GetMapRooms(currentMap) do
		local floorTop = if room.Map == "Agency" then TidyConfig.FloorHeights[room.Floor or 1] else 1
		setFloor(floorTop)
		local grid = obstacleGrids[floorTop]
		if not grid then
			grid = buildObstacleGrid(floorTop)
			obstacleGrids[floorTop] = grid
		end
		local placedGrid = placedGrids[floorTop]
		if not placedGrid then
			placedGrid = {}
			placedGrids[floorTop] = placedGrid
		end
		for _, itemType in TidyConfig.TypeOrder do
			local count = room.Items[itemType] or 0
			for _ = 1, count do
				counters[itemType] = (counters[itemType] or 0) + 1
				local index = counters[itemType]
				local tippedInfo = TIPPED[itemType]
				local tipped = tippedInfo ~= nil and (tippedInfo.Always or rng:NextNumber() < 0.45)
				local categories = TidyConfig.Categories[itemType]
				local categoryId = categories and categories[(index - 1) % #categories + 1].Id or nil
				local radius = if tipped then tippedInfo.Radius else ITEM_RADIUS[itemType]
				local found = false
				local x, z = 0, 0
				for _ = 1, 400 do
					x = rng:NextNumber(room.MinX + radius + 1, room.MaxX - radius - 1)
					z = rng:NextNumber(room.MinZ + radius + 1, room.MaxZ - radius - 1)
					if not overlapsObstacle(grid, x, z, radius) and not overlapsItems(placedGrid, x, z, radius) then
						found = true
						break
					end
				end
				if found then
					gridInsert(placedGrid, x - radius, x + radius, z - radius, z + radius, { x, z, radius })
					local base = CFrame.new(x, FLOOR_TOP, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					local home
					if tipped and tippedInfo.Axis == "X" then
						home = base * CFrame.new(0, tippedInfo.Height, 0) * CFrame.Angles(math.rad(-90), 0, 0)
					elseif tipped then
						home = base * CFrame.new(0, tippedInfo.Height, 0) * CFrame.Angles(0, 0, math.rad(90))
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

-- Construit le hall d'accueil. Renvoie { Spawn, Pads, Leaderboard, Root }.
function AgencyBuilder.BuildHub()
	local old = Workspace:FindFirstChild("TidyHub")
	if old then
		old:Destroy()
	end
	setupLighting()
	local root = Instance.new("Model")
	root.Name = "TidyHub"
	local wasCollecting = collectObstacles
	collectObstacles = false
	local spawn, pads, leaderboard = Hub.Build(root)
	collectObstacles = wasCollecting
	setFloor(GROUND_TOP)
	root.Parent = Workspace
	return { Spawn = spawn, Pads = pads, Leaderboard = leaderboard, Root = root }
end

function AgencyBuilder.GetItemsFolder()
	return itemsFolder
end

function AgencyBuilder.GetCurrentMap()
	return currentMap
end

-- Limites (minX, maxX, minZ, maxZ) d'un niveau.
function AgencyBuilder.GetBounds(mapId)
	local bounds = MAP_BOUNDS[mapId] or MAP_BOUNDS.Agency
	return bounds[1], bounds[2], bounds[3], bounds[4]
end

-- Hauteur d'un objet debout (pour empiler les objets portés).
function AgencyBuilder.GetItemHeight(itemType)
	local info = TidyConfig.ItemTypes[itemType]
	return info and info.Height or 1
end

AgencyBuilder.FloorTop = FLOOR_TOP
return AgencyBuilder
