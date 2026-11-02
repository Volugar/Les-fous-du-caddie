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
	label.Font = Enum.Font.FredokaOne
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

-- Catégories des zones (Cat) : chaque meuble de rangement appartient à UNE catégorie de son type d'objet.
-- Les meubles qui n'en reçoivent pas à la construction sont répartis à la fin (Cat.Assign) :
-- sections voisines pour une même catégorie, assez de places pour chaque catégorie, pièces ouvertes à temps.
local Cat = {}
Cat.Zones = {}

-- Étiquette de couleur posée sur le meuble (nom du rayon). spot = { CFrame, Vector2 taille } ; face avant = -Z du CFrame.
function Cat.Tag(parent, cframe, size, category)
	local part = newPart(parent, "CategoryTag", Vector3.new(size.X, size.Y, 0.05), cframe, category.Color, "SmoothPlastic", { CanCollide = false, CastShadow = false })
	part.CanTouch = false
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TagGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.MaxDistance = 90
	gui.LightInfluence = 0.4
	gui.Parent = part
	local text = string.upper(category.Name)
	local c = category.Color
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = if c.R * 0.3 + c.G * 0.59 + c.B * 0.11 > 0.62 then Color3.fromRGB(34, 36, 46) else Color3.fromRGB(255, 255, 255)
	label.TextSize = math.max(8, math.floor(math.min(size.Y * 40 * 0.72, size.X * 40 * 0.9 / (math.max(4, #text) * 0.58))))
	label.Parent = gui
	return part
end

-- Repères d'étiquettes : sur une face verticale (regarde vers "facing") ou à plat (texte lisible depuis -Z après "yaw").
function Cat.Front(position, facing, width, height)
	return { CFrame.lookAt(position, position + facing), Vector2.new(width, height) }
end
function Cat.Flat(position, yaw, width, height)
	return { CFrame.new(position) * CFrame.Angles(0, yaw or 0, 0) * CFrame.Angles(math.rad(90), 0, 0), Vector2.new(width, height) }
end

-- Direction (le long de Z ou de X) vers le centre de la pièce : pour tourner les étiquettes vers les joueurs.
function Cat.TowardRoom(x, z, alongX)
	local room = TidyConfig.GetRoomAt(Vector3.new(x, FLOOR_TOP + 1, z))
	if not room then
		return if alongX then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
	end
	if alongX then
		return Vector3.new(0, 0, if (room.MinZ + room.MaxZ) / 2 >= z then 1 else -1)
	end
	return Vector3.new(if (room.MinX + room.MaxX) / 2 >= x then 1 else -1, 0, 0)
end

-- Termine une zone dont la catégorie est connue : attributs, places, étiquettes, bacs colorés et panneau flottant.
function Cat.Finish(model, categoryId)
	local z = Cat.Zones[model]
	local itemType = z.Type
	local category = categoryId and TidyConfig.GetCategory(itemType, categoryId)
	local info = TidyConfig.ItemTypes[itemType]
	model:SetAttribute("ZoneLabel", info.PlaceName .. (if category then " - " .. category.Name else ""))
	if category then
		model:SetAttribute("Category", category.Id)
		for _, slot in z.Spots:GetChildren() do
			slot:SetAttribute("Category", category.Id)
		end
		for _, spot in z.Labels or {} do
			Cat.Tag(model, spot[1], spot[2], category)
		end
		for _, d in model:GetDescendants() do
			if d.Name == "DocumentTray" and d:IsA("BasePart") then
				d.Color = category.Color
			end
		end
	end
	z.Done = true

	-- Panneau du meuble : petite pastille bleu nuit de taille fixe à l'écran (ne grossit plus de près),
	-- icône de couleur, nom, barre de progression. L'écran du joueur n'affiche que le plus proche
	-- de chaque groupe de meubles identiques, et le met en vert quand on porte le bon objet.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CategoryBillboard"
	billboard.Adornee = z.Anchor
	billboard.Size = UDim2.fromOffset(210, 46)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, z.Height, 0)
	billboard.MaxDistance = 70
	billboard.LightInfluence = 0
	billboard.Enabled = false
	billboard.Parent = model

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(28, 30, 70)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.7
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = panel

	local iconBack = Instance.new("Frame")
	iconBack.Name = "IconBack"
	iconBack.Position = UDim2.fromOffset(5, 5)
	iconBack.Size = UDim2.fromOffset(36, 36)
	iconBack.BackgroundColor3 = if category then category.Color else Color3.fromRGB(72, 154, 255)
	iconBack.BorderSizePixel = 0
	iconBack.Parent = panel
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = iconBack
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(5, 5)
	icon.Size = UDim2.fromOffset(26, 26)
	icon.TextSize = 22
	icon.Text = info.Icon
	icon.Parent = iconBack

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(48, 5)
	label.Size = UDim2.new(1, -110, 0, 20)
	label.Font = Enum.Font.FredokaOne
	label.Text = if category then category.Name else info.PlaceName
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = panel
	local count = Instance.new("TextLabel")
	count.Name = "Count"
	count.BackgroundTransparency = 1
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -14, 0, 5)
	count.Size = UDim2.fromOffset(60, 20)
	count.Font = Enum.Font.FredokaOne
	count.Text = "0/0"
	count.TextColor3 = Color3.fromRGB(184, 188, 228)
	count.TextSize = 14
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.Parent = panel
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(48, 29)
	bar.Size = UDim2.new(1, -62, 0, 8)
	bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bar.BackgroundTransparency = 0.82
	bar.BorderSizePixel = 0
	bar.Parent = panel
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(62, 214, 112)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
end

-- Unlock effectif d'une pièce (une pièce qui en "Requires" une autre s'ouvre au plus tôt avec elle).
function Cat.RoomUnlock(room)
	local unlock, guard = 0, 0
	while room and guard < 10 do
		unlock = math.max(unlock, room.Unlock or 0)
		room = room.Requires and TidyConfig.GetRoom(room.Requires)
		guard += 1
	end
	return unlock
end

-- Objets de chaque catégorie sur un niveau : demand[type][indexCatégorie] = liste des unlocks de leurs pièces.
-- (Même règle que ScatterItems : numéro par type sur tout le niveau, catégories à tour de rôle.)
function Cat.Demand(mapId)
	local demand, counters = {}, {}
	for _, room in TidyConfig.GetMapRooms(mapId) do
		local unlock = Cat.RoomUnlock(room)
		for _, itemType in TidyConfig.TypeOrder do
			local categories = TidyConfig.Categories[itemType]
			for _ = 1, room.Items[itemType] or 0 do
				counters[itemType] = (counters[itemType] or 0) + 1
				if categories then
					local c = (counters[itemType] - 1) % #categories + 1
					demand[itemType] = demand[itemType] or {}
					demand[itemType][c] = demand[itemType][c] or {}
					table.insert(demand[itemType][c], unlock)
				end
			end
		end
	end
	return demand
end

-- Répartit les catégories sur les meubles qui n'en ont pas encore, pièce par pièce (dans l'ordre d'ouverture) :
-- d'abord ce qu'il faut pour les objets déjà accessibles, puis le reste au prorata ; meubles voisins = même catégorie.
function Cat.Assign(mapId)
	local demand = Cat.Demand(mapId)
	local roomOrder = {}
	for i, room in TidyConfig.GetMapRooms(mapId) do
		roomOrder[room.Id] = i
	end
	local byType, typeList = {}, {}
	for _, model in allZones do
		local z = Cat.Zones[model]
		local categories = z and TidyConfig.Categories[z.Type]
		if categories then
			if not byType[z.Type] then
				byType[z.Type] = {}
				table.insert(typeList, z.Type)
			end
			z.Model = model
			z.Slots = #z.Spots:GetChildren()
			z.Unlock = if z.Room then Cat.RoomUnlock(z.Room) else 0
			z.Order = if z.Room then roomOrder[z.Room.Id] or 999 else 999
			z.Index = nil
			for i, category in categories do
				if category.Id == z.Fixed then
					z.Index = i
				end
			end
			table.insert(byType[z.Type], z)
		end
	end
	for _, itemType in typeList do
		local zones = byType[itemType]
		local categories = TidyConfig.Categories[itemType]
		local k = #categories
		local need = demand[itemType] or {}
		local function demandAt(c, unlock)
			local n = 0
			for _, u in need[c] or {} do
				if u <= unlock then
					n += 1
				end
			end
			return n
		end
		local total, cap = {}, {}
		for c = 1, k do
			total[c] = #(need[c] or {})
			cap[c] = 0
		end
		local groups, groupOf = {}, {}
		for _, z in zones do
			local key = if z.Room then z.Room.Id else "?"
			local g = groupOf[key]
			if not g then
				g = { Unlock = z.Unlock, Order = z.Order, Zones = {} }
				groupOf[key] = g
				table.insert(groups, g)
			end
			table.insert(g.Zones, z)
		end
		table.sort(groups, function(a, b)
			if a.Unlock ~= b.Unlock then
				return a.Unlock < b.Unlock
			end
			return a.Order < b.Order
		end)
		for _, g in groups do
			local auto, size = {}, 0
			for _, z in g.Zones do
				if z.Index then
					cap[z.Index] += z.Slots
				else
					table.insert(auto, z)
					size += z.Slots
				end
			end
			if #auto > 0 then
				-- Ordre de lecture en serpentin (rangées le long de X) : les meubles voisins se suivent.
				table.sort(auto, function(a, b)
					local pa, pb = a.Anchor.Position, b.Anchor.Position
					local ra, rb = math.floor(pa.Z / 5 + 0.5), math.floor(pb.Z / 5 + 0.5)
					if ra ~= rb then
						return ra < rb
					end
					if ra % 2 == 0 then
						return pa.X < pb.X
					end
					return pa.X > pb.X
				end)
				local now, sumNow = {}, 0
				for c = 1, k do
					now[c] = math.max(0, demandAt(c, g.Unlock) - cap[c])
					sumNow += now[c]
				end
				local target = {}
				if sumNow >= size then
					for c = 1, k do
						target[c] = size * now[c] / sumNow
					end
				else
					local rest, fin, sumFin = size - sumNow, {}, 0
					for c = 1, k do
						fin[c] = math.max(0, total[c] - cap[c] - now[c])
						sumFin += fin[c]
					end
					for c = 1, k do
						target[c] = now[c] + (if sumFin > 0 then rest * fin[c] / sumFin else rest / k)
					end
				end
				local acc, c, cumul = 0, 1, target[1]
				for _, z in auto do
					while c < k and acc + z.Slots / 2 >= cumul do
						c += 1
						cumul += target[c]
					end
					z.Index = c
					cap[c] += z.Slots
					acc += z.Slots
				end
			end
		end
		-- Réparation : une catégorie qui manque de places en prend à une autre qui en a trop (pièces tardives d'abord).
		for _ = 1, 400 do
			local worst, gap = nil, 0
			for c = 1, k do
				if total[c] - cap[c] > gap then
					worst, gap = c, total[c] - cap[c]
				end
			end
			if not worst then
				break
			end
			local best = nil
			for _, z in zones do
				if not z.Fixed and z.Index ~= worst and cap[z.Index] - z.Slots >= total[z.Index] then
					if not best then
						best = z
					else
						local fits, bestFits = z.Slots >= gap, best.Slots >= gap
						if fits ~= bestFits then
							if fits then
								best = z
							end
						elseif z.Unlock ~= best.Unlock then
							if z.Unlock > best.Unlock then
								best = z
							end
						elseif (fits and z.Slots < best.Slots) or (not fits and z.Slots > best.Slots) then
							best = z
						end
					end
				end
			end
			if not best then
				warn("[AgencyBuilder] Not enough " .. itemType .. " slots for category " .. categories[worst].Id .. " on " .. mapId)
				break
			end
			cap[best.Index] -= best.Slots
			best.Index = worst
			cap[worst] += best.Slots
		end
		for _, z in zones do
			if not z.Done then
				Cat.Finish(z.Model, categories[z.Index or 1].Id)
			end
		end
	end
	-- Zones d'un type sans catégories (aucune aujourd'hui) : panneau simple.
	for _, model in allZones do
		local z = Cat.Zones[model]
		if z and not z.Done then
			Cat.Finish(model, nil)
		end
	end
end

-- Transforme un meuble en zone de rangement : on clique dessus pour y ranger.
-- categoryId (facultatif) : catégorie imposée ; sinon Cat.Assign la choisit à la fin de la construction.
-- labels (facultatif) : repères des étiquettes de couleur à poser sur le meuble (voir Cat.Front / Cat.Flat).
local function makeZone(model, itemType, anchorPart, billboardHeight, categoryId, labels)
	local room = TidyConfig.GetRoomAt(anchorPart.Position)
	model:SetAttribute("ItemType", itemType)
	model:SetAttribute("Room", room and room.Id or "")
	CollectionService:AddTag(model, TidyConfig.ZoneTag)
	local spots = newFolder(model, "Spots")
	Cat.Zones[model] = { Type = itemType, Anchor = anchorPart, Height = billboardHeight, Labels = labels, Spots = spots, Room = room, Fixed = categoryId }
	table.insert(allZones, model)
	if categoryId then
		Cat.Finish(model, categoryId)
	end
	return spots
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
	categoryId = categoryId or (spotsFolder.Parent and spotsFolder.Parent:GetAttribute("Category"))
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
-- Fonctions ajoutées, regroupées dans deux tables (limite de 200 variables locales) :
-- AG = aile est de l'agence, murs épais, façades vitrées, plafonds légers ;
-- BD = décors extérieurs vus par les fenêtres (rue, zone industrielle, quartier d'affaires).
---------------------------------------------------------------------------
local AG = {}
local BD = {}
AG.MinX, AG.MaxX = 80, 240 -- aile est de l'agence (rez-de-chaussée) : de X = 80 à X = 240

-- Pièce d'un mur droit. alongX = true : le mur suit X (à Z = fixed) ; sinon il suit Z (à X = fixed).
-- a, b = début et fin le long du mur ; offset = décalage perpendiculaire au mur.
function AG.Piece(parent, name, alongX, fixed, a, b, y1, y2, depth, offset, color, material, options)
	if b - a <= 0.01 or y2 - y1 <= 0.01 then
		return nil
	end
	local mid, h = (a + b) / 2, y2 - y1
	local size = if alongX then Vector3.new(b - a, h, depth) else Vector3.new(depth, h, b - a)
	local position = if alongX then Vector3.new(mid, y1 + h / 2, fixed + offset) else Vector3.new(fixed + offset, y1 + h / 2, mid)
	return block(parent, name, size, position, color, material, options)
end

-- Mur plein épais avec des portes (doors = liste de { From, To, Room }).
-- Si le mur part plus bas que le sol (baseY), un seuil métallique bouche le sol sous chaque porte.
function AG.Wall(parent, name, alongX, fixed, from, to, thickness, doors, baseY, color, material)
	baseY = baseY or FLOOR_TOP
	color = color or COLORS.Wall
	material = material or "Plaster"
	local top = CEILING_BOTTOM
	table.sort(doors, function(a, b)
		return a.From < b.From
	end)
	local cursor = from
	for _, door in doors do
		AG.Piece(parent, name, alongX, fixed, cursor, door.From, baseY, top, thickness, 0, color, material)
		cursor = door.To
	end
	AG.Piece(parent, name, alongX, fixed, cursor, to, baseY, top, thickness, 0, color, material)
	local trim = { CanCollide = false, CastShadow = false }
	for _, door in doors do
		local length = door.To - door.From
		local mid = (door.From + door.To) / 2
		AG.Piece(parent, name .. "Lintel", alongX, fixed, door.From, door.To, FLOOR_TOP + DOOR_HEIGHT, top, thickness, 0, color, material)
		AG.Piece(parent, "Threshold", alongX, fixed, door.From, door.To, baseY, FLOOR_TOP, thickness, 0, COLORS.DarkMetal, "Metal")
		-- Encadrement blanc, visible des deux côtés du mur.
		AG.Piece(parent, "DoorCasing", alongX, fixed, door.From - 0.3, door.From, FLOOR_TOP, FLOOR_TOP + DOOR_HEIGHT, thickness + 0.2, 0, COLORS.Trim, "SmoothPlastic", trim)
		AG.Piece(parent, "DoorCasing", alongX, fixed, door.To, door.To + 0.3, FLOOR_TOP, FLOOR_TOP + DOOR_HEIGHT, thickness + 0.2, 0, COLORS.Trim, "SmoothPlastic", trim)
		AG.Piece(parent, "DoorCasingTop", alongX, fixed, door.From - 0.3, door.To + 0.3, FLOOR_TOP + DOOR_HEIGHT, FLOOR_TOP + DOOR_HEIGHT + 0.3, thickness + 0.2, 0, COLORS.Trim, "SmoothPlastic", trim)
		if alongX then
			addObstacle(door.From - 1, door.To + 1, fixed - 3, fixed + 3)
			door.Center = Vector3.new(mid, FLOOR_TOP + DOOR_HEIGHT / 2, fixed)
			door.Facing = Vector3.new(0, 0, 1)
		else
			addObstacle(fixed - 3, fixed + 3, door.From - 1, door.To + 1)
			door.Center = Vector3.new(fixed, FLOOR_TOP + DOOR_HEIGHT / 2, mid)
			door.Facing = Vector3.new(1, 0, 0)
		end
		door.Size = Vector3.new(length, DOOR_HEIGHT, 0.3)
	end
end

-- Mur extérieur avec des fenêtres (même style que windowedSideWall, dans les deux directions).
-- windows = liste de { début, fin } le long du mur ; insideDirection = côté intérieur (+1 ou -1).
function AG.WindowWall(parent, name, alongX, fixed, from, to, windows, insideDirection, baseY)
	local sillY, windowTop = FLOOR_TOP + 3, FLOOR_TOP + 9
	AG.Piece(parent, name .. "Low", alongX, fixed, from, to, baseY, sillY, 1, 0, COLORS.Wall, "Plaster")
	AG.Piece(parent, name .. "High", alongX, fixed, from, to, windowTop, CEILING_BOTTOM, 1, 0, COLORS.Wall, "Plaster")
	local cursor = from
	for _, window in windows do
		AG.Piece(parent, name .. "Pillar", alongX, fixed, cursor, window[1], sillY, windowTop, 1, 0, COLORS.Wall, "Plaster")
		AG.Piece(parent, name .. "Window", alongX, fixed, window[1], window[2], sillY, windowTop, 0.3, 0, COLORS.Glass, "Glass", { Transparency = 0.5 })
		AG.Piece(parent, name .. "Sill", alongX, fixed, window[1], window[2], sillY, sillY + 0.2, 0.6, insideDirection * 0.8, COLORS.Trim, "SmoothPlastic")
		cursor = window[2]
	end
	AG.Piece(parent, name .. "Pillar", alongX, fixed, cursor, to, sillY, windowTop, 1, 0, COLORS.Wall, "Plaster")
end

-- Façade de verre du sol au plafond (bureaux en haut de la tour) : socle, grande vitre, bandeau et meneaux.
function AG.GlassWall(parent, name, alongX, fixed, from, to, baseY, frameColor, step)
	local glassBottom, glassTop = FLOOR_TOP + 0.5, CEILING_BOTTOM - 1
	AG.Piece(parent, name .. "Base", alongX, fixed, from, to, baseY, glassBottom, 1, 0, frameColor, "Metal")
	AG.Piece(parent, name .. "Glass", alongX, fixed, from, to, glassBottom, glassTop, 0.4, 0, Color3.fromRGB(176, 214, 238), "Glass", { Transparency = 0.62, CastShadow = false })
	AG.Piece(parent, name .. "Head", alongX, fixed, from, to, glassTop, CEILING_BOTTOM, 1, 0, frameColor, "Metal")
	local count = math.max(1, math.floor((to - from) / step))
	for i = 1, count - 1 do
		local p = from + i * (to - from) / count
		AG.Piece(parent, "Mullion", alongX, fixed, p - 0.15, p + 0.15, glassBottom, glassTop, 1.1, 0, frameColor, "Metal", { CanCollide = false, CastShadow = false })
	end
end

-- Bandeaux lumineux (néon) d'une pièce, avec très peu de vraies lumières (performances).
function AG.Strips(parent, minX, maxX, minZ, maxZ, lights)
	local y = CEILING_BOTTOM - 0.4
	local z = minZ + 7.75
	while z <= maxZ - 5 do
		block(parent, "LightStrip", Vector3.new(maxX - minX - 8, 0.15, 0.6), Vector3.new((minX + maxX) / 2, y, z), COLORS.Light, "Neon", { CanCollide = false, CastShadow = false, Transparency = 0.45 })
		z += 12.5
	end
	for i = 1, lights do
		local holder = block(parent, "LightPoint", Vector3.new(0.2, 0.1, 0.2), Vector3.new((minX + maxX) / 2, y - 0.2, minZ + (i - 0.5) * (maxZ - minZ) / lights), COLORS.Light, "SmoothPlastic", { CanCollide = false, CastShadow = false, Transparency = 1 })
		local light = Instance.new("PointLight")
		light.Range = 26
		light.Brightness = lampPower(0.55)
		light.Color = Color3.fromRGB(255, 236, 206)
		light.Shadows = false
		light.Parent = holder
	end
end

-- Dalles lumineuses au plafond (sans lumière réelle), tous les "step" studs.
function AG.Panels(parent, minX, maxX, minZ, maxZ, step, color)
	for x = minX + step / 2, maxX - step / 2 + 0.01, step do
		for z = minZ + step / 2, maxZ - step / 2 + 0.01, step do
			block(parent, "CeilingPanel", Vector3.new(5, 0.1, 5), Vector3.new(x, CEILING_BOTTOM - 0.05, z), color or COLORS.Light, "Neon", { CanCollide = false, CastShadow = false, Transparency = 0.5 })
		end
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
			-- Une lumière tous les 32 studs (portée plus grande) : deux fois moins de lumières, moins de lag.
			local lightX = room.MinX + 12
			while lightX <= room.MaxX - 6 do
				local holder = block(parent, "LightPoint", Vector3.new(0.2, 0.1, 0.2), Vector3.new(lightX, y - 0.4, stripZ), COLORS.Light, "SmoothPlastic", { CanCollide = false, CastShadow = false, Transparency = 1 })
				local light = Instance.new("PointLight")
				light.Range = 20
				light.Brightness = lampPower(0.5)
				light.Color = Color3.fromRGB(255, 236, 206)
				light.Shadows = false
				light.Parent = holder
				lightX += 32
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
	-- Aile est : un grand couloir au milieu, 4 pièces au sud et 4 au nord (après le mur épais X = 80..81).
	local wx = AG.MinX + 1
	floor("EastHallFloor", wx, AG.MaxX, -10, 20, COLORS.Tiles, "CeramicTiles", { Reflectance = 0.05 })
	floor("StaffCafeFloor", wx, 120, 20, 60, COLORS.MintTiles, "CeramicTiles", { Reflectance = 0.04 })
	floor("JobClubFloor", 120, 160, 20, 60, COLORS.GreenCarpet, "Carpet")
	floor("ComputerLabFloor", 160, 200, 20, 60, COLORS.Carpet, "Carpet")
	floor("SupplyRoomFloor", 200, AG.MaxX, 20, 60, COLORS.Concrete, "Concrete")
	floor("RecordsHallFloor", wx, 120, -100, -10, COLORS.WarmCarpet, "Carpet")
	floor("CareerLibraryFloor", 120, 160, -100, -10, COLORS.WoodFloor, "WoodPlanks")
	floor("ParcelDepotFloor", 160, 200, -100, -10, COLORS.Concrete, "Concrete")
	floor("StockroomFloor", 200, AG.MaxX, -100, -10, Color3.fromRGB(196, 194, 188), "Concrete")

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
	-- Murs extérieurs de l'aile est : nord plein, est et sud vitrés (vue sur la rue).
	block(parent, "NorthWallEast", Vector3.new(AG.MaxX - AG.MinX, wallHeight, 1), Vector3.new((wx + AG.MaxX + 1) / 2, wallY, MIN_Z - 0.5), COLORS.Wall, "Plaster")
	AG.WindowWall(parent, "WingEastWall", false, AG.MaxX + 0.5, MIN_Z, MAX_Z, { { -92, -72 }, { -60, -40 }, { -28, -14 }, { -4, 14 }, { 26, 54 } }, -1, 0)
	AG.WindowWall(parent, "WingSouthWall", true, MAX_Z + 0.5, wx, AG.MaxX + 1, { { 86, 114 }, { 126, 154 }, { 166, 194 }, { 206, 234 } }, -1, 0)

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
	-- Ancien mur est : mur plein entre l'agence et l'aile est, avec la porte du couloir.
	AG.Wall(parent, "EastWall", false, HALF_X + 0.5, MIN_Z, MAX_Z, 1, { door(1, 9, "EastHall") }, 0)
	interiorWallAlongX(parent, 20, wx, AG.MaxX, { door(96, 104, "StaffCafe"), door(136, 144, "JobClub"), door(176, 184, "ComputerLab"), door(216, 224, "SupplyRoom") })
	interiorWallAlongX(parent, -10, wx, AG.MaxX, { door(96, 104, "RecordsHall"), door(136, 144, "CareerLibrary"), door(176, 184, "ParcelDepot"), door(216, 224, "Stockroom") })
	for _, x in { 120, 160, 200 } do
		interiorWallAlongZ(parent, x, 20.25, MAX_Z, {})
		interiorWallAlongZ(parent, x, MIN_Z, -10.25, {})
	end
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
		{ "EAST WING", Vector3.new(79.7, signY, 5), Vector3.new(-1, 0, 0) },
		{ "STAFF CAFÉ", Vector3.new(100, signY, 19.7), Vector3.new(0, 0, -1) },
		{ "JOB CLUB", Vector3.new(140, signY, 19.7), Vector3.new(0, 0, -1) },
		{ "COMPUTER LAB", Vector3.new(180, signY, 19.7), Vector3.new(0, 0, -1) },
		{ "SUPPLY ROOM", Vector3.new(220, signY, 19.7), Vector3.new(0, 0, -1) },
		{ "RECORDS HALL", Vector3.new(100, signY, -9.7), Vector3.new(0, 0, 1) },
		{ "CAREER LIBRARY", Vector3.new(140, signY, -9.7), Vector3.new(0, 0, 1) },
		{ "PARCEL DEPOT", Vector3.new(180, signY, -9.7), Vector3.new(0, 0, 1) },
		{ "STOCKROOM", Vector3.new(220, signY, -9.7), Vector3.new(0, 0, 1) },
	}
	for _, sign in roomSigns do
		newSign(parent, "RoomSign", sign[1], Vector3.new(7, 1.2, 0.1), sign[2], sign[3])
	end

	-- Plafond : dalle claire, lattes de bois chaleureuses et bandeaux lumineux.
	block(parent, "Ceiling", Vector3.new(fullLengthX, 1, fullLengthZ), Vector3.new(0, CEILING_BOTTOM + 0.5, MID_Z), COLORS.Ceiling, "SmoothPlastic")
	local groundRooms = {}
	for _, room in TidyConfig.GetMapRooms("Agency") do
		if (room.Floor or 1) == 1 and room.MaxX <= HALF_X then
			table.insert(groundRooms, room)
		end
	end
	slatCeiling(parent, -HALF_X, HALF_X, MIN_Z, MAX_Z, {}, groundRooms)

	-- Plafond de l'aile est : puits de lumière au-dessus du couloir, lattes de bois dans les pièces,
	-- bandeaux lumineux avec seulement 2 vraies lumières par pièce.
	local wingHoles = { { 100, 120, -4, 14 }, { 150, 170, -4, 14 }, { 200, 220, -4, 14 } }
	slabWithHoles(parent, "WingCeiling", wx, AG.MaxX + 1, MIN_Z - 1, MAX_Z + 1, CEILING_BOTTOM, 1, wingHoles, COLORS.Ceiling, "SmoothPlastic")
	for _, hole in wingHoles do
		skylight(parent, hole, CEILING_BOTTOM + 1)
		local cx, cz = (hole[1] + hole[2]) / 2, (hole[3] + hole[4]) / 2
		local sx, sz = hole[2] - hole[1], hole[4] - hole[3]
		for _, side in { -1, 1 } do
			block(parent, "SkylightFrame", Vector3.new(sx + 0.6, 0.4, 0.3), Vector3.new(cx, CEILING_BOTTOM - 0.2, cz + side * (sz / 2 + 0.15)), COLORS.Trim, "SmoothPlastic", { CanCollide = false })
			block(parent, "SkylightFrame", Vector3.new(0.3, 0.4, sz), Vector3.new(cx + side * (sx / 2 + 0.15), CEILING_BOTTOM - 0.2, cz), COLORS.Trim, "SmoothPlastic", { CanCollide = false })
		end
	end
	slatCeiling(parent, wx, AG.MaxX, 20, MAX_Z, {}, {})
	slatCeiling(parent, wx, AG.MaxX, MIN_Z, -10, {}, {})
	for _, room in TidyConfig.GetMapRooms("Agency") do
		if room.MinX >= AG.MinX then
			if room.Id == "EastHall" then
				for _, x1 in { wx, 120, 170, 220 } do
					local x2 = if x1 == wx then 100 elseif x1 == 220 then AG.MaxX else x1 + 30
					AG.Strips(parent, x1, x2, room.MinZ, room.MaxZ, 1)
				end
			else
				AG.Strips(parent, math.max(room.MinX, wx), room.MaxX, room.MinZ, room.MaxZ, 2)
			end
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
	-- Le mur est a maintenant une porte (Z = 1 à 9) : bandeaux coupés de chaque côté, et bandeaux de l'aile est.
	for _, side in { { MIN_Z, 0.7 }, { 9.3, MAX_Z } } do
		local length, mid = side[2] - side[1], (side[1] + side[2]) / 2
		band("EastBand", Vector3.new(0.1, 3, length), Vector3.new(HALF_X - 0.05, bandY, mid), false)
		band("WingWestBand", Vector3.new(0.1, 3, length), Vector3.new(wx + 0.05, bandY, mid), false)
	end
	band("WingNorthBand", Vector3.new(AG.MaxX - wx, 3, 0.1), Vector3.new((wx + AG.MaxX) / 2, bandY, MIN_Z + 0.05), true)
	band("WingSouthBand", Vector3.new(AG.MaxX - wx, 3, 0.1), Vector3.new((wx + AG.MaxX) / 2, bandY, MAX_Z - 0.05), true)
	band("WingEastBand", Vector3.new(0.1, 3, DEPTH_Z), Vector3.new(AG.MaxX - 0.05, bandY, MID_Z), false)
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
	createPrinterStation(parent, 2, 77, 13) -- laisse libre la porte de l'aile est (Z = 1 à 9)
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

-- Impressions des objets (étiquettes, marques, textes) : une surface d'affichage par objet,
-- visible seulement de près pour ne pas alourdir le jeu.
local Print = {}
Print.MaxDistance = 34

function Print.surface(part, face, pixelsPerStud)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Print"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 90
	gui.MaxDistance = Print.MaxDistance
	gui.LightInfluence = 1
	gui.Parent = part
	return gui
end

function Print.box(parent, x, y, w, h, color, cornerScale, transparency)
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.Parent = parent
	if cornerScale then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(cornerScale, 0)
		c.Parent = frame
	end
	return frame
end

function Print.text(parent, text, x, y, w, h, color, font, align)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(w, h)
	label.Text = text
	label.TextColor3 = color
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = align or Enum.TextXAlignment.Center
	label.Parent = parent
	return label
end

-- Code-barres imprimé (traits fins).
function Print.barcode(parent, x, y, w, h)
	local holder = Print.box(parent, x, y, w, h, Color3.fromRGB(255, 255, 255))
	for k = 0, 9 do
		Print.box(holder, 0.05 + k * 0.09, 0.1, if k % 3 == 0 then 0.05 else 0.025, 0.8, Color3.fromRGB(30, 30, 34))
	end
	return holder
end

-- Lignes de texte grisées (document imprimé).
function Print.lines(parent, x, y, w, count, gap, color)
	for k = 0, count - 1 do
		local width = w * (if k % 3 == 2 then 0.6 else 1)
		Print.box(parent, x, y + k * gap, width, gap * 0.45, color or Color3.fromRGB(170, 176, 190), 1)
	end
end

local BRAND_NAMES = {
	ShoeBox = { "RUNFAST", "STRIDE", "TRAILCO", "SOFTSTEP", "KIDDO", "URBANO" },
	Bottle = { "SPARKLE", "CITRUSY", "CRYSTAL", "FLUFFY" },
	Gadget = { "SoundMax", "NovaPhone", "PlayPad", "EchoBox" },
	Box = { "OFFICE SUPPLIES", "PRINTER PAPER", "ARCHIVES", "MOVING BOX" },
}

-- Fabrique les pièces d'un objet autour de l'origine. Renvoie le modèle et sa pièce principale.
-- Chaque objet est fait de pièces soudées, sans pièces superposées (pas de scintillement),
-- sans petits néons, avec des étiquettes imprimées lisibles de près.
local function buildItemParts(itemType, index, categoryId)
	local model = Instance.new("Model")
	model.Name = itemType .. index
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local size = ITEM_SIZES[itemType]
	local main = nil
	local variant = TidyConfig.GetVariantName(itemType, index)

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
	local white = Color3.fromRGB(252, 252, 250)
	local ink = Color3.fromRGB(34, 36, 46)

	if itemType == "Folder" then
		-- Chemise cartonnée : 2 couvertures, feuilles qui dépassent, onglet, étiquette imprimée.
		hiddenMain()
		local color = pick(FOLDER_COLORS)
		d("BackCover", Vector3.new(1.3, 0.03, 1.6), CFrame.new(0, -0.06, 0), color, "SmoothPlastic")
		d("Papers", Vector3.new(1.2, 0.06, 1.5), CFrame.new(0.08, -0.015, 0.03), COLORS.Paper)
		local front = d("FrontCover", Vector3.new(1.3, 0.03, 1.6), CFrame.new(0, 0.03, 0), color:Lerp(white, 0.08), "SmoothPlastic")
		d("Tab", Vector3.new(0.45, 0.03, 0.18), CFrame.new(-0.3, 0.03, -0.89), color, "SmoothPlastic")
		d("Elastic", Vector3.new(1.34, 0.13, 0.05), CFrame.new(0, -0.015, 0.58), Color3.fromRGB(44, 44, 52), "Fabric")
		local gui = Print.surface(front, Enum.NormalId.Top, 80)
		local label = Print.box(gui, 0.18, 0.12, 0.64, 0.3, white, 0.12)
		Print.box(label, 0, 0, 1, 0.3, color:Lerp(Color3.new(0, 0, 0), 0.15), 0.2)
		Print.text(label, string.upper(variant), 0.06, 0.38, 0.88, 0.5, ink)
		Print.text(gui, "CONFIDENTIAL", 0.2, 0.62, 0.6, 0.1, Color3.fromRGB(200, 40, 40), Enum.Font.BuilderSansExtraBold)
	elseif itemType == "Paper" then
		-- Pile de feuilles légèrement décalées, pince noire, première page imprimée.
		hiddenMain()
		local top = nil
		for layer = 0, 3 do
			local angle = ({ -4, 3, -2, 0 })[layer + 1]
			top = d("Sheets", Vector3.new(1.05, 0.05, 1.45), CFrame.new(((layer % 2) - 0.5) * 0.04, -0.1 + layer * 0.062, 0) * CFrame.Angles(0, math.rad(angle), 0), pick(SHEET_COLORS, layer))
		end
		local gui = Print.surface(top, Enum.NormalId.Top, 80)
		Print.box(gui, 0.1, 0.08, 0.5, 0.06, pick(BRIGHT_COLORS), 1)
		Print.lines(gui, 0.1, 0.2, 0.8, 9, 0.07)
		d("Clip", Vector3.new(0.34, 0.08, 0.14), CFrame.new(0, 0.1, -0.67), ink, "SmoothPlastic")
		d("ClipHandle", Vector3.new(0.04, 0.03, 0.26), CFrame.new(-0.1, 0.16, -0.78) * CFrame.Angles(math.rad(25), 0, 0), COLORS.Metal, "Metal")
		d("ClipHandle", Vector3.new(0.04, 0.03, 0.26), CFrame.new(0.1, 0.16, -0.78) * CFrame.Angles(math.rad(25), 0, 0), COLORS.Metal, "Metal")
	elseif itemType == "Chair" then
		-- La pièce principale est l'assise. La chaise regarde vers -Z.
		local chairColor = pick(CHAIR_COLORS)
		local cushion = chairColor:Lerp(white, 0.12)
		solidMain(COLORS.DarkMetal, "SmoothPlastic")
		d("SeatCushion", Vector3.new(1.9, 0.22, 1.9), CFrame.new(0, 0.28, -0.02), cushion, "Fabric")
		d("BackCushion", Vector3.new(1.8, 1.7, 0.24), CFrame.new(0, 1.25, 0.8) * CFrame.Angles(math.rad(-6), 0, 0), cushion, "Fabric")
		d("BackShell", Vector3.new(1.84, 1.6, 0.1), CFrame.new(0, 1.22, 0.96) * CFrame.Angles(math.rad(-6), 0, 0), COLORS.DarkMetal)
		if variant == "Office Chair" or variant == "Meeting Chair" and index % 2 == 0 then
			-- Fauteuil de bureau : vérin, étoile à 5 branches, roulettes.
			vcyl("GasLift", 1.1, 0.22, Vector3.new(0, -0.7, 0), COLORS.Metal, "Metal")
			for k = 0, 4 do
				local angle = math.rad(k * 72)
				local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
				d("StarLeg", Vector3.new(0.14, 0.1, 0.85), CFrame.lookAt(Vector3.new(0, -1.3, 0) + dir * 0.42, Vector3.new(0, -1.3, 0) + dir), COLORS.DarkMetal)
				ball("Caster", 0.2, Vector3.new(0, -1.7, 0) + dir * 0.84, ink)
			end
		else
			-- Chaise visiteur : 4 pieds chromés.
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					d("Leg", Vector3.new(0.12, 1.6, 0.12), CFrame.new(0.82 * sx, -0.975, 0.82 * sz), COLORS.Metal, "Metal")
					d("Foot", Vector3.new(0.16, 0.06, 0.16), CFrame.new(0.82 * sx, -1.77, 0.82 * sz), ink)
				end
			end
		end
		for _, sx in { -1, 1 } do
			d("Armrest", Vector3.new(0.16, 0.12, 1.2), CFrame.new(0.98 * sx, 0.8, 0.1), ink)
			d("ArmPost", Vector3.new(0.1, 0.55, 0.1), CFrame.new(0.98 * sx, 0.47, 0.35), COLORS.Metal, "Metal")
		end
	elseif itemType == "Box" then
		-- Carton : rabats, ruban adhésif, étiquette d'expédition imprimée.
		solidMain(COLORS.Cardboard, "Cardboard")
		local half = size / 2
		d("TopTape", Vector3.new(size.X + 0.02, 0.02, 0.42), CFrame.new(0, half.Y + 0.01, 0), COLORS.Tape)
		d("FrontTape", Vector3.new(0.42, 0.4, 0.02), CFrame.new(0, half.Y - 0.2, -half.Z - 0.01), COLORS.Tape)
		d("BackTape", Vector3.new(0.42, 0.4, 0.02), CFrame.new(0, half.Y - 0.2, half.Z + 0.01), COLORS.Tape)
		local gui = Print.surface(main, Enum.NormalId.Right, 60)
		local labelBox = Print.box(gui, 0.12, 0.22, 0.5, 0.42, white, 0.06)
		Print.text(labelBox, pick(BRAND_NAMES.Box), 0.06, 0.06, 0.88, 0.24, ink)
		Print.lines(labelBox, 0.08, 0.38, 0.6, 3, 0.12, Color3.fromRGB(150, 150, 160))
		Print.barcode(labelBox, 0.08, 0.74, 0.5, 0.2)
		if index % 2 == 0 then
			Print.text(gui, "FRAGILE", 0.66, 0.22, 0.3, 0.16, Color3.fromRGB(210, 40, 36))
			Print.text(gui, "🥂", 0.7, 0.42, 0.22, 0.25, ink)
		else
			Print.text(gui, "⬆⬆", 0.66, 0.24, 0.3, 0.3, ink)
			Print.text(gui, "THIS SIDE UP", 0.64, 0.56, 0.34, 0.1, ink, Enum.Font.BuilderSansExtraBold)
		end
	elseif itemType == "Mug" then
		-- Tasse : corps, bord, anse arrondie, café.
		hiddenMain()
		local mugColor = pick(MUG_COLORS)
		vcyl("Body", 0.52, 0.46, Vector3.new(0, -0.015, 0), mugColor, "SmoothPlastic")
		vcyl("Rim", 0.03, 0.47, Vector3.new(0, 0.26, 0), mugColor:Lerp(white, 0.35))
		if index % 2 == 0 then
			vcyl("Coffee", 0.02, 0.4, Vector3.new(0, 0.22, 0), Color3.fromRGB(96, 60, 36))
		end
		vcyl("Stripe", 0.08, 0.47, Vector3.new(0, 0.12, 0), pick(BRIGHT_COLORS, 2))
		-- Anse en "C" : deux barres arrondies et un montant.
		xcyl("HandleTop", 0.2, 0.08, Vector3.new(0.3, 0.13, 0), mugColor)
		xcyl("HandleBottom", 0.2, 0.08, Vector3.new(0.3, -0.13, 0), mugColor)
		d("HandleSide", Vector3.new(0.08, 0.34, 0.08), CFrame.new(0.39, 0, 0), mugColor)
		ball("HandleCorner", 0.08, Vector3.new(0.39, 0.13, 0), mugColor)
		ball("HandleCorner", 0.08, Vector3.new(0.39, -0.13, 0), mugColor)
	elseif itemType == "Plant" then
		hiddenMain()
		local potColor = pick(POT_COLORS)
		vcyl("Pot", 0.78, 0.82, Vector3.new(0, -0.56, 0), potColor, "SmoothPlastic")
		vcyl("PotRim", 0.12, 0.94, Vector3.new(0, -0.11, 0), potColor:Lerp(Color3.new(0, 0, 0), 0.12))
		vcyl("Soil", 0.04, 0.78, Vector3.new(0, -0.07, 0), Color3.fromRGB(96, 66, 44), "Ground")
		local greens = { Color3.fromRGB(62, 160, 70), Color3.fromRGB(110, 196, 84), Color3.fromRGB(44, 128, 64) }
		local style = index % 3
		if style == 0 then
			ball("Leaves", 0.95, Vector3.new(0, 0.32, 0), greens[1], "Grass")
			ball("Leaves", 0.6, Vector3.new(0.24, 0.66, 0.14), greens[2], "Grass")
			ball("Leaves", 0.55, Vector3.new(-0.24, 0.58, -0.18), greens[3], "Grass")
		elseif style == 1 then
			vcyl("Stem", 0.45, 0.08, Vector3.new(0, 0.15, 0), Color3.fromRGB(80, 120, 60))
			for k = 0, 5 do
				local angle = math.rad(k * 60)
				d("Frond", Vector3.new(0.2, 0.05, 0.85), CFrame.new(0, 0.42, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.1, -0.34) * CFrame.Angles(math.rad(25), 0, 0), greens[(k % 3) + 1], "Grass")
			end
			ball("Heart", 0.34, Vector3.new(0, 0.52, 0), greens[2], "Grass")
		else
			ball("Leaves", 0.8, Vector3.new(0, 0.3, 0), greens[1], "Grass")
			ball("Leaves", 0.48, Vector3.new(0, 0.64, 0), greens[3], "Grass")
			for k = 0, 3 do
				local angle = math.rad(k * 90 + 45)
				ball("Flower", 0.2, Vector3.new(math.cos(angle) * 0.32, 0.62, math.sin(angle) * 0.32), pick(BRIGHT_COLORS, k), "SmoothPlastic")
			end
		end
	elseif itemType == "Book" then
		-- Livre : couvertures de la couleur du rayon, pages, dos avec titre, couverture imprimée.
		hiddenMain()
		local category = TidyConfig.GetCategory("Book", categoryId) or TidyConfig.Categories.Book[1]
		local shade = 0.85 + (index % 3) * 0.08
		local color = Color3.new(math.min(1, category.Color.R * shade), math.min(1, category.Color.G * shade), math.min(1, category.Color.B * shade))
		d("CoverLeft", Vector3.new(0.04, 1.1, 0.8), CFrame.new(-0.13, 0, 0), color)
		local cover = d("CoverRight", Vector3.new(0.04, 1.1, 0.8), CFrame.new(0.13, 0, 0), color)
		local spine = d("Spine", Vector3.new(0.3, 1.1, 0.05), CFrame.new(0, 0, -0.375), color:Lerp(Color3.new(0, 0, 0), 0.1))
		d("Pages", Vector3.new(0.22, 1.04, 0.74), CFrame.new(0, 0, 0.02), Color3.fromRGB(250, 246, 232))
		local gui = Print.surface(cover, Enum.NormalId.Right, 90)
		Print.text(gui, string.upper(variant), 0.1, 0.1, 0.8, 0.14, white)
		Print.box(gui, 0.2, 0.32, 0.6, 0.34, white, 0.1, 0.15)
		Print.text(gui, ({ "📝", "🎤", "🎓", "💼" })[(table.find(TidyConfig.Categories.Book, category) or 1)], 0.3, 0.36, 0.4, 0.26, ink)
		Print.text(gui, category.Name, 0.08, 0.76, 0.84, 0.1, white, Enum.Font.BuilderSansBold)
		local spineGui = Print.surface(spine, Enum.NormalId.Front, 90)
		Print.box(spineGui, 0, 0.08, 1, 0.04, COLORS.Gold)
		Print.box(spineGui, 0, 0.88, 1, 0.04, COLORS.Gold)
		Print.box(spineGui, 0.2, 0.3, 0.6, 0.4, white, 0.2)
	elseif itemType == "Laptop" then
		-- Ordinateur portable fermé : coque, charnière, petit logo discret imprimé (plus de néon).
		hiddenMain()
		local shell = pick({ COLORS.Laptop, Color3.fromRGB(196, 200, 208), Color3.fromRGB(70, 90, 130) })
		d("Base", Vector3.new(1.2, 0.045, 0.9), CFrame.new(0, -0.027, 0), shell:Lerp(Color3.new(0, 0, 0), 0.15), "SmoothPlastic")
		local lid = d("Lid", Vector3.new(1.18, 0.04, 0.88), CFrame.new(0, 0.02, 0.005), shell, "SmoothPlastic", nil, { Reflectance = 0.08 })
		xcyl("Hinge", 1.0, 0.06, Vector3.new(0, -0.005, 0.45), ink)
		local gui = Print.surface(lid, Enum.NormalId.Top, 70)
		local logo = Print.box(gui, 0.43, 0.38, 0.14, 0.2, white, 1, 0.55)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = logo
	elseif itemType == "Cushion" then
		local color = pick(CUSHION_COLORS)
		solidMain(color, "Fabric")
		d("Piping", Vector3.new(1.26, 0.05, 1.26), CFrame.new(), color:Lerp(white, 0.35), "Fabric")
		d("TopPuff", Vector3.new(1.0, 0.08, 1.0), CFrame.new(0, 0.2, 0), color:Lerp(white, 0.08), "Fabric")
		ball("Button", 0.12, Vector3.new(0, 0.25, 0), color:Lerp(Color3.new(0, 0, 0), 0.25), "Fabric")
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				ball("Tassel", 0.14, Vector3.new(sx * 0.63, 0, sz * 0.63), COLORS.Gold, "Fabric")
			end
		end
	elseif itemType == "Parcel" then
		-- Colis : ruban en croix, étiquette d'adresse de la couleur du rayon.
		local category = TidyConfig.GetCategory("Parcel", categoryId) or TidyConfig.Categories.Parcel[1]
		solidMain(COLORS.Cardboard, "Cardboard")
		local half = size / 2
		d("TapeX", Vector3.new(size.X + 0.02, 0.016, 0.18), CFrame.new(0, half.Y + 0.008, 0), COLORS.Tape)
		d("TapeZ", Vector3.new(0.18, 0.02, size.Z + 0.02), CFrame.new(0, half.Y + 0.01, 0), COLORS.Tape)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Right } do
			local gui = Print.surface(main, face, 100)
			local labelBox = Print.box(gui, 0.12, 0.14, 0.76, 0.72, white, 0.06)
			Print.box(labelBox, 0, 0, 1, 0.3, category.Color, 0.1)
			Print.text(labelBox, string.upper(category.Name), 0.05, 0.04, 0.9, 0.22, white)
			Print.lines(labelBox, 0.08, 0.38, 0.7, 2, 0.13)
			Print.barcode(labelBox, 0.08, 0.68, 0.6, 0.24)
		end
	elseif itemType == "ShoeBox" then
		-- Boîte à chaussures : couvercle, marque imprimée, taille sur le côté.
		local bodyColor = pick({ Color3.fromRGB(240, 120, 40), Color3.fromRGB(40, 110, 220), Color3.fromRGB(44, 44, 50), Color3.fromRGB(220, 50, 50), Color3.fromRGB(250, 250, 246), Color3.fromRGB(60, 170, 100) })
		local lidColor = if bodyColor.R + bodyColor.G + bodyColor.B > 2.5 then Color3.fromRGB(230, 60, 60) else Color3.fromRGB(250, 250, 246)
		solidMain(bodyColor, "SmoothPlastic")
		local lid = d("Lid", Vector3.new(1.66, 0.22, 1.06), CFrame.new(0, 0.31, 0), lidColor)
		local brandColor = if lidColor.R + lidColor.G + lidColor.B > 2.5 then bodyColor else white
		local lidGui = Print.surface(lid, Enum.NormalId.Top, 60)
		Print.text(lidGui, pick(BRAND_NAMES.ShoeBox), 0.15, 0.3, 0.7, 0.4, if brandColor == white then ink else brandColor)
		local gui = Print.surface(main, Enum.NormalId.Back, 70)
		Print.text(gui, pick(BRAND_NAMES.ShoeBox), 0.06, 0.2, 0.5, 0.4, lidColor)
		local sizeTag = Print.box(gui, 0.08, 0.66, 0.36, 0.24, white, 0.1)
		Print.text(sizeTag, "SIZE " .. (36 + index % 10), 0.05, 0.1, 0.9, 0.8, ink, Enum.Font.BuilderSansExtraBold)
	elseif itemType == "Toy" then
		hiddenMain()
		local style = (index - 1) % 4
		if style == 0 then
			-- Ours en peluche.
			local fur = pick({ Color3.fromRGB(176, 120, 72), Color3.fromRGB(240, 170, 190), Color3.fromRGB(120, 170, 230), Color3.fromRGB(246, 240, 226) }, math.floor(index / 4))
			local light = fur:Lerp(white, 0.4)
			ball("Body", 0.9, Vector3.new(0, -0.2, 0), fur, "Fabric")
			ball("Belly", 0.5, Vector3.new(0, -0.22, 0.24), light, "Fabric")
			ball("Head", 0.75, Vector3.new(0, 0.38, 0), fur, "Fabric")
			for _, sx in { -1, 1 } do
				ball("Ear", 0.3, Vector3.new(sx * 0.3, 0.7, -0.02), fur, "Fabric")
				ball("InnerEar", 0.16, Vector3.new(sx * 0.3, 0.71, 0.09), light, "Fabric")
				ball("Eye", 0.1, Vector3.new(sx * 0.14, 0.47, 0.33), ink)
				ball("Arm", 0.36, Vector3.new(sx * 0.48, -0.08, 0.1), fur, "Fabric")
				ball("Leg", 0.42, Vector3.new(sx * 0.27, -0.5, 0.22), fur, "Fabric")
				ball("Paw", 0.22, Vector3.new(sx * 0.27, -0.52, 0.43), light, "Fabric")
			end
			ball("Snout", 0.3, Vector3.new(0, 0.32, 0.33), light, "Fabric")
			ball("Nose", 0.12, Vector3.new(0, 0.37, 0.48), ink)
			d("Bow", Vector3.new(0.4, 0.14, 0.1), CFrame.new(0, 0.06, 0.36), Color3.fromRGB(220, 40, 50), "Fabric")
		elseif style == 1 then
			-- Petite voiture (phares peints, plus de néon).
			local paint = pick(BRIGHT_COLORS, math.floor(index / 4))
			d("Body", Vector3.new(1.1, 0.34, 0.6), CFrame.new(0, -0.43, 0), paint, "SmoothPlastic", nil, { Reflectance = 0.12 })
			d("Cabin", Vector3.new(0.6, 0.28, 0.54), CFrame.new(-0.05, -0.12, 0), paint:Lerp(white, 0.1), "SmoothPlastic", nil, { Reflectance = 0.12 })
			d("Windshield", Vector3.new(0.02, 0.2, 0.46), CFrame.new(0.255, -0.12, 0), Color3.fromRGB(150, 200, 240), "Glass", nil, { Transparency = 0.1 })
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local wheel = Vector3.new(sx * 0.36, -0.53, sz * 0.31)
					d("Wheel", Vector3.new(0.12, 0.34, 0.34), CFrame.new(wheel) * CFrame.Angles(0, math.rad(90), 0), ink, "SmoothPlastic", Enum.PartType.Cylinder)
					d("Hubcap", Vector3.new(0.13, 0.16, 0.16), CFrame.new(wheel) * CFrame.Angles(0, math.rad(90), 0), COLORS.Metal, "Metal", Enum.PartType.Cylinder)
				end
				d("Headlight", Vector3.new(0.02, 0.08, 0.12), CFrame.new(0.56, -0.4, sx * 0.18), Color3.fromRGB(255, 244, 196))
			end
		elseif style == 2 then
			-- Ballon de plage.
			local colors = { Color3.fromRGB(232, 60, 56), Color3.fromRGB(250, 210, 40), Color3.fromRGB(46, 120, 226), Color3.fromRGB(60, 180, 96) }
			ball("Ball", 1.04, Vector3.new(0, 0, 0), white)
			for k = 1, 4 do
				d("Stripe", Vector3.new(0.14, 1.06, 1.06), CFrame.Angles(0, math.rad(k * 45), 0), colors[k], "SmoothPlastic", Enum.PartType.Cylinder)
			end
			ball("Cap", 0.2, Vector3.new(0, 0.5, 0), white)
		else
			-- Robot jouet (yeux peints, plus de néon).
			local metal = pick({ Color3.fromRGB(200, 206, 216), Color3.fromRGB(80, 150, 230), Color3.fromRGB(240, 120, 40) }, math.floor(index / 4))
			local torso = d("Torso", Vector3.new(0.6, 0.5, 0.4), CFrame.new(0, -0.15, 0), metal, "SmoothPlastic")
			local head = d("Head", Vector3.new(0.45, 0.35, 0.38), CFrame.new(0, 0.3, 0), metal, "SmoothPlastic")
			for _, sx in { -1, 1 } do
				d("Arm", Vector3.new(0.14, 0.45, 0.14), CFrame.new(sx * 0.38, -0.15, 0), metal:Lerp(Color3.new(0, 0, 0), 0.2))
				d("Leg", Vector3.new(0.18, 0.3, 0.2), CFrame.new(sx * 0.15, -0.55, 0), metal:Lerp(Color3.new(0, 0, 0), 0.3))
			end
			vcyl("Antenna", 0.22, 0.04, Vector3.new(0, 0.58, 0), COLORS.DarkMetal)
			ball("AntennaTip", 0.1, Vector3.new(0, 0.7, 0), Color3.fromRGB(240, 60, 60))
			local face = Print.surface(head, Enum.NormalId.Back, 100)
			Print.box(face, 0.12, 0.15, 0.76, 0.7, Color3.fromRGB(30, 36, 50), 0.2)
			Print.box(face, 0.24, 0.3, 0.16, 0.22, Color3.fromRGB(110, 230, 255), 1)
			Print.box(face, 0.6, 0.3, 0.16, 0.22, Color3.fromRGB(110, 230, 255), 1)
			Print.box(face, 0.35, 0.62, 0.3, 0.07, Color3.fromRGB(110, 230, 255), 1)
			local chest = Print.surface(torso, Enum.NormalId.Back, 100)
			Print.box(chest, 0.25, 0.2, 0.5, 0.45, Color3.fromRGB(250, 210, 60), 0.2)
		end
	elseif itemType == "Bottle" then
		hiddenMain()
		local style = (index - 1) % 4
		local liquid = pick({ Color3.fromRGB(60, 140, 230), Color3.fromRGB(250, 196, 50), Color3.fromRGB(80, 200, 220), Color3.fromRGB(230, 120, 200), Color3.fromRGB(120, 210, 90) }, math.floor(index / 4))
		local brand = pick(BRAND_NAMES.Bottle)
		local labelPart
		if style == 0 or style == 3 then
			-- Bidon de lessive avec poignée.
			d("Jug", Vector3.new(0.72, 1.0, 0.46), CFrame.new(0, -0.18, 0), liquid, "SmoothPlastic")
			d("Shoulder", Vector3.new(0.5, 0.18, 0.42), CFrame.new(-0.08, 0.41, 0), liquid, "SmoothPlastic")
			d("Handle", Vector3.new(0.1, 0.34, 0.2), CFrame.new(0.27, 0.43, 0), liquid, "SmoothPlastic")
			d("HandleTop", Vector3.new(0.3, 0.08, 0.2), CFrame.new(0.15, 0.6, 0), liquid, "SmoothPlastic")
			vcyl("Cap", 0.16, 0.24, Vector3.new(-0.15, 0.58, 0), white)
			labelPart = d("Label", Vector3.new(0.58, 0.56, 0.02), CFrame.new(0, -0.16, 0.24), white)
		elseif style == 1 then
			-- Liquide vaisselle : bouteille haute.
			vcyl("BottleBody", 1.0, 0.42, Vector3.new(0, -0.2, 0), liquid, "SmoothPlastic")
			vcyl("Neck", 0.22, 0.24, Vector3.new(0, 0.41, 0), liquid, "SmoothPlastic")
			vcyl("Cap", 0.16, 0.18, Vector3.new(0, 0.6, 0), Color3.fromRGB(240, 240, 240))
			labelPart = d("Label", Vector3.new(0.3, 0.46, 0.02), CFrame.new(0, -0.2, 0.215), white)
		else
			-- Spray nettoyant.
			d("SprayBody", Vector3.new(0.5, 0.9, 0.36), CFrame.new(0, -0.25, 0), liquid, "SmoothPlastic")
			vcyl("Collar", 0.12, 0.26, Vector3.new(0, 0.26, 0), white)
			d("Trigger", Vector3.new(0.4, 0.2, 0.2), CFrame.new(0.08, 0.42, 0), white)
			d("Nozzle", Vector3.new(0.14, 0.1, 0.12), CFrame.new(0.32, 0.45, 0), Color3.fromRGB(230, 60, 60))
			d("Lever", Vector3.new(0.06, 0.24, 0.1), CFrame.new(0.18, 0.26, 0), white)
			labelPart = d("Label", Vector3.new(0.4, 0.46, 0.02), CFrame.new(0, -0.25, 0.19), white)
		end
		local gui = Print.surface(labelPart, Enum.NormalId.Back, 120)
		Print.box(gui, 0, 0, 1, 0.28, liquid, 0.1)
		Print.text(gui, brand, 0.06, 0.03, 0.88, 0.22, white)
		Print.text(gui, ({ "🫧", "🍋", "✨", "🌸" })[style + 1], 0.25, 0.32, 0.5, 0.36, ink)
		Print.text(gui, string.upper(variant), 0.05, 0.74, 0.9, 0.18, ink, Enum.Font.BuilderSansExtraBold)
	elseif itemType == "Can" then
		-- Conserve : étiquette de couleur, bandeau blanc, couvercle à anneau.
		hiddenMain()
		local labelColor = pick({ Color3.fromRGB(220, 50, 46), Color3.fromRGB(60, 140, 70), Color3.fromRGB(250, 196, 40), Color3.fromRGB(240, 220, 150), Color3.fromRGB(250, 150, 60) })
		vcyl("Tin", 0.65, 0.48, Vector3.new(0, 0, 0), COLORS.Metal, "Metal")
		vcyl("Label", 0.46, 0.495, Vector3.new(0, -0.01, 0), labelColor)
		vcyl("LabelStripe", 0.08, 0.5, Vector3.new(0, 0.11, 0), white)
		vcyl("TopRim", 0.03, 0.5, Vector3.new(0, 0.315, 0), Color3.fromRGB(220, 224, 230), "Metal")
		vcyl("BottomRim", 0.03, 0.5, Vector3.new(0, -0.315, 0), Color3.fromRGB(220, 224, 230), "Metal")
		d("PullTab", Vector3.new(0.12, 0.02, 0.08), CFrame.new(0, 0.335, 0.1), Color3.fromRGB(200, 204, 210), "Metal")
	elseif itemType == "Gadget" then
		-- Boîte de produit électronique : face imprimée avec le produit et la marque.
		local boxColor = pick({ white, Color3.fromRGB(30, 32, 38), white, Color3.fromRGB(220, 50, 60) })
		solidMain(boxColor, "SmoothPlastic")
		local textColor = if boxColor.R + boxColor.G + boxColor.B > 1.5 then ink else white
		local style = (index - 1) % 4
		local gui = Print.surface(main, Enum.NormalId.Back, 90)
		Print.text(gui, pick(BRAND_NAMES.Gadget), 0.08, 0.05, 0.84, 0.12, textColor)
		local picture = Print.box(gui, 0.12, 0.2, 0.76, 0.5, pick(BRIGHT_COLORS, 1), 0.08)
		Print.text(picture, ({ "🎧", "📱", "🎮", "🔊" })[style + 1], 0.15, 0.1, 0.7, 0.8, ink)
		Print.text(gui, string.upper(variant), 0.08, 0.74, 0.84, 0.1, textColor, Enum.Font.BuilderSansExtraBold)
		Print.box(gui, 0, 0.9, 1, 0.1, pick(BRIGHT_COLORS, 4))
		d("SideSticker", Vector3.new(0.02, 0.2, 0.3), CFrame.new(0.51, 0.3, 0), COLORS.Gold, "Foil")
	elseif itemType == "Tape" then
		hiddenMain()
		local style = (index - 1) % 3
		local tapeColor = ({ Color3.fromRGB(226, 176, 110), Color3.fromRGB(230, 60, 50), Color3.fromRGB(240, 226, 186) })[style + 1]
		vcyl("Roll", 0.36, 0.9, Vector3.new(0, 0, 0), tapeColor, "SmoothPlastic")
		vcyl("Core", 0.37, 0.52, Vector3.new(0, 0, 0), Color3.fromRGB(176, 130, 84), "Cardboard")
		vcyl("Hole", 0.38, 0.42, Vector3.new(0, 0, 0), Color3.fromRGB(60, 44, 30))
		if style == 1 then
			vcyl("FragileBand", 0.1, 0.905, Vector3.new(0, 0, 0), white)
		end
	elseif itemType == "Trophy" then
		-- Coupe : socle en marbre, plaque gravée, coupe brillante.
		hiddenMain()
		local metal = pick({ Color3.fromRGB(250, 196, 50), Color3.fromRGB(210, 214, 222), Color3.fromRGB(206, 130, 70), Color3.fromRGB(250, 196, 50) })
		local base = d("Base", Vector3.new(0.7, 0.25, 0.5), CFrame.new(0, -0.575, 0), Color3.fromRGB(34, 34, 40), "Marble")
		d("Step", Vector3.new(0.45, 0.14, 0.32), CFrame.new(0, -0.38, 0), Color3.fromRGB(44, 44, 52), "Marble")
		vcyl("Stem", 0.32, 0.12, Vector3.new(0, -0.15, 0), metal, "Metal")
		ball("Knot", 0.2, Vector3.new(0, -0.02, 0), metal, "Metal")
		ball("Cup", 0.6, Vector3.new(0, 0.28, 0), metal, "Metal")
		vcyl("CupRim", 0.12, 0.64, Vector3.new(0, 0.5, 0), metal, "Metal")
		for _, sx in { -1, 1 } do
			d("HandleOut", Vector3.new(0.06, 0.32, 0.06), CFrame.new(sx * 0.4, 0.3, 0), metal, "Metal")
			d("HandleTop", Vector3.new(0.12, 0.06, 0.06), CFrame.new(sx * 0.35, 0.45, 0), metal, "Metal")
			d("HandleLow", Vector3.new(0.12, 0.06, 0.06), CFrame.new(sx * 0.35, 0.15, 0), metal, "Metal")
		end
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Material == Enum.Material.Metal then
				part.Reflectance = 0.25
			end
		end
		local gui = Print.surface(base, Enum.NormalId.Back, 120)
		local plaque = Print.box(gui, 0.2, 0.2, 0.6, 0.6, COLORS.Gold, 0.15)
		Print.text(plaque, ({ "BEST TEAM", "TOP SELLER", "No.1", "EMPLOYEE OF THE MONTH" })[(index - 1) % 4 + 1], 0.05, 0.1, 0.9, 0.8, ink, Enum.Font.BuilderSansExtraBold)
	elseif itemType == "Frame" then
		-- Cadre photo : baguette, image imprimée (photo d'équipe, paysage, diplôme, portrait), pied.
		hiddenMain()
		local border = pick({ COLORS.Gold, COLORS.Walnut, COLORS.Black, COLORS.White })
		local borderMaterial = if border == COLORS.Gold then "Foil" else "Wood"
		d("BorderTop", Vector3.new(1.2, 0.08, 0.1), CFrame.new(0, 0.435, 0), border, borderMaterial)
		d("BorderBottom", Vector3.new(1.2, 0.08, 0.1), CFrame.new(0, -0.435, 0), border, borderMaterial)
		d("BorderLeft", Vector3.new(0.08, 0.79, 0.1), CFrame.new(-0.56, 0, 0), border, borderMaterial)
		d("BorderRight", Vector3.new(0.08, 0.79, 0.1), CFrame.new(0.56, 0, 0), border, borderMaterial)
		local picture = d("Picture", Vector3.new(1.04, 0.79, 0.04), CFrame.new(0, 0, -0.01), Color3.fromRGB(240, 240, 236))
		d("Back", Vector3.new(1.04, 0.79, 0.02), CFrame.new(0, 0, -0.04), Color3.fromRGB(70, 56, 44))
		d("Stand", Vector3.new(0.12, 0.7, 0.05), CFrame.new(0, -0.15, -0.2) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(70, 56, 44))
		local gui = Print.surface(picture, Enum.NormalId.Back, 120)
		local style = (index - 1) % 4
		if style == 0 then
			Print.box(gui, 0, 0, 1, 1, Color3.fromRGB(160, 214, 250))
			Print.box(gui, 0, 0.62, 1, 0.38, Color3.fromRGB(110, 190, 100))
			Print.text(gui, "🧑‍💼🧑‍💼🧑‍💼", 0.05, 0.3, 0.9, 0.5, ink)
		elseif style == 1 then
			Print.box(gui, 0, 0, 1, 1, Color3.fromRGB(140, 200, 250))
			Print.text(gui, "🏔️", 0.15, 0.15, 0.7, 0.8, ink)
		elseif style == 2 then
			Print.box(gui, 0, 0, 1, 1, Color3.fromRGB(252, 246, 224))
			Print.text(gui, "CERTIFICATE", 0.1, 0.1, 0.8, 0.18, Color3.fromRGB(120, 90, 40))
			Print.lines(gui, 0.2, 0.4, 0.6, 3, 0.1, Color3.fromRGB(170, 150, 120))
			Print.text(gui, "🏅", 0.66, 0.6, 0.26, 0.36, ink)
		else
			Print.box(gui, 0, 0, 1, 1, Color3.fromRGB(110, 120, 140))
			Print.text(gui, "🧑‍💼", 0.2, 0.1, 0.6, 0.85, ink)
		end
	elseif itemType == "Binder" then
		-- Classeur : couvertures de la couleur du service, dos avec étiquette imprimée et trou de doigt.
		hiddenMain()
		local category = TidyConfig.GetCategory("Binder", categoryId) or TidyConfig.Categories.Binder[1]
		d("CoverLeft", Vector3.new(0.04, 1.3, 1.0), CFrame.new(-0.18, 0, 0), category.Color)
		local cover = d("CoverRight", Vector3.new(0.04, 1.3, 1.0), CFrame.new(0.18, 0, 0), category.Color)
		local coverGui = Print.surface(cover, Enum.NormalId.Right, 90)
		Print.box(coverGui, 0, 0.12, 1, 0.16, Color3.fromRGB(255, 255, 255), nil, 0.2)
		Print.text(coverGui, string.upper(category.Name), 0.08, 0.14, 0.84, 0.12, ink, Enum.Font.BuilderSansExtraBold)
		Print.text(coverGui, string.upper(variant), 0.1, 0.4, 0.8, 0.1, white)
		Print.text(coverGui, "2026", 0.3, 0.78, 0.4, 0.1, white, Enum.Font.BuilderSansBold)
		local spine = d("Spine", Vector3.new(0.4, 1.3, 0.05), CFrame.new(0, 0, -0.475), category.Color:Lerp(Color3.new(0, 0, 0), 0.08))
		d("Pages", Vector3.new(0.3, 1.22, 0.9), CFrame.new(0, 0, 0.03), Color3.fromRGB(250, 248, 240))
		local gui = Print.surface(spine, Enum.NormalId.Front, 120)
		local labelBox = Print.box(gui, 0.12, 0.1, 0.76, 0.42, white, 0.1)
		Print.text(labelBox, string.upper(category.Name), 0.08, 0.05, 0.84, 0.9, ink, Enum.Font.BuilderSansExtraBold).TextWrapped = true
		local hole = Print.box(gui, 0.3, 0.68, 0.4, 0.14, Color3.fromRGB(30, 30, 36), 1)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = hole
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
	-- Éclairage ShadowMap (léger) : à l'intérieur, la lumière vient surtout de l'ambiance.
	-- Ambiance claire et neutre pour des pièces lumineuses sans effet "brûlé".
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.2 * LIGHT_LEVEL
	Lighting.ExposureCompensation = -0.05 + (LIGHT_LEVEL - 1) * 0.5
	Lighting.Ambient = Color3.fromRGB(150, 146, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 148, 144)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true

	local colorCorrection = Lighting:FindFirstChild("AgencyColorCorrection")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "AgencyColorCorrection"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Brightness = 0.02
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
	AG.FurnishWing(furniture, newFolder(root, "WingDecor"))

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
	BD.Agency(newFolder(root, "Backdrop"))
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
-- height (facultatif, 10 par défaut) : étagère plus basse sous un plafond bas (agence).
function WH.Rack(parent, name, cx, z1, z2, itemType, categoryId, perSlots, accent, height)
	local model = newModel(parent, name)
	local length = z2 - z1
	local cz = (z1 + z2) / 2
	local size = ITEM_SIZES[itemType]
	local rackHeight = height or 10
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

	local spots = makeZone(model, itemType, anchor, rackHeight - (anchor.Position.Y - FLOOR_TOP) + (if rackHeight < 10 then 2.2 else 3.2), categoryId)
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
	local function wall(name, size, position, solid)
		local alongX = size.X > size.Z
		local lowH, midH, glassH = 3, 16, 6
		local topH = top - (FLOOR_TOP + lowH + midH + glassH)
		local function piece(suffix, h, y, color, material, options)
			local s = if alongX then Vector3.new(size.X, h, size.Z) else Vector3.new(size.X, h, size.Z)
			block(structure, name .. suffix, s, Vector3.new(position.X, y, position.Z), color, material, options)
		end
		piece("Low", lowH + FLOOR_TOP, (lowH + FLOOR_TOP) / 2, COLORS.WallBand, "SmoothPlastic")
		-- Bande de fenêtres à hauteur des yeux (vue sur la cour), murs pleins derrière les portes de quai (solid).
		local ribbonBottom, ribbonTop = FLOOR_TOP + lowH + 1.5, FLOOR_TOP + lowH + 7.5
		piece("MidLow", ribbonBottom - (FLOOR_TOP + lowH), (FLOOR_TOP + lowH + ribbonBottom) / 2, COLORS.Wall, "Concrete")
		piece("MidHigh", FLOOR_TOP + lowH + midH - ribbonTop, (ribbonTop + FLOOR_TOP + lowH + midH) / 2, COLORS.Wall, "Concrete")
		local fixed = if alongX then position.Z else position.X
		local length = if alongX then size.X else size.Z
		local from = (if alongX then position.X else position.Z) - length / 2
		local cursor = from
		local segments = {}
		for _, range in solid or {} do
			table.insert(segments, { cursor, range[1], true })
			table.insert(segments, { range[1], range[2], false })
			cursor = range[2]
		end
		table.insert(segments, { cursor, from + length, true })
		for _, seg in segments do
			if seg[3] then
				AG.Piece(structure, name .. "Ribbon", alongX, fixed, seg[1], seg[2], ribbonBottom, ribbonTop, 0.4, 0, COLORS.Glass, "Glass", { Transparency = 0.45 })
				local count = math.floor((seg[2] - seg[1]) / 20)
				for i = 1, count - 1 do
					local p = seg[1] + i * (seg[2] - seg[1]) / count
					AG.Piece(structure, "RibbonMullion", alongX, fixed, p - 0.25, p + 0.25, ribbonBottom, ribbonTop, 1.1, 0, COLORS.WallBand, "Metal", { CanCollide = false, CastShadow = false })
				end
			else
				AG.Piece(structure, name .. "MidSolid", alongX, fixed, seg[1], seg[2], ribbonBottom, ribbonTop, 1, 0, COLORS.Wall, "Concrete")
			end
		end
		piece("Glass", glassH, FLOOR_TOP + lowH + midH + glassH / 2, COLORS.Glass, "Glass", { Transparency = 0.5 })
		piece("Top", topH, FLOOR_TOP + lowH + midH + glassH + topH / 2, COLORS.Wall, "Concrete")
	end
	wall("NorthWall", Vector3.new(width + 2, 0, 1), Vector3.new(cx, 0, minZ - 0.5))
	wall("SouthWall", Vector3.new(width + 2, 0, 1), Vector3.new(cx, 0, maxZ + 0.5), { { cx - 128, cx - 112 }, { cx - 68, cx - 52 }, { cx + 52, cx + 68 }, { cx + 112, cx + 128 } })
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
	-- Zone industrielle autour (vue par les fenêtres).
	BD.Warehouse(newFolder(root, "Backdrop"))

	WALL_HEIGHT = savedHeight
	setFloor(1)
end

---------------------------------------------------------------------------
-- Agence : mobilier et décor de l'aile est (un grand couloir et 8 pièces de plain-pied)
---------------------------------------------------------------------------
function AG.FurnishWing(furniture, decor)
	setFloor(GROUND_TOP)
	local f = {}
	for _, id in { "EastHall", "StaffCafe", "JobClub", "ComputerLab", "SupplyRoom", "RecordsHall", "CareerLibrary", "ParcelDepot", "Stockroom" } do
		f[id] = newFolder(furniture, id)
	end
	local wx = AG.MinX + 1
	local ceiling = CEILING_BOTTOM
	local noCollide = { CanCollide = false, CastShadow = false }

	-- Couloir : postes de travail libres, imprimantes, salles d'attente et jardinières.
	local hall = f.EastHall
	for i, x in { 110, 116, 150, 156, 190, 196 } do
		createHotDesk(hall, 300 + i, x, -7.3)
	end
	for i, x in { 88, 128, 168, 208 } do
		createPrinterStation(hall, 300 + i, x, -8.4)
	end
	for i, x in { 120, 160, 200 } do
		createChairRug(hall, "WaitingArea" .. i, Vector2.new(x, 7), Vector2.new(14, 8), { x - 5, x - 1.7, x + 1.7, x + 5 }, { 5, 9 }, 0, if i == 2 then COLORS.GreenRug else COLORS.Rug, 5)
	end
	for i, x in { 116, 156, 196, 232 } do
		createPlanter(hall, 300 + i, x, 19)
		if i < 4 then
			createWallArt(hall, Vector3.new(x, FLOOR_TOP + 6.5, 19.7), Vector3.new(0, 0, -1), Vector2.new(5, 3), BRIGHT_COLORS[i + 1])
		end
	end
	createCredenza(hall, 300, AG.MaxX - 1.6, 5)
	createBench(hall, 88, 13)
	createBench(hall, 228, 12.5)
	createWaterCooler(hall, 84, 17)
	createTrashBin(hall, 84, -2)
	createTrashBin(hall, 236, -6)
	createPlant(hall, 237, 17.5)
	createClock(hall, Vector3.new(AG.MaxX - 0.1, FLOOR_TOP + 9, -6), Vector3.new(-1, 0, 0))
	createFireExtinguisher(hall, Vector3.new(wx + 0.3, FLOOR_TOP + 1.2, 14), Vector3.new(1, 0, 0))
	newSign(hall, "WingDirectory", "EAST WING\nCafé - Job Club - Computer Lab - Supply Room\nRecords - Library - Parcels - Stockroom", Vector3.new(10, 3, 0.1), Vector3.new(88.5, FLOOR_TOP + 7, -9.7), Vector3.new(0, 0, 1), COLORS.SignBlue)
	Deco.HangingSign(decor, "EAST WING", Vector3.new(90, FLOOR_TOP + 9, 5), Vector3.new(-1, 0, 0), 10, COLORS.WallBand, ceiling)
	block(decor, "WayfindingLine", Vector3.new(AG.MaxX - wx - 2, 0.02, 0.4), Vector3.new((wx + AG.MaxX) / 2, FLOOR_TOP + 0.01, 0), COLORS.WallBand, "SmoothPlastic", noCollide)

	-- Café du personnel : vaisseliers (mur et îlot), tables, frigo et distributeur.
	local cafe = f.StaffCafe
	for i, x in { 85, 91.5, 108.5, 115 } do
		createCupboard(cafe, 300 + i, x, 21.1)
	end
	for i, x in { 87, 93.5, 106.5, 113 } do
		createCupboard(cafe, 310 + i, x, 31)
	end
	for i, p in { { 90, 43 }, { 110, 43 }, { 90, 54 }, { 110, 54 } } do
		createCafeTable(cafe, 300 + i, p[1], p[2])
		Deco.Pendant(decor, p[1], ceiling - 0.3, p[2], 4, Color3.fromRGB(80, 180, 190), false)
	end
	block(cafe, "Fridge", Vector3.new(2.4, 6, 2.2), Vector3.new(117.5, FLOOR_TOP + 3, 57.6), COLORS.White, "SmoothPlastic")
	local vending = newModel(cafe, "VendingMachine")
	block(vending, "Body", Vector3.new(3, 6.5, 2), Vector3.new(84, FLOOR_TOP + 3.25, 57.8), Color3.fromRGB(200, 50, 50), "SmoothPlastic")
	block(vending, "Window", Vector3.new(2.2, 3.6, 0.05), Vector3.new(83.6, FLOOR_TOP + 4.2, 56.77), Color3.fromRGB(255, 236, 200), "Neon", { CanCollide = false, CastShadow = false, Transparency = 0.3 })
	createWaterCooler(cafe, 100, 58)
	createTrashBin(cafe, 118, 36)
	poster(cafe, "FREE COFFEE\nFOR JOB SEEKERS", Vector3.new(wx + 0.05, FLOOR_TOP + 7, 45), Vector3.new(1, 0, 0), COLORS.SignBlue)
	createClock(cafe, Vector3.new(119.65, FLOOR_TOP + 8, 45), Vector3.new(-1, 0, 0))

	-- Club emploi : coins canapés, jardinières et tableau du programme.
	local club = f.JobClub
	local index = 300
	for _, gx in { 130, 150 } do
		for _, gz in { 30, 42, 54 } do
			index += 1
			createSofa(club, index, gx, gz - 3.6, math.pi)
			index += 1
			createSofa(club, index, gx, gz + 3.6, 0)
			createCoffeeTable(club, gx, gz)
			Deco.Pendant(decor, gx, ceiling - 0.3, gz, 3.5, Color3.fromRGB(240, 170, 60), false)
		end
	end
	createPlanter(club, 320, 140, 40)
	createPlanter(club, 321, 140, 58.9)
	newSign(club, "JobClubBoard", "JOB CLUB\nMondays & Thursdays 10:00\nCV reviews - Mock interviews", Vector3.new(10, 4, 0.1), Vector3.new(159.65, FLOOR_TOP + 6.5, 40), Vector3.new(-1, 0, 0), COLORS.White, Color3.fromRGB(40, 60, 120))
	createWallArt(club, Vector3.new(120.35, FLOOR_TOP + 6.5, 36), Vector3.new(1, 0, 0), Vector2.new(4, 3), Color3.fromRGB(90, 130, 110))
	createWallArt(club, Vector3.new(120.35, FLOOR_TOP + 6.5, 48), Vector3.new(1, 0, 0), Vector2.new(4, 3), Color3.fromRGB(180, 120, 80))
	createPlant(club, 123, 23)

	-- Salle informatique : chariots de recharge, bureaux de formateurs, baies serveurs.
	local lab = f.ComputerLab
	index = 300
	for _, cz in { 21.2, 33, 44 } do
		for _, x in { 165, 171, 189, 195 } do
			index += 1
			createLaptopCart(lab, index, x, cz)
		end
	end
	createTeacherDesk(lab, 170, 55)
	createTeacherDesk(lab, 190, 55)
	createCredenza(lab, 301, 161.2, 52)
	createCredenza(lab, 302, 198.8, 52)
	createPrinterStation(lab, 301, 180, 49)
	createServerRack(lab, 198.5, 25.5)
	createServerRack(lab, 198.5, 28.7)
	newSign(lab, "LabScreen", "COMPUTER LAB\nReturn laptops to the carts", Vector3.new(8, 3, 0.15), Vector3.new(160.35, FLOOR_TOP + 6.5, 35), Vector3.new(1, 0, 0), COLORS.Black, Color3.fromRGB(120, 200, 255))
	createFireExtinguisher(lab, Vector3.new(160.35, FLOOR_TOP + 1.2, 27), Vector3.new(1, 0, 0))

	-- Fournitures : étagères métalliques, imprimantes, buffets et palette.
	local supply = f.SupplyRoom
	index = 300
	for _, cz in { 22, 35, 48 } do
		for _, x in { 205, 211, 229, 235 } do
			index += 1
			createStorageShelf(supply, index, x, cz)
		end
	end
	createPrinterStation(supply, 311, 220, 30)
	createCredenza(supply, 311, AG.MaxX - 1.6, 29)
	createCredenza(supply, 312, AG.MaxX - 1.6, 41.5)
	Deco.PalletStack(supply, 220, 56, 2, COLORS.Cardboard)
	for _, x in { 214.5, 225.5 } do
		block(decor, "HazardLine", Vector3.new(0.4, 0.02, 34), Vector3.new(x, FLOOR_TOP + 0.01, 41), COLORS.Hazard, "SmoothPlastic", noCollide)
	end
	Deco.HangingSign(decor, "SUPPLY ROOM", Vector3.new(220, FLOOR_TOP + 9, 38), Vector3.new(0, 0, -1), 10, COLORS.RackOrange, ceiling)

	-- Salle des dossiers : 3 rangées d'étagères à dossiers et des tables de lecture.
	local records = f.RecordsHall
	index = 300
	for _, cz in { -98.9, -83, -67 } do
		for _, x in { 84.5, 92, 99.5, 107, 114.5 } do
			index += 1
			createArchiveShelf(records, index, x, cz)
		end
	end
	index = 0
	for _, cz in { -45, -30 } do
		for _, x in { 92, 108 } do
			index += 1
			createReadingTable(records, "RecordsTable" .. index, x, cz)
		end
	end
	Deco.HangingSign(decor, "RECORDS HALL", Vector3.new(100, FLOOR_TOP + 9, -55), Vector3.new(0, 0, 1), 10, Color3.fromRGB(196, 96, 74), ceiling)
	createClock(records, Vector3.new(119.65, FLOOR_TOP + 8, -40), Vector3.new(-1, 0, 0))
	createWallArt(records, Vector3.new(wx + 0.05, FLOOR_TOP + 6.5, -45), Vector3.new(1, 0, 0), Vector2.new(4, 3), Color3.fromRGB(70, 110, 150))
	createWallArt(records, Vector3.new(wx + 0.05, FLOOR_TOP + 6.5, -28), Vector3.new(1, 0, 0), Vector2.new(4, 3), Color3.fromRGB(160, 120, 70))
	createPlant(records, 84, -13)
	createPlant(records, 116, -13)
	createTrashBin(records, 117, -52)

	-- Bibliothèque des métiers : 16 bibliothèques de couleur, tables de lecture, lustres et boiseries.
	local library = f.CareerLibrary
	local bookCats = { "CV", "Interview", "Training", "Careers" }
	index = 300
	for row, cz in { -99.1, -86, -73, -60 } do
		for col, x in { 125, 132, 148, 155 } do
			index += 1
			createBookcase(library, index, x, cz, bookCats[(row + col) % 4 + 1])
		end
	end
	index = 0
	for _, cz in { -42, -27 } do
		for _, x in { 130, 150 } do
			index += 1
			createReadingTable(library, "LibraryTable" .. index, x, cz)
		end
	end
	Deco.Chandelier(decor, 140, ceiling - 0.3, -34, 0.9)
	Deco.Chandelier(decor, 140, ceiling - 0.3, -80, 0.9)
	Deco.Wainscot(decor, Vector3.new(120.4, 0, -54), Vector3.new(120.4, 0, -13), Vector3.new(1, 0, 0), 3.5, COLORS.Walnut)
	Deco.Wainscot(decor, Vector3.new(159.6, 0, -13), Vector3.new(159.6, 0, -54), Vector3.new(-1, 0, 0), 3.5, COLORS.Walnut)
	newSign(library, "LibrarySign", "CAREER LIBRARY  -  QUIET PLEASE", Vector3.new(14, 1.2, 0.1), Vector3.new(140, FLOOR_TOP + 10.2, -10.35), Vector3.new(0, 0, -1))
	createPlant(library, 123, -13)
	createPlant(library, 157, -13)

	-- Dépôt de colis : rayonnages d'entrepôt (un par couleur d'étiquette), tapis roulant, tables de tri.
	local depot = f.ParcelDepot
	local parcelCats = TidyConfig.Categories.Parcel
	index = 0
	for col, x in { 166, 175, 185, 194 } do
		local category = parcelCats[col]
		for _, range in { { -97, -85 }, { -79, -67 } } do
			index += 1
			WH.Rack(depot, "ParcelRack" .. index, x, range[1], range[2], "Parcel", category.Id, 40, category.Color, 7.5)
		end
	end
	WH.Conveyor(depot, 164, 196, -45)
	WH.WorkTable(depot, 172, -30, false)
	WH.WorkTable(depot, 190, -30, false)
	createMailCart(depot, 168, -56)
	createMailCart(depot, 192, -58)
	Deco.PalletStack(depot, 196, -20, 2, nil)
	block(decor, "HazardLine", Vector3.new(36, 0.02, 0.4), Vector3.new(180, FLOOR_TOP + 0.01, -63), COLORS.Hazard, "SmoothPlastic", noCollide)
	Deco.HangingSign(decor, "PARCEL DEPOT", Vector3.new(180, FLOOR_TOP + 9, -58), Vector3.new(0, 0, 1), 10, Color3.fromRGB(40, 140, 160), ceiling)
	poster(depot, "SORT EVERY PARCEL\nBY LABEL COLOR", Vector3.new(160.35, FLOOR_TOP + 7, -40), Vector3.new(1, 0, 0), COLORS.SignBlue)

	-- Réserve : rayonnages à cartons, palettes et chariot élévateur.
	local stock = f.Stockroom
	for i, x in { 206, 215, 225, 234 } do
		WH.Rack(stock, "BoxRack" .. i, x, -97, -73, "Box", nil, 40, BRIGHT_COLORS[i], 8)
	end
	WH.Forklift(stock, 228, -45, math.rad(90))
	Deco.PalletStack(stock, 206, -56, 3, COLORS.Cardboard)
	Deco.PalletStack(stock, 234, -60, 2, COLORS.Cardboard)
	block(decor, "HazardLine", Vector3.new(36, 0.02, 0.4), Vector3.new(220, FLOOR_TOP + 0.01, -69), COLORS.Hazard, "SmoothPlastic", noCollide)
	Deco.HangingSign(decor, "STOCKROOM", Vector3.new(220, FLOOR_TOP + 9, -62), Vector3.new(0, 0, 1), 10, COLORS.RackOrange, ceiling)
	createFireExtinguisher(stock, Vector3.new(200.35, FLOOR_TOP + 1.2, -30), Vector3.new(1, 0, 0))
end

---------------------------------------------------------------------------
-- Décors extérieurs (vus par les fenêtres) : très peu de pièces, grandes et simples,
-- sans collision, sans ombre et ignorées par les clics. Le sol cache le gazon de la Baseplate.
---------------------------------------------------------------------------
BD.Asphalt = Color3.fromRGB(54, 56, 60)
BD.Line = Color3.fromRGB(236, 236, 230)
BD.Yellow = Color3.fromRGB(240, 196, 50)
BD.CarColors = {
	Color3.fromRGB(200, 40, 40), Color3.fromRGB(230, 230, 228), Color3.fromRGB(40, 44, 52), Color3.fromRGB(46, 96, 170),
	Color3.fromRGB(150, 154, 160), Color3.fromRGB(250, 196, 40), Color3.fromRGB(60, 120, 80), Color3.fromRGB(110, 30, 40),
}

function BD.Part(parent, name, size, cframe, color, material, transparency)
	local part = newPart(parent, name, size, cframe, color, material or "SmoothPlastic", { CanCollide = false, CastShadow = false })
	part.CanTouch = false
	part.CanQuery = false
	if transparency then
		part.Transparency = transparency
	end
	return part
end

function BD.Box(parent, name, size, position, color, material, transparency)
	return BD.Part(parent, name, size, CFrame.new(position), color, material, transparency)
end

-- Cylindre vertical.
function BD.Cyl(parent, name, height, diameter, center, color, material)
	local part = BD.Part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Dalle de sol (topY = hauteur du dessus).
function BD.Ground(parent, name, minX, maxX, minZ, maxZ, topY, thickness, color, material)
	return BD.Box(parent, name, Vector3.new(maxX - minX, thickness, maxZ - minZ), Vector3.new((minX + maxX) / 2, topY - thickness / 2, (minZ + maxZ) / 2), color, material)
end

-- Voiture (4 pièces) ; simple = sans roues (vue de très haut).
function BD.Car(parent, x, z, yaw, color, groundY, simple)
	local base = CFrame.new(x, groundY, z) * CFrame.Angles(0, yaw, 0)
	BD.Part(parent, "CarBody", Vector3.new(4.4, 1.5, 9.5), base * CFrame.new(0, 1.35, 0), color, "SmoothPlastic")
	BD.Part(parent, "CarCabin", Vector3.new(4, 1.3, 5), base * CFrame.new(0, 2.75, 0.4), Color3.fromRGB(40, 48, 60), "Glass")
	if not simple then
		for _, wz in { -3, 3 } do
			BD.Part(parent, "Wheels", Vector3.new(4.6, 1.7, 1.7), base * CFrame.new(0, 0.85, wz), COLORS.Black, "SmoothPlastic").Shape = Enum.PartType.Cylinder
		end
	end
end

-- Semi-remorque : l'arrière de la remorque est à (x, z), le tracteur devant (vers +Z local).
function BD.Truck(parent, x, z, yaw, color, withCab, groundY)
	local base = CFrame.new(x, groundY, z) * CFrame.Angles(0, yaw, 0)
	BD.Part(parent, "Trailer", Vector3.new(8, 9, 40), base * CFrame.new(0, 6.6, 20), color, "Metal")
	BD.Part(parent, "TrailerStripe", Vector3.new(8.1, 0.5, 40.1), base * CFrame.new(0, 2.6, 20), Color3.fromRGB(220, 60, 50), "SmoothPlastic")
	for _, wz in { 4, 7.5 } do
		BD.Part(parent, "Wheels", Vector3.new(8.4, 2.6, 2.6), base * CFrame.new(0, 1.3, wz), COLORS.Black, "SmoothPlastic").Shape = Enum.PartType.Cylinder
	end
	if withCab then
		BD.Part(parent, "Cab", Vector3.new(8, 7.5, 7), base * CFrame.new(0, 5.4, 45), Color3.fromRGB(230, 232, 236), "SmoothPlastic")
		BD.Part(parent, "Windshield", Vector3.new(7.2, 2.6, 0.3), base * CFrame.new(0, 7, 48.55), Color3.fromRGB(40, 50, 64), "Glass")
		BD.Part(parent, "Hood", Vector3.new(7.6, 3.6, 4.5), base * CFrame.new(0, 3.4, 50.7), Color3.fromRGB(200, 50, 46), "SmoothPlastic")
		BD.Part(parent, "Wheels", Vector3.new(8.4, 2.8, 2.8), base * CFrame.new(0, 1.4, 49), COLORS.Black, "SmoothPlastic").Shape = Enum.PartType.Cylinder
	end
end

-- Lampadaire (3 pièces, sans vraie lumière). facing = côté de la rue.
function BD.Lamp(parent, x, z, facing, groundY)
	local h = 13
	BD.Box(parent, "LampPole", Vector3.new(0.5, h, 0.5), Vector3.new(x, groundY + h / 2, z), COLORS.DarkMetal, "Metal")
	local top = Vector3.new(x, groundY + h - 0.2, z)
	BD.Part(parent, "LampArm", Vector3.new(0.3, 0.3, 3.4), CFrame.lookAt(top + facing * 1.7, top + facing * 4), COLORS.DarkMetal, "Metal")
	BD.Box(parent, "LampHead", Vector3.new(1.4, 0.35, 1.4), top + facing * 3.4 - Vector3.new(0, 0.3, 0), Color3.fromRGB(255, 240, 206), "Neon")
end

function BD.Tree(parent, x, z, groundY, scale)
	BD.Box(parent, "TreeTrunk", Vector3.new(0.8, 5 * scale, 0.8), Vector3.new(x, groundY + 2.5 * scale, z), Color3.fromRGB(110, 80, 56), "Wood")
	BD.Box(parent, "TreeCrown", Vector3.new(7, 6.5, 7) * scale, Vector3.new(x, groundY + 7 * scale, z), Color3.fromRGB(78, 140, 70), "Grass").Shape = Enum.PartType.Ball
end

-- Immeuble de bureaux : volume, bandeaux de fenêtres (un bloc un peu plus large, au plus 7), vitrine et corniche.
function BD.Building(parent, cx, cz, w, d, h, bodyColor, bandColor, groundY)
	BD.Box(parent, "Building", Vector3.new(w, h, d), Vector3.new(cx, groundY + h / 2, cz), bodyColor, "Concrete")
	local floorH = 7
	local floors = math.floor((h - 8) / floorH)
	local step = math.max(1, math.ceil(floors / 7))
	for i = 1, floors, step do
		BD.Box(parent, "WindowBand", Vector3.new(w + 0.4, 3.2, d + 0.4), Vector3.new(cx, groundY + 6 + i * floorH - floorH / 2, cz), bandColor, "Glass")
	end
	BD.Box(parent, "Storefront", Vector3.new(w + 0.3, 5, d + 0.3), Vector3.new(cx, groundY + 2.5, cz), Color3.fromRGB(44, 56, 70), "Glass")
	BD.Box(parent, "Cornice", Vector3.new(w + 1, 1, d + 1), Vector3.new(cx, groundY + h + 0.5, cz), bodyColor:Lerp(Color3.new(0, 0, 0), 0.25), "Concrete")
	BD.Box(parent, "RoofUnit", Vector3.new(w * 0.3, 3, d * 0.3), Vector3.new(cx + w * 0.15, groundY + h + 2.5, cz - d * 0.1), Color3.fromRGB(150, 152, 156), "Metal")
end

-- Gratte-ciel de verre : corps, bandeaux techniques, étage en retrait, couronne et parfois une flèche.
function BD.Tower(parent, cx, cz, w, d, h, color, trim)
	local bodyH = math.floor(h * 0.8)
	BD.Box(parent, "TowerBody", Vector3.new(w, bodyH, d), Vector3.new(cx, bodyH / 2, cz), color, "Glass").Reflectance = 0.25
	BD.Box(parent, "TowerTier", Vector3.new(w * 0.72, h - bodyH, d * 0.72), Vector3.new(cx, bodyH + (h - bodyH) / 2, cz), color:Lerp(Color3.new(1, 1, 1), 0.12), "Glass").Reflectance = 0.25
	for y = 64, bodyH - 16, 64 do
		BD.Box(parent, "TowerBand", Vector3.new(w + 0.6, 1.6, d + 0.6), Vector3.new(cx, y, cz), trim, "Metal")
	end
	BD.Box(parent, "TowerCrown", Vector3.new(w * 0.72 + 0.8, 2.4, d * 0.72 + 0.8), Vector3.new(cx, h + 1.2, cz), trim, "Metal")
	if h >= 280 then
		BD.Box(parent, "TowerSpire", Vector3.new(1.2, 40, 1.2), Vector3.new(cx, h + 22, cz), trim, "Metal")
	end
end

-- Agence : rue animée (avenue avec passage piéton, voitures garées, arrêt de bus, lampadaires, arbres)
-- et immeubles de bureaux tout autour. Plus le toit de l'aile est (acrotère et climatiseurs).
function BD.Agency(parent)
	local wasCollecting = collectObstacles
	collectObstacles = false
	local g = 0.3 -- dessus de la chaussée
	BD.Ground(parent, "Pavement", -480, 640, -420, 460, 0.2, 0.4, Color3.fromRGB(196, 192, 184), "Concrete")
	BD.Ground(parent, "Avenue", -480, 640, 78, 108, g, 0.2, BD.Asphalt, "Asphalt")
	BD.Ground(parent, "NorthStreet", -480, 640, -150, -126, g, 0.2, BD.Asphalt, "Asphalt")
	for _, x in { -132, 268 } do
		for _, seg in { { -420, -150 }, { -126, 78 }, { 108, 460 } } do
			BD.Ground(parent, "SideStreet", x, x + 24, seg[1], seg[2], g, 0.2, BD.Asphalt, "Asphalt")
		end
	end
	for _, z in { 92.6, 93.4 } do
		BD.Box(parent, "CenterLine", Vector3.new(1120, 0.05, 0.3), Vector3.new(80, g + 0.03, z), BD.Yellow, "SmoothPlastic")
	end
	for _, z in { 79.6, 106.4 } do
		BD.Box(parent, "EdgeLine", Vector3.new(1120, 0.05, 0.3), Vector3.new(80, g + 0.03, z), BD.Line, "SmoothPlastic")
	end
	BD.Box(parent, "CenterLine", Vector3.new(1120, 0.05, 0.3), Vector3.new(80, g + 0.03, -138), BD.Line, "SmoothPlastic")
	for i = -3, 3 do
		BD.Box(parent, "Crosswalk", Vector3.new(1.4, 0.05, 26), Vector3.new(i * 2.3, g + 0.04, 93), BD.Line, "SmoothPlastic")
	end
	for _, z in { 77.7, 108.3 } do
		BD.Box(parent, "Curb", Vector3.new(1120, 0.3, 0.6), Vector3.new(80, 0.35, z), Color3.fromRGB(160, 158, 152), "Concrete")
	end
	-- Voitures garées des deux côtés de l'avenue.
	for i, x in { -70, -50, 26, 46, 120, 142, 168, 214, 330, -200 } do
		BD.Car(parent, x, 82.5, math.rad(90), BD.CarColors[(i - 1) % #BD.CarColors + 1], g)
	end
	for i, x in { -40, 10, 70, 190, 236, -150, 380 } do
		BD.Car(parent, x, 103.5, math.rad(-90), BD.CarColors[(i + 3) % #BD.CarColors + 1], g)
	end
	-- Arrêt de bus et bus.
	BD.Box(parent, "ShelterRoof", Vector3.new(10, 0.3, 3.6), Vector3.new(90, 8, 70), COLORS.DarkMetal, "Metal")
	BD.Box(parent, "ShelterGlass", Vector3.new(10, 6, 0.2), Vector3.new(90, 4.4, 71.7), COLORS.Glass, "Glass", 0.5)
	for _, x in { 85.2, 94.8 } do
		BD.Box(parent, "ShelterPost", Vector3.new(0.3, 7.6, 0.3), Vector3.new(x, 4.1, 68.4), COLORS.DarkMetal, "Metal")
	end
	BD.Box(parent, "ShelterBench", Vector3.new(8, 0.4, 1.2), Vector3.new(90, 1.9, 71), COLORS.Wood, "Wood")
	local stopSign = newSign(parent, "BusStopSign", "BUS 42  -  CITY CENTRE", Vector3.new(6, 1, 0.1), Vector3.new(90, 8.8, 68.2), Vector3.new(0, 0, -1), COLORS.SignBlue)
	stopSign.CanQuery = false
	BD.Box(parent, "Bus", Vector3.new(24, 6.4, 5), Vector3.new(90, g + 4.6, 82.5), Color3.fromRGB(40, 110, 190), "SmoothPlastic")
	BD.Box(parent, "BusWindows", Vector3.new(24.1, 1.9, 5.1), Vector3.new(90, g + 6, 82.5), Color3.fromRGB(36, 44, 56), "Glass")
	for _, dx in { -8, 8 } do
		BD.Part(parent, "Wheels", Vector3.new(5.2, 2.4, 2.4), CFrame.new(90 + dx, g + 1.2, 82.5) * CFrame.Angles(0, math.rad(90), 0), COLORS.Black, "SmoothPlastic").Shape = Enum.PartType.Cylinder
	end
	-- Lampadaires, arbres, feux et bouche d'incendie.
	for _, x in { -100, -60, -20, 30, 70, 130, 170, 210, 250 } do
		BD.Lamp(parent, x, 76, Vector3.new(0, 0, 1), 0.2)
	end
	for _, x in { -80, -40, 0, 50, 110, 150, 230 } do
		BD.Lamp(parent, x, 110, Vector3.new(0, 0, -1), 0.2)
	end
	for _, z in { -80, -20, 40 } do
		BD.Lamp(parent, 266, z, Vector3.new(1, 0, 0), 0.2)
		BD.Lamp(parent, -106, z, Vector3.new(-1, 0, 0), 0.2)
	end
	for _, x in { -120, -85, -45, 22, 60, 112, 150, 190, 228 } do
		BD.Tree(parent, x, 70.5, 0.2, 1)
	end
	for _, z in { -90, -50, -10, 30 } do
		BD.Tree(parent, 256, z, 0.2, 1.1)
		BD.Tree(parent, -95, z, 0.2, 1.1)
	end
	for _, p in { { 10, 76.5, 0 }, { -10, 109.5, 180 } } do
		BD.Box(parent, "TrafficPole", Vector3.new(0.4, 9, 0.4), Vector3.new(p[1], 4.7, p[2]), COLORS.DarkMetal, "Metal")
		BD.Box(parent, "TrafficLight", Vector3.new(0.9, 2.4, 0.9), Vector3.new(p[1], 8.4, p[2]), Color3.fromRGB(30, 30, 34), "SmoothPlastic")
	end
	BD.Cyl(parent, "Hydrant", 1.2, 0.7, Vector3.new(60, 0.8, 76), Color3.fromRGB(200, 40, 40), "Metal")
	-- Immeubles de bureaux autour de l'agence (sud, est, ouest, nord).
	local styles = {
		{ Color3.fromRGB(214, 204, 186), Color3.fromRGB(56, 70, 86) },
		{ Color3.fromRGB(150, 70, 56), Color3.fromRGB(40, 48, 58) },
		{ Color3.fromRGB(196, 202, 210), Color3.fromRGB(70, 110, 150) },
		{ Color3.fromRGB(232, 226, 214), Color3.fromRGB(60, 90, 110) },
		{ Color3.fromRGB(120, 126, 134), Color3.fromRGB(150, 196, 220) },
	}
	for i, b in {
		{ -330, 150, 80, 60, 70 }, { -230, 145, 90, 50, 48 }, { -130, 150, 80, 60, 64 }, { -40, 158, 70, 70, 96 },
		{ 40, 145, 60, 50, 42 }, { 110, 150, 70, 60, 78 }, { 190, 145, 70, 50, 52 }, { 236, 145, 36, 50, 36 },
		{ 340, 150, 70, 60, 110 }, { 440, 150, 90, 60, 66 }, { 560, 150, 80, 60, 88 },
		{ 330, 20, 60, 90, 58 }, { 420, 0, 90, 110, 120 }, { 330, -85, 60, 60, 40 }, { 540, -40, 100, 120, 76 },
		{ -180, 0, 60, 120, 54 }, { -260, -85, 70, 60, 90 }, { -280, 30, 70, 80, 44 }, { -400, -20, 120, 120, 70 },
		{ -60, -200, 100, 60, 60 }, { 60, -210, 90, 80, 84 }, { 170, -200, 100, 60, 46 }, { -200, -220, 90, 100, 100 }, { 330, -220, 80, 100, 130 },
	} do
		local style = styles[(i - 1) % #styles + 1]
		BD.Building(parent, b[1], b[2], b[3], b[4], b[5], style[1], style[2], 0.2)
	end
	-- Toit de l'aile est : acrotère et climatiseurs (vus depuis l'étage).
	local roofY = CEILING_BOTTOM + 1
	BD.Box(parent, "Parapet", Vector3.new(AG.MaxX - AG.MinX, 1.2, 0.6), Vector3.new((AG.MinX + AG.MaxX) / 2 + 1, roofY + 0.6, MIN_Z - 0.7), COLORS.Wall, "Concrete")
	BD.Box(parent, "Parapet", Vector3.new(AG.MaxX - AG.MinX, 1.2, 0.6), Vector3.new((AG.MinX + AG.MaxX) / 2 + 1, roofY + 0.6, MAX_Z + 0.7), COLORS.Wall, "Concrete")
	BD.Box(parent, "Parapet", Vector3.new(0.6, 1.2, DEPTH_Z + 2), Vector3.new(AG.MaxX + 0.7, roofY + 0.6, MID_Z), COLORS.Wall, "Concrete")
	for _, p in { { 140, -60 }, { 200, -40 }, { 180, 40 }, { 110, 36 } } do
		BD.Box(parent, "RoofHVAC", Vector3.new(8, 3, 6), Vector3.new(p[1], roofY + 1.5, p[2]), Color3.fromRGB(176, 180, 186), "Metal")
		BD.Cyl(parent, "HVACFan", 0.3, 4, Vector3.new(p[1] + 1.5, roofY + 3.1, p[2]), COLORS.DarkMetal, "Metal")
	end
	collectObstacles = wasCollecting
end

-- Entrepôt : zone industrielle (cour en asphalte, camions aux quais, remorques, conteneurs,
-- clôture, parking du personnel, mâts d'éclairage, autres entrepôts au loin).
function BD.Warehouse(parent)
	local wasCollecting = collectObstacles
	collectObstacles = false
	local g = 0.3
	BD.Ground(parent, "Concrete", 420, 1720, -560, 600, 0.2, 0.4, Color3.fromRGB(172, 170, 164), "Concrete")
	BD.Ground(parent, "Yard", 680, 1340, -240, 330, g, 0.2, BD.Asphalt, "Asphalt")
	BD.Ground(parent, "DockApron", 840, 1160, 121, 150, 0.45, 0.2, Color3.fromRGB(190, 188, 182), "Concrete")
	BD.Ground(parent, "SouthRoad", 420, 1720, 360, 390, g, 0.2, BD.Asphalt, "Asphalt")
	BD.Ground(parent, "EastRoad", 1380, 1410, -560, 360, g, 0.2, BD.Asphalt, "Asphalt")
	BD.Box(parent, "RoadLine", Vector3.new(1300, 0.05, 0.3), Vector3.new(1070, g + 0.03, 375), BD.Yellow, "SmoothPlastic")
	-- Camions à quai (devant les 4 portes de quai) et remorques garées.
	for i, x in { 880, 940, 1060, 1120 } do
		BD.Truck(parent, x, 122.5, 0, if i % 2 == 0 then Color3.fromRGB(236, 236, 232) else Color3.fromRGB(70, 110, 170), true, 0.45)
	end
	for i, x in { 760, 775, 790, 805, 1150, 1165, 1180, 1195 } do
		BD.Truck(parent, x, 200, 0, if i % 3 == 0 then Color3.fromRGB(200, 70, 50) else Color3.fromRGB(226, 228, 230), false, g)
	end
	for _, x in { 752.5, 767.5, 782.5, 797.5, 812.5, 1142.5, 1157.5, 1172.5, 1187.5, 1202.5 } do
		BD.Box(parent, "ParkingLine", Vector3.new(0.4, 0.05, 44), Vector3.new(x, g + 0.03, 220), BD.Yellow, "SmoothPlastic")
	end
	-- Parking du personnel (ouest).
	for z = -60, 12, 6 do
		BD.Box(parent, "ParkingLine", Vector3.new(14, 0.05, 0.25), Vector3.new(760, g + 0.03, z), BD.Line, "SmoothPlastic")
	end
	for i, z in { -57, -45, -39, -27, -15, -3, 9 } do
		BD.Car(parent, 760, z, math.rad(90), BD.CarColors[i], g)
	end
	-- Conteneurs empilés (est).
	local containerColors = { Color3.fromRGB(170, 70, 50), Color3.fromRGB(40, 90, 160), Color3.fromRGB(60, 130, 80), Color3.fromRGB(150, 150, 156), Color3.fromRGB(220, 130, 40) }
	local n = 0
	for _, x in { 1240, 1250, 1260, 1290, 1300 } do
		for _, z in { -150, -100, -50, 10 } do
			n += 1
			for level = 0, (n * 7) % 3 do
				BD.Box(parent, "Container", Vector3.new(8, 8.5, 40), Vector3.new(x, g + 4.25 + level * 8.5, z), containerColors[(n + level) % #containerColors + 1], "Metal")
			end
		end
	end
	-- Clôture grillagée autour de la cour, avec poteaux et un poste de garde.
	local fx1, fx2, fz1, fz2 = 660, 1360, -260, 340
	for _, side in { { fx1, fz1, fx2, fz1 }, { fx1, fz2, fx2, fz2 }, { fx1, fz1, fx1, fz2 }, { fx2, fz1, fx2, fz2 } } do
		local alongX = side[2] == side[4]
		local length = if alongX then side[3] - side[1] else side[4] - side[2]
		local center = Vector3.new((side[1] + side[3]) / 2, 0, (side[2] + side[4]) / 2)
		BD.Box(parent, "FenceMesh", if alongX then Vector3.new(length, 9, 0.15) else Vector3.new(0.15, 9, length), center + Vector3.new(0, 4.7, 0), Color3.fromRGB(130, 136, 144), "Metal", 0.6)
		local posts = math.floor(length / 100)
		for i = 0, posts do
			local t = side[1] == side[3] and Vector3.new(side[1], 4.7, side[2] + i * length / posts) or Vector3.new(side[1] + i * length / posts, 4.7, side[2])
			BD.Box(parent, "FencePost", Vector3.new(0.4, 9.4, 0.4), t, COLORS.DarkMetal, "Metal")
		end
	end
	BD.Box(parent, "Gatehouse", Vector3.new(8, 8, 6), Vector3.new(1040, 4.2, 330), COLORS.Wall, "Concrete")
	BD.Box(parent, "GatehouseWindows", Vector3.new(8.2, 2.4, 6.2), Vector3.new(1040, 5.6, 330), Color3.fromRGB(40, 50, 64), "Glass")
	BD.Box(parent, "GatehouseRoof", Vector3.new(10, 0.6, 8), Vector3.new(1040, 8.5, 330), COLORS.WallBand, "SmoothPlastic")
	BD.Box(parent, "GateBarrier", Vector3.new(14, 0.4, 0.4), Vector3.new(1024, 3.5, 340), Color3.fromRGB(220, 50, 40), "SmoothPlastic")
	-- Mâts d'éclairage de la cour (visibles par les fenêtres hautes).
	for _, p in { { 700, -230 }, { 700, 300 }, { 1330, -230 }, { 1330, 300 }, { 1000, 290 }, { 760, 150 }, { 1240, 150 } } do
		BD.Box(parent, "LightMast", Vector3.new(1, 40, 1), Vector3.new(p[1], 20.2, p[2]), Color3.fromRGB(150, 154, 160), "Metal")
		BD.Box(parent, "MastLights", Vector3.new(6, 1.5, 3), Vector3.new(p[1], 40.5, p[2]), Color3.fromRGB(255, 244, 214), "Neon")
	end
	-- Autres entrepôts au loin.
	for i, w in {
		{ 1440, 1700, -220, 80, 34 }, { 460, 640, -360, -140, 30 }, { 760, 1240, -520, -330, 40 },
		{ 1440, 1700, 200, 460, 28 }, { 460, 640, 120, 440, 32 }, { 1440, 1650, -520, -300, 36 },
	} do
		local cx, cz = (w[1] + w[2]) / 2, (w[3] + w[4]) / 2
		local color = if i % 2 == 0 then Color3.fromRGB(196, 200, 206) else Color3.fromRGB(226, 220, 206)
		BD.Box(parent, "FarWarehouse", Vector3.new(w[2] - w[1], w[5], w[4] - w[3]), Vector3.new(cx, w[5] / 2, cz), color, "Concrete")
		BD.Box(parent, "FarWarehouseBand", Vector3.new(w[2] - w[1] + 0.6, 4, w[4] - w[3] + 0.6), Vector3.new(cx, 2, cz), BRIGHT_COLORS[i], "SmoothPlastic")
		BD.Box(parent, "FarWarehouseRoof", Vector3.new(w[2] - w[1] + 1.2, 1.2, w[4] - w[3] + 1.2), Vector3.new(cx, w[5] + 0.6, cz), Color3.fromRGB(150, 152, 156), "Metal")
	end
	-- Silos et château d'eau.
	for _, z in { -60, -38, -16 } do
		BD.Cyl(parent, "Silo", 50, 16, Vector3.new(560, 25.2, z), Color3.fromRGB(210, 212, 214), "Metal")
	end
	for _, s in { { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } } do
		BD.Box(parent, "TowerLeg", Vector3.new(1, 40, 1), Vector3.new(1425 + s[1], 20.2, 150 + s[2]), COLORS.DarkMetal, "Metal")
	end
	BD.Cyl(parent, "WaterTank", 14, 20, Vector3.new(1425, 47, 150), Color3.fromRGB(80, 140, 190), "Metal")
	BD.Cyl(parent, "WaterTankRoof", 1, 21, Vector3.new(1425, 54.5, 150), Color3.fromRGB(60, 110, 160), "Metal")
	collectObstacles = wasCollecting
end

-- Siège social : la tour sous les bureaux (corps vitré, bandeaux d'étages, socle, couronne)
-- et le quartier d'affaires autour (gratte-ciel, avenues tout en bas, esplanade avec fontaine).
function BD.Headquarters(parent, HQ) -- HQ est passé en paramètre (table définie plus bas)
	local wasCollecting = collectObstacles
	collectObstacles = false
	local tx, tz = (HQ.MinX + HQ.MaxX) / 2, (HQ.MinZ + HQ.MaxZ) / 2
	local w, d = HQ.MaxX - HQ.MinX, HQ.MaxZ - HQ.MinZ
	local slabBottom = HQ.Floor - 1
	local glass = Color3.fromRGB(58, 92, 118)
	local trim = Color3.fromRGB(196, 200, 206)
	-- Tour.
	BD.Box(parent, "TowerPodium", Vector3.new(w + 40, 24, d + 40), Vector3.new(tx, 12.2, tz), Color3.fromRGB(206, 200, 190), "Limestone")
	BD.Box(parent, "TowerBody", Vector3.new(w - 2, slabBottom - 24.4, d - 2), Vector3.new(tx, 24.4 + (slabBottom - 24.4) / 2 - 0.1, tz), glass, "Glass").Reflectance = 0.25
	for y = 40, slabBottom - 8, 16 do
		BD.Box(parent, "TowerFloorBand", Vector3.new(w + 0.4, 1.2, d + 0.4), Vector3.new(tx, y, tz), trim, "Metal")
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			BD.Box(parent, "TowerCorner", Vector3.new(5, slabBottom - 24.4, 5), Vector3.new(tx + sx * (w / 2 - 1.5), 24.4 + (slabBottom - 24.4) / 2 - 0.1, tz + sz * (d / 2 - 1.5)), trim, "Metal")
		end
	end
	BD.Box(parent, "TowerCanopy", Vector3.new(50, 1, 16), Vector3.new(tx, 14, HQ.MaxZ + 28), COLORS.Walnut, "Wood")
	local logo = newSign(parent, "TowerLogo", "APEX HOLDINGS", Vector3.new(70, 9, 0.5), Vector3.new(tx, 19, HQ.MaxZ + 20.3), Vector3.new(0, 0, 1), COLORS.Walnut, COLORS.Gold)
	logo.CanQuery = false
	-- Toit : acrotère, héliport, locaux techniques et antenne.
	local roofY = CEILING_BOTTOM + 1
	for _, e in { { true, HQ.MinZ - 1.4 }, { true, HQ.MaxZ + 1.4 }, { false, HQ.MinX - 1.4 }, { false, HQ.MaxX + 1.4 } } do
		local size = if e[1] then Vector3.new(w + 3.6, 3, 0.8) else Vector3.new(0.8, 3, d + 2)
		local position = if e[1] then Vector3.new(tx, roofY + 1.5, e[2]) else Vector3.new(e[2], roofY + 1.5, tz)
		BD.Box(parent, "Parapet", size, position, trim, "Metal")
	end
	BD.Cyl(parent, "Helipad", 0.4, 44, Vector3.new(-930, roofY + 0.2, -150), Color3.fromRGB(60, 64, 70), "Concrete")
	BD.Box(parent, "HelipadH", Vector3.new(2, 0.1, 16), Vector3.new(-935, roofY + 0.45, -150), COLORS.White, "SmoothPlastic")
	BD.Box(parent, "HelipadH", Vector3.new(2, 0.1, 16), Vector3.new(-925, roofY + 0.45, -150), COLORS.White, "SmoothPlastic")
	BD.Box(parent, "HelipadH", Vector3.new(8, 0.1, 2), Vector3.new(-930, roofY + 0.45, -150), COLORS.White, "SmoothPlastic")
	BD.Box(parent, "RoofPlant", Vector3.new(30, 8, 20), Vector3.new(-1130, roofY + 4, -150), Color3.fromRGB(176, 180, 186), "Metal")
	BD.Box(parent, "RoofPlant", Vector3.new(24, 6, 18), Vector3.new(-1130, roofY + 3, 50), Color3.fromRGB(176, 180, 186), "Metal")
	BD.Box(parent, "Antenna", Vector3.new(1.5, 60, 1.5), Vector3.new(-1130, roofY + 38, -150), trim, "Metal")
	BD.Box(parent, "AntennaLight", Vector3.new(1.2, 1.2, 1.2), Vector3.new(-1130, roofY + 68.6, -150), Color3.fromRGB(255, 60, 50), "Neon")
	-- Sol du quartier, esplanade, avenues et voitures (tout en bas).
	local g = 0.3
	BD.Ground(parent, "CityPavement", -1820, -260, -820, 720, 0.2, 0.4, Color3.fromRGB(178, 176, 172), "Concrete")
	BD.Ground(parent, "Plaza", -1270, -790, -290, 190, 0.45, 0.3, Color3.fromRGB(214, 206, 192), "Slate")
	for _, z in { 230, -360 } do
		BD.Ground(parent, "Avenue", -1820, -260, z, z + 30, g, 0.2, BD.Asphalt, "Asphalt")
		BD.Box(parent, "AvenueLine", Vector3.new(1560, 0.05, 0.4), Vector3.new(-1040, g + 0.03, z + 15), BD.Yellow, "SmoothPlastic")
	end
	for _, x in { -1340, -750 } do
		for _, seg in { { -820, -360 }, { -330, 230 }, { 260, 720 } } do
			BD.Ground(parent, "Avenue", x, x + 30, seg[1], seg[2], g, 0.2, BD.Asphalt, "Asphalt")
			BD.Box(parent, "AvenueLine", Vector3.new(0.4, 0.05, seg[2] - seg[1]), Vector3.new(x + 15, g + 0.03, (seg[1] + seg[2]) / 2), BD.Line, "SmoothPlastic")
		end
	end
	local k = 0
	for _, x in { -1700, -1560, -1420, -1180, -980, -860, -640, -480, -350 } do
		for _, z in { 238, 252, -352, -338 } do
			k += 1
			if k % 3 ~= 0 then
				BD.Car(parent, x + (k % 5) * 9, z, math.rad(if z == 238 or z == -352 then 90 else -90), BD.CarColors[k % #BD.CarColors + 1], g, true)
			end
		end
	end
	for _, z in { -700, -500, -100, 100, 400, 600 } do
		BD.Car(parent, -1332, z, 0, BD.CarColors[(z // 100) % #BD.CarColors + 1], g, true)
		BD.Car(parent, -728, z + 30, math.pi, BD.CarColors[(z // 100 + 3) % #BD.CarColors + 1], g, true)
	end
	for _, p in { { -1240, -260 }, { -820, -260 }, { -1240, 160 }, { -820, 160 } } do
		BD.Ground(parent, "Lawn", p[1] - 22, p[1] + 22, p[2] - 22, p[2] + 22, 0.55, 0.2, Color3.fromRGB(86, 150, 74), "Grass")
	end
	BD.Cyl(parent, "FountainBasin", 2, 34, Vector3.new(tx, 1.3, 155), Color3.fromRGB(230, 226, 218), "Marble")
	BD.Cyl(parent, "FountainWater", 0.3, 31, Vector3.new(tx, 2.2, 155), Color3.fromRGB(90, 170, 220), "Glass")
	for i = 0, 15 do
		local angle = i / 16 * math.pi * 2
		BD.Tree(parent, tx + math.cos(angle) * 225, tz + math.sin(angle) * 225, 0.45, 1.6)
	end
	-- Gratte-ciel tout autour (certains plus hauts que les bureaux, d'autres bien plus bas).
	local glassColors = {
		Color3.fromRGB(70, 110, 140), Color3.fromRGB(110, 130, 150), Color3.fromRGB(50, 70, 100),
		Color3.fromRGB(150, 160, 170), Color3.fromRGB(90, 120, 110), Color3.fromRGB(150, 124, 92),
	}
	for i, t in {
		{ -1420, -200, 70, 70, 320 }, { -1450, 50, 60, 80, 240 }, { -1430, 160, 80, 60, 180 }, { -1420, -460, 70, 70, 280 },
		{ -1600, -100, 90, 90, 380 }, { -1620, 120, 70, 70, 150 }, { -1600, -520, 80, 60, 220 }, { -1450, 400, 80, 80, 260 }, { -1650, 420, 90, 70, 200 },
		{ -640, -200, 70, 70, 300 }, { -630, 60, 80, 60, 210 }, { -650, 170, 60, 60, 260 }, { -640, -470, 80, 80, 170 },
		{ -460, -50, 90, 90, 340 }, { -450, 150, 70, 70, 190 }, { -470, -440, 70, 70, 250 }, { -600, 420, 80, 80, 230 }, { -420, 450, 90, 90, 280 },
		{ -1200, -470, 80, 70, 260 }, { -1030, -520, 90, 80, 360 }, { -860, -470, 70, 70, 200 }, { -1120, -680, 100, 80, 300 }, { -920, -680, 80, 80, 230 },
		{ -1200, 360, 80, 70, 230 }, { -1030, 420, 90, 80, 290 }, { -860, 370, 70, 70, 180 }, { -1120, 600, 80, 80, 260 }, { -920, 600, 90, 70, 330 },
	} do
		BD.Tower(parent, t[1], t[2], t[3], t[4], t[5], glassColors[(i - 1) % #glassColors + 1], if i % 3 == 0 then Color3.fromRGB(220, 222, 226) else Color3.fromRGB(150, 156, 164))
	end
	collectObstacles = wasCollecting
end

---------------------------------------------------------------------------
-- Niveau 3 : siège social (bureaux de direction luxueux)
---------------------------------------------------------------------------
local HQ = {}
HQ.MinX, HQ.MaxX, HQ.MinZ, HQ.MaxZ = -1180, -880, -200, 100
HQ.WallHeight = 16
HQ.Floor = 200 -- les bureaux sont au dernier étage d'une tour : surface du sol à Y = 200
HQ.OldMinZ = -100 -- limite nord des pièces d'origine (mur épais vers la nouvelle rangée nord)

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
	-- Rebord doré visible tout autour, l'eau posée par-dessus (avant, le rebord cachait l'eau).
	cylinder(model, "BasinRim", 0.3, 14.6, Vector3.new(x, FLOOR_TOP + 1.7, z), COLORS.Gold, "Foil")
	local water = cylinder(model, "Water", 0.1, 13.2, Vector3.new(x, FLOOR_TOP + 1.9, z), Color3.fromRGB(90, 190, 240), "Glass")
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
	-- Une dalle lumineuse sur deux caissons (moins de pièces, même effet).
	for x = room.MinX + 5, room.MaxX - 5, 20 do
		for z = room.MinZ + 5, room.MaxZ - 5, 20 do
			block(parent, "CofferLight", Vector3.new(4, 0.1, 4), Vector3.new(x, CEILING_BOTTOM - 0.05, z), COLORS.Light, "Neon", { CanCollide = false, CastShadow = false, Transparency = 0.55 })
		end
	end
end

-- Rangée nord des bureaux (4 pièces derrière la suite du PDG, face aux baies vitrées).
function HQ.FurnishNorth(f, top)
	local index

	-- Département juridique : classeurs de couleur, dossiers, bureaux d'avocats.
	local legal = f.HLegal
	local binderCats = { "Finance", "Legal", "HR", "Marketing" }
	for i = 1, 8 do
		HQ.RecordsShelf(legal, 300 + i, -1181 + i * 8, -199.3, binderCats[(i - 1) % 4 + 1])
	end
	for i, x in { -1170, -1162, -1154, -1146 } do
		createArchiveShelf(legal, 300 + i, x, -178)
	end
	index = 300
	for _, x in { -1165, -1150, -1135, -1120 } do
		index += 1
		createAdvisorDesk(legal, index, x, -145)
	end
	createCredenza(legal, 301, -1106.2, -180)
	createCredenza(legal, 302, -1106.2, -168)
	block(legal, "LegalRug", Vector3.new(60, 0.04, 34), Vector3.new(-1142, FLOOR_TOP + 0.02, -145), Color3.fromRGB(150, 40, 46), "Fabric", { CanCollide = false })
	newSign(legal, "LegalSign", "LEGAL DEPARTMENT", Vector3.new(12, 1.6, 0.15), Vector3.new(-1142, FLOOR_TOP + 11, -101.1), Vector3.new(0, 0, -1), COLORS.Walnut, COLORS.Gold)
	createWallArt(legal, Vector3.new(-1105.35, FLOOR_TOP + 7, -150), Vector3.new(-1, 0, 0), Vector2.new(6, 4), Color3.fromRGB(60, 80, 110))
	Deco.Pendant(legal, -1142, top - 0.3, -165, 6, COLORS.Gold, true)
	Deco.Pendant(legal, -1142, top - 0.3, -125, 6, COLORS.Gold, true)
	for _, p in { { -1177, -104 }, { -1108, -194 } } do
		createPlant(legal, p[1], p[2])
	end

	-- Salon panoramique : bar le long de la vitre, coins canapés, tables, jardinières.
	local lounge = f.HSkyLounge
	for i, x in { -1097, -1090.5, -1084, -1077.5, -1071, -1064.5 } do
		createCupboard(lounge, 300 + i, x, -199.1)
	end
	index = 300
	for _, x in { -1055, -1045, -1035 } do
		index += 1
		createPlanter(lounge, index, x, -199)
	end
	for _, x in { -1092, -1076, -1058, -1040 } do
		index += 1
		createPlanter(lounge, index, x, -188)
	end
	index = 300
	for _, g in { { -1094, -172 }, { -1076, -172 }, { -1058, -172 }, { -1040, -172 }, { -1094, -152 }, { -1076, -152 }, { -1058, -152 }, { -1040, -152 }, { -1040, -132 } } do
		index += 1
		createSofa(lounge, index, g[1], g[2] - 3.6, math.pi)
		index += 1
		createSofa(lounge, index, g[1], g[2] + 3.6, 0)
		createCoffeeTable(lounge, g[1], g[2])
	end
	index = 300
	for _, p in { { -1076, -132 }, { -1058, -132 }, { -1094, -118 }, { -1076, -115 }, { -1058, -115 } } do
		index += 1
		createCafeTable(lounge, index, p[1], p[2])
	end
	newSign(lounge, "LoungeSign", "SKY LOUNGE", Vector3.new(10, 1.6, 0.15), Vector3.new(-1067, FLOOR_TOP + 11, -101.1), Vector3.new(0, 0, -1), COLORS.Walnut, COLORS.Gold)
	Deco.Pendant(lounge, -1067, top - 0.3, -162, 6, COLORS.Gold, true)
	Deco.Pendant(lounge, -1067, top - 0.3, -123, 6, COLORS.Gold, true)

	-- Studio marketing : murs de cadres, vitrines à trophées, tables de réunion, postes de travail.
	local studio = f.HMarketing
	index = 300
	for _, z in { -190, -181, -172 } do
		index += 1
		HQ.FrameShelf(studio, index, -1029.05, z, Vector3.new(1, 0, 0))
		index += 1
		HQ.FrameShelf(studio, index, -955.95, z, Vector3.new(-1, 0, 0))
	end
	HQ.TrophyCabinet(studio, 301, -1000, -199, Vector3.new(0, 0, 1))
	HQ.TrophyCabinet(studio, 302, -985, -199, Vector3.new(0, 0, 1))
	createConferenceTable(studio, 301, -1010, -172)
	createConferenceTable(studio, 302, -975, -172)
	createConferenceTable(studio, 303, -992.5, -152)
	index = 300
	for _, x in { -1020, -1008, -996, -984, -972 } do
		index += 1
		createHotDesk(studio, index, x, -128)
	end
	for i, p in { { -1028.8, -145 }, { -1028.8, -127 }, { -956.2, -145 }, { -956.2, -127 } } do
		createCredenza(studio, 300 + i, p[1], p[2])
	end
	newSign(studio, "CampaignScreen", "NEW CAMPAIGN: TIDY IS THE NEW BLACK", Vector3.new(10, 3.5, 0.15), Vector3.new(-1029.65, FLOOR_TOP + 9, -136), Vector3.new(1, 0, 0), COLORS.Black, Color3.fromRGB(255, 120, 170))
	Deco.Pendant(studio, -1000, top - 0.3, -172, 6, Color3.fromRGB(240, 120, 160), true)
	Deco.Pendant(studio, -985, top - 0.3, -128, 6, Color3.fromRGB(240, 120, 160), true)

	-- Labo d'innovation : chariots de portables, étagères de cartons, postes de travail, salle de démo.
	local lab = f.HLab
	index = 300
	for _, z in { -198.8, -186, -173 } do
		for _, x in { -949, -942, -935, -928, -921, -914, -907 } do
			if not (z == -173 and x == -907) then
				index += 1
				createLaptopCart(lab, index, x, z)
			end
		end
	end
	index = 300
	for _, z in { -197, -192, -187, -182, -177, -172, -167 } do
		index += 1
		createStorageShelf(lab, index, -885, z)
		if z < -172 then
			index += 1
			createStorageShelf(lab, index, -894.5, z)
		end
	end
	index = 320
	for _, z in { -150, -135 } do
		for _, x in { -948, -936, -924, -912, -900 } do
			index += 1
			createHotDesk(lab, index, x, z)
		end
	end
	createChairRug(lab, "DemoSeating", Vector2.new(-925, -115), Vector2.new(40, 14), { -942, -937, -932, -927, -922, -917, -912, -907 }, { -120, -116, -112, -108.5 }, 180, Color3.fromRGB(70, 90, 150), 6)
	for i = 0, 3 do
		createServerRack(lab, -882, -150 + i * 3.2)
	end
	newSign(lab, "LabScreen", "INNOVATION LAB  -  DEMO DAY FRIDAY", Vector3.new(10, 3.5, 0.15), Vector3.new(-954.65, FLOOR_TOP + 8, -158), Vector3.new(1, 0, 0), COLORS.Black, Color3.fromRGB(120, 220, 160))
	Deco.Pendant(lab, -925, top - 0.3, -186, 6, COLORS.DarkMetal, true)
	Deco.Pendant(lab, -925, top - 0.3, -128, 6, COLORS.DarkMetal, true)
end

function HQ.Build(root)
	local savedHeight = WALL_HEIGHT
	WALL_HEIGHT = HQ.WallHeight
	setFloor(HQ.Floor)
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
		HSkyLounge = { Color3.fromRGB(64, 58, 70), "WoodPlanks" },
		HLegal = { Color3.fromRGB(46, 70, 120), "Carpet" },
		HMarketing = { Color3.fromRGB(236, 230, 220), "Concrete" },
		HLab = { Color3.fromRGB(210, 214, 220), "SmoothPlastic" },
	}
	local rooms = TidyConfig.GetMapRooms("Headquarters")
	for _, room in rooms do
		local style = floors[room.Id]
		-- La rangée nord s'arrête au mur épais (Z = -101 à -100) qui la sépare des pièces d'origine.
		local roomMaxZ = if room.MinZ < HQ.OldMinZ then HQ.OldMinZ - 1 else room.MaxZ
		block(structure, room.Id .. "Floor", Vector3.new(room.MaxX - room.MinX, 1, roomMaxZ - room.MinZ), Vector3.new((room.MinX + room.MaxX) / 2, FLOOR_TOP - 0.5, (room.MinZ + roomMaxZ) / 2), style[1], style[2], { Reflectance = if style[2] == "Marble" then 0.08 else 0 })
	end
	-- Incrustations du hall : bordure noire et rosace dorée.
	block(structure, "LobbyInlay", Vector3.new(60, 0.02, 1), Vector3.new(-1030, FLOOR_TOP + 0.01, 30), Color3.fromRGB(40, 40, 46), "Marble", { CanCollide = false })
	local rosette = cylinder(structure, "LobbyRosette", 0.02, 10, Vector3.new(-1030, FLOOR_TOP + 0.01, 80), COLORS.Gold, "Foil")
	rosette.CanCollide = false

	-- Murs extérieurs : grandes baies vitrées du sol au plafond sur les côtés ouest, est et nord
	-- (vue sur la ville, 200 studs plus bas), façade dorée au sud avec les ascenseurs.
	local wallTop = top
	local slabBottom = FLOOR_TOP - 1
	AG.GlassWall(structure, "NorthFacade", true, minZ - 0.5, minX - 1, maxX + 1, slabBottom, Color3.fromRGB(60, 64, 74), 24)
	AG.GlassWall(structure, "WestFacade", false, minX - 0.5, minZ, maxZ + 1, slabBottom, Color3.fromRGB(60, 64, 74), 24)
	AG.GlassWall(structure, "EastFacade", false, maxX + 0.5, minZ, maxZ + 1, slabBottom, Color3.fromRGB(60, 64, 74), 24)
	-- Façade sud : verre et montants dorés, ascenseurs au milieu du hall.
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
		block(structure, "ElevatorDoor", Vector3.new(5, 9, 0.3), Vector3.new(doorX + side * 2.5, FLOOR_TOP + 4.5, maxZ + 0.6), COLORS.Metal, "Metal", { Reflectance = 0.15 })
	end
	block(structure, "ElevatorThreshold", Vector3.new(10, 1, 1), Vector3.new(doorX, FLOOR_TOP - 0.5, maxZ + 0.5), COLORS.DarkMetal, "Metal")
	newSign(structure, "SkyLobbySign", "SKY LOBBY  -  FLOOR 52", Vector3.new(9, 1.2, 0.1), Vector3.new(doorX, FLOOR_TOP + 11.6, maxZ - 0.06), Vector3.new(0, 0, -1), COLORS.Walnut, COLORS.Gold)

	-- Cloisons et portes (les portes des pièces fermées sont vitrées et verrouillées).
	local doors = {}
	local function door(from, to, room)
		local d = { From = from, To = to, Room = room }
		if room then
			table.insert(doors, d)
		end
		return d
	end
	interiorWallAlongZ(structure, -1080, HQ.OldMinZ, maxZ, { door(52, 60, "HOpenOffice"), door(-14, -6, "HTrophy"), door(-74, -66, "HExecutive") })
	interiorWallAlongZ(structure, -980, HQ.OldMinZ, maxZ, { door(52, 60, "HCafe"), door(-14, -6, "HBoard"), door(-74, -66, "HServer") })
	-- Ancien mur nord : mur épais vers la rangée nord (4 nouvelles pièces face à la ville).
	AG.Wall(structure, "OldNorthWall", true, HQ.OldMinZ - 0.5, minX, maxX, 1, { door(-1114, -1106, "HLegal"), door(-1052, -1044, "HSkyLounge"), door(-1016, -1008, "HMarketing"), door(-920, -912, "HLab") }, slabBottom, Color3.fromRGB(240, 232, 216), "Plaster")
	for _, x in { -1105, -1030, -955 } do
		interiorWallAlongZ(structure, x, minZ, HQ.OldMinZ - 1, {})
	end
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
		{ "LEGAL", Vector3.new(-1110, signY, -99.9), Vector3.new(0, 0, 1) },
		{ "SKY LOUNGE", Vector3.new(-1048, signY, -99.9), Vector3.new(0, 0, 1) },
		{ "MARKETING", Vector3.new(-1012, signY, -99.9), Vector3.new(0, 0, 1) },
		{ "INNOVATION LAB", Vector3.new(-916, signY, -99.9), Vector3.new(0, 0, 1) },
	} do
		newSign(structure, "RoomSign", sign[1], Vector3.new(8, 1.3, 0.1), sign[2], sign[3], COLORS.Walnut, COLORS.Gold)
	end

	-- Toit avec une grande verrière au-dessus de l'atrium.
	local holes = { { -1066, -994, -28, 8 } }
	slabWithHoles(structure, "Roof", minX - 1, maxX + 1, minZ - 1, maxZ + 1, top, 1, holes, COLORS.Ceiling, "SmoothPlastic")
	skylight(structure, holes[1], top + 1)
	for _, room in rooms do
		if room.Id == "HOpenOffice" or room.Id == "HCafe" or room.Id == "HServer" or room.Id == "HArchive" then
			-- Lattes de bois et bandeaux lumineux, avec peu de vraies lumières (performances).
			slatCeiling(structure, room.MinX, room.MaxX, room.MinZ, room.MaxZ, {}, {})
			AG.Strips(structure, room.MinX, room.MaxX, room.MinZ, room.MaxZ, 2)
		elseif room.MinZ < HQ.OldMinZ then
			AG.Panels(structure, room.MinX, room.MaxX, room.MinZ, room.MaxZ, 20)
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
	createFilingCabinet(archive, -1090, -99.9)
	createFilingCabinet(archive, -1087.9, -99.9)

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
	Deco.Wainscot(exec, Vector3.new(-1043.5, 0, -99.6), Vector3.new(-1016.5, 0, -99.6), Vector3.new(0, 0, 1), 3.5, COLORS.Walnut)

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

	-- Rangée nord (face à la ville) : département juridique, salon panoramique, studio marketing, labo.
	HQ.FurnishNorth(f, top)
	-- Tour sous les bureaux et quartier d'affaires autour (décor sans collision).
	BD.Headquarters(newFolder(root, "Backdrop"), HQ)

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
	titleLabel.Font = Enum.Font.FredokaOne
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
		line.Font = Enum.Font.FredokaOne
		line.Text = ""
		line.TextColor3 = Color3.fromRGB(240, 240, 240)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextScaled = true
		line.Parent = gui
	end
	return gui
end

---------------------------------------------------------------------------
-- Hall d'accueil (lobby intérieur) : verrière, fenêtres en arc, lambris, néons, palmiers,
-- mur des classements à l'entrée, 6 tapis de départ, boutique avec affiches et assistant.
---------------------------------------------------------------------------
local Hub = {}
Hub.Center = Vector3.new(0, 1, 690)
Hub.MinX, Hub.MaxX, Hub.MinZ, Hub.MaxZ = -60, 60, 630, 750
Hub.Robux = utf8.char(0xE002)

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

-- Petit utilitaire : texte d'interface avec contour épais (style titres de jeux Roblox).
local function guiText(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = props.Font or Enum.Font.FredokaOne
	label.Text = props.Text or ""
	label.TextColor3 = props.Color or Color3.new(1, 1, 1)
	label.Position = props.Position or UDim2.new()
	label.Size = props.Size or UDim2.fromScale(1, 1)
	label.TextXAlignment = props.AlignX or Enum.TextXAlignment.Center
	label.Name = props.Name or "Text"
	label.ZIndex = props.ZIndex or 2
	if props.Stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.Stroke
		stroke.Thickness = props.StrokeThickness or 3
		stroke.Parent = label
	end
	label.Parent = parent
	return label
end

local function corner(parent, scale)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0.2, 0)
	c.Parent = parent
	return c
end

-- Couleurs du hall (mêmes teintes que l'interface : bleu nuit, or, crème, vert menthe).
Hub.Navy = Color3.fromRGB(44, 46, 104)
Hub.NavyDark = Color3.fromRGB(28, 30, 70)
Hub.Gold = Color3.fromRGB(240, 190, 74)
Hub.Cream = Color3.fromRGB(248, 242, 230)
Hub.Mint = Color3.fromRGB(64, 232, 140)

-- Cadre arrondi d'interface (fond, coins, bord).
local function guiFrame(parent, props)
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Frame"
	frame.AnchorPoint = props.Anchor or Vector2.new(0, 0)
	frame.Position = props.Position or UDim2.new()
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = props.Color or Hub.Navy
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BorderSizePixel = 0
	frame.ZIndex = props.ZIndex or 1
	frame.Parent = parent
	corner(frame, props.Corner or 0.2)
	if props.Stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.Stroke
		stroke.Thickness = props.StrokeThickness or 4
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
	end
	if props.Gradient then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), props.Gradient)
		gradient.Rotation = 90
		gradient.Parent = frame
	end
	return frame
end

-- Surface d'affichage (texte net à toutes les distances).
local function surface(part, face, pixelsPerStud)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0
	gui.Parent = part
	return gui
end

-- Monument de classement : socle, colonnes bleu nuit à chapiteaux dorés, gemme lumineuse,
-- tableau sombre à bandeau doré et 10 lignes. Renvoie les lignes { Name, Value } mises à jour par le serveur.
function Hub.Monument(parent, name, x, z, facing, title, gemColor)
	local model = newModel(parent, name)
	local base = CFrame.lookAt(Vector3.new(x, FLOOR_TOP, z), Vector3.new(x, FLOOR_TOP, z) + facing)
	local function at(px, py, pz)
		return base * CFrame.new(px, py, pz)
	end
	newPart(model, "Plinth", Vector3.new(17, 1.2, 3), at(0, 0.6, 0), Hub.NavyDark, "SmoothPlastic")
	newPart(model, "PlinthTrim", Vector3.new(17.2, 0.2, 3.2), at(0, 1.25, 0), Hub.Gold, "Foil", { CanCollide = false })
	for _, side in { -1, 1 } do
		newPart(model, "Pillar", Vector3.new(1.6, 14.4, 2), at(side * 7.7, 8.4, 0), Hub.Navy, "SmoothPlastic")
		newPart(model, "PillarCap", Vector3.new(2.2, 0.5, 2.4), at(side * 7.7, 15.85, 0), Hub.Gold, "Foil", { CanCollide = false })
	end
	newPart(model, "Lintel", Vector3.new(17.4, 1.6, 2.4), at(0, 16.9, 0), Hub.Navy, "SmoothPlastic")
	newPart(model, "LintelTrim", Vector3.new(17.6, 0.25, 2.6), at(0, 16.05, 0), Hub.Gold, "Foil", { CanCollide = false })
	newPart(model, "GemHousing", Vector3.new(4.4, 3.6, 2.2), at(0, 19.4, 0), Hub.Gold, "Foil")
	local gem = newPart(model, "Gem", Vector3.new(2.8, 2.8, 2.8), at(0, 19.4, -0.6), gemColor, "Neon", { CanCollide = false, CastShadow = false })
	gem.Shape = Enum.PartType.Ball
	local board = newPart(model, "Board", Vector3.new(13.4, 13.6, 0.4), at(0, 8.6, -0.3), Hub.NavyDark, "SmoothPlastic", { CanCollide = false })
	local gui = surface(board, Enum.NormalId.Front, 40)
	gui.Name = "BoardGui"
	local header = guiFrame(gui, { Name = "Header", Position = UDim2.fromScale(0.04, 0.025), Size = UDim2.fromScale(0.92, 0.1), Color = Hub.Gold, Corner = 0.35, Gradient = Color3.fromRGB(220, 200, 170) })
	guiText(header, { Name = "Title", Text = title, Font = Enum.Font.FredokaOne, Color = Color3.fromRGB(255, 255, 255), Stroke = Color3.fromRGB(150, 96, 20), StrokeThickness = 4, Position = UDim2.fromScale(0.04, 0.12), Size = UDim2.fromScale(0.92, 0.76) })
	local rows = {}
	local medalColors = { Color3.fromRGB(255, 214, 90), Color3.fromRGB(214, 222, 240), Color3.fromRGB(232, 160, 100) }
	for i = 1, 10 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.Position = UDim2.fromScale(0.05, 0.145 + (i - 1) * 0.084)
		row.Size = UDim2.fromScale(0.9, 0.072)
		row.BackgroundColor3 = medalColors[i] or Color3.fromRGB(255, 255, 255)
		row.BackgroundTransparency = if i <= 3 then 0.75 else 0.9
		row.BorderSizePixel = 0
		row.Parent = gui
		corner(row, 0.4)
		guiText(row, { Name = "Rank", Text = "#" .. i, Font = Enum.Font.FredokaOne, Color = medalColors[i] or Color3.fromRGB(190, 196, 236), Position = UDim2.fromScale(0.02, 0.12), Size = UDim2.fromScale(0.13, 0.76) })
		local nameLabel = guiText(row, { Name = "PlayerName", Text = "---", Font = Enum.Font.BuilderSansBold, Color = Color3.fromRGB(255, 255, 255), AlignX = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.17, 0.12), Size = UDim2.fromScale(0.55, 0.76) })
		local valueLabel = guiText(row, { Name = "Value", Text = "", Font = Enum.Font.FredokaOne, Color = Color3.fromRGB(255, 220, 110), AlignX = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.72, 0.12), Size = UDim2.fromScale(0.25, 0.76) })
		rows[i] = { Name = nameLabel, Value = valueLabel }
	end
	return rows
end

-- Affiche d'un article Robux : cadre doré à arche, fond bleu nuit, badge rond, nom, prix vert.
function Hub.Poster(parent, entry, kind, x, z, badgeColor)
	local model = newModel(parent, "Poster_" .. entry.Id)
	block(model, "Stand", Vector3.new(6.4, 0.5, 1.6), Vector3.new(x, FLOOR_TOP + 0.25, z), Hub.NavyDark, "SmoothPlastic")
	block(model, "Frame", Vector3.new(7, 9.4, 0.6), Vector3.new(x, FLOOR_TOP + 5.2, z), Hub.Gold, "Foil")
	local arch = cylinder(model, "Arch", 0.6, 7, Vector3.new(x, FLOOR_TOP + 9.9, z), Hub.Gold, "Foil")
	arch.CFrame = CFrame.new(x, FLOOR_TOP + 9.9, z) * CFrame.Angles(0, math.rad(90), 0)
	local panel = block(model, "Panel", Vector3.new(6.2, 8.8, 0.2), Vector3.new(x, FLOOR_TOP + 5.3, z + 0.32), Hub.NavyDark, "SmoothPlastic", { CanCollide = false })
	local top = cylinder(model, "ArchPanel", 0.2, 6.2, Vector3.new(x, FLOOR_TOP + 9.9, z + 0.32), Hub.NavyDark, "SmoothPlastic")
	top.CFrame = CFrame.new(x, FLOOR_TOP + 9.9, z + 0.32) * CFrame.Angles(0, math.rad(90), 0)
	top.CanCollide = false
	local gui = surface(panel, Enum.NormalId.Back, 50)
	gui.Name = "PosterGui"
	local badge = guiFrame(gui, { Name = "Badge", Anchor = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.05), Size = UDim2.fromScale(0.64, 0.45), Color = badgeColor, Corner = 1, Stroke = Color3.fromRGB(255, 255, 255), StrokeThickness = 6, Gradient = Color3.fromRGB(150, 150, 170) })
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = badge
	guiText(badge, { Text = entry.Icon, Position = UDim2.fromScale(0.16, 0.16), Size = UDim2.fromScale(0.68, 0.68) })
	guiText(gui, { Name = "ItemName", Text = entry.Name, Font = Enum.Font.FredokaOne, Color = Color3.fromRGB(255, 255, 255), Stroke = Hub.NavyDark, StrokeThickness = 4, Position = UDim2.fromScale(0.05, 0.54), Size = UDim2.fromScale(0.9, 0.13) })
	guiText(gui, { Name = "Tag", Text = if kind == "Pass" then "GAME PASS" else "BOOST", Font = Enum.Font.BuilderSansExtraBold, Color = Hub.Gold, Position = UDim2.fromScale(0.1, 0.68), Size = UDim2.fromScale(0.8, 0.07) })
	local price = guiFrame(gui, { Name = "Price", Anchor = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.79), Size = UDim2.fromScale(0.78, 0.15), Color = Color3.fromRGB(62, 214, 112), Corner = 0.45, Stroke = Color3.fromRGB(24, 132, 66), StrokeThickness = 5, Gradient = Color3.fromRGB(200, 200, 210) })
	guiText(price, { Text = Hub.Robux .. " " .. entry.Price, Font = Enum.Font.FredokaOne, Color = Color3.fromRGB(255, 255, 255), Stroke = Color3.fromRGB(24, 132, 66), StrokeThickness = 4, Position = UDim2.fromScale(0.05, 0.1), Size = UDim2.fromScale(0.9, 0.8) })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Buy"
	prompt.ObjectText = entry.Name .. " - R$ " .. entry.Price
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ShopKind", kind)
	prompt:SetAttribute("ShopItem", entry.Id)
	prompt.Parent = panel
	return model
end

-- Fenêtre en arc (verre bleu ciel, montants blancs) posée contre un mur.
function Hub.ArchWindow(parent, x, z, facing, width, height)
	local model = newModel(parent, "ArchWindow")
	local base = CFrame.lookAt(Vector3.new(x, FLOOR_TOP, z), Vector3.new(x, FLOOR_TOP, z) + facing)
	local glass = Color3.fromRGB(180, 220, 255)
	local white = Color3.fromRGB(252, 250, 246)
	local bottom = 8
	newPart(model, "Glass", Vector3.new(width, height, 0.15), base * CFrame.new(0, bottom + height / 2, 0), glass, "Glass", { CanCollide = false, Transparency = 0.3, Reflectance = 0.2 })
	local archGlass = newPart(model, "ArchGlass", Vector3.new(0.15, width, width), base * CFrame.new(0, bottom + height, 0) * CFrame.Angles(0, math.rad(90), 0), glass, "Glass", { CanCollide = false, Transparency = 0.3, Reflectance = 0.2 })
	archGlass.Shape = Enum.PartType.Cylinder
	for _, side in { -1, 1 } do
		newPart(model, "FrameSide", Vector3.new(0.6, height, 0.4), base * CFrame.new(side * width / 2, bottom + height / 2, -0.1), white, "SmoothPlastic", { CanCollide = false })
	end
	newPart(model, "FrameSill", Vector3.new(width + 1.2, 0.6, 0.9), base * CFrame.new(0, bottom, -0.25), Hub.Gold, "Foil", { CanCollide = false })
	newPart(model, "Mullion", Vector3.new(0.3, height + width / 2, 0.3), base * CFrame.new(0, bottom + (height + width / 2) / 2, -0.1), white, "SmoothPlastic", { CanCollide = false })
	newPart(model, "Transom", Vector3.new(width, 0.3, 0.3), base * CFrame.new(0, bottom + height, -0.1), white, "SmoothPlastic", { CanCollide = false })
	return model
end

-- Plateforme de départ : disque menthe à anneau lumineux, grand numéro au sol,
-- panneau flottant (carte sombre) "Empty / Waiting for players / PLAY".
function Hub.QueuePad(parent, index, x, z, wallSide)
	local model = newModel(parent, "QueuePad" .. index)
	local diameter = 11
	local ring = cylinder(model, "PadRing", 0.3, diameter + 1.2, Vector3.new(x, FLOOR_TOP + 0.15, z), Hub.Mint, "Neon")
	ring.CanCollide = false
	local disk = cylinder(model, "PadDisk", 0.36, diameter, Vector3.new(x, FLOOR_TOP + 0.18, z), Color3.fromRGB(36, 150, 96), "SmoothPlastic")
	disk.CanCollide = false
	local pad = block(model, "Pad", Vector3.new(diameter - 1, 0.05, diameter - 1), Vector3.new(x, FLOOR_TOP + 0.4, z), Hub.Mint, "SmoothPlastic", { CanCollide = false, CastShadow = false, Transparency = 1 })
	pad:SetAttribute("QueueIndex", index)
	-- Numéro peint au sol.
	local numberGui = surface(pad, Enum.NormalId.Top, 30)
	guiText(numberGui, { Text = tostring(index), Font = Enum.Font.FredokaOne, Color = Color3.fromRGB(190, 255, 220), Position = UDim2.fromScale(0.2, 0.2), Size = UDim2.fromScale(0.6, 0.6) })
	local glow = Instance.new("PointLight")
	glow.Color = Hub.Mint
	glow.Range = 12
	glow.Brightness = lampPower(0.5)
	glow.Parent = disk
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Rate = 3
	sparkles.Lifetime = NumberRange.new(1.2, 2)
	sparkles.Speed = NumberRange.new(1.5, 3)
	sparkles.SpreadAngle = Vector2.new(25, 25)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Color = ColorSequence.new(Hub.Mint)
	sparkles.Size = NumberSequence.new(0.22)
	sparkles.LightEmission = 0.8
	sparkles.Parent = pad
	Hub.ArchWindow(model, wallSide * (Hub.MaxX - 0.2), z, Vector3.new(-wallSide, 0, 0), 9, 9)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "QueueBillboard"
	billboard.Adornee = pad
	billboard.Size = UDim2.fromScale(10, 5.4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 7.5, 0)
	billboard.MaxDistance = 140
	billboard.LightInfluence = 0
	billboard.Parent = model
	guiFrame(billboard, { Name = "Card", Size = UDim2.fromScale(1, 0.62), Color = Hub.NavyDark, Transparency = 0.12, Corner = 0.25, Stroke = Color3.fromRGB(255, 255, 255), StrokeThickness = 2, ZIndex = 1 })
	local title = guiText(billboard, { Name = "Title", Text = "Empty", Font = Enum.Font.FredokaOne, Color = Color3.fromRGB(255, 255, 255), Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.3), ZIndex = 2 })
	local status = guiText(billboard, { Name = "Status", Text = "Waiting for players", Font = Enum.Font.BuilderSansBold, Color = Color3.fromRGB(190, 196, 236), Position = UDim2.fromScale(0.05, 0.34), Size = UDim2.fromScale(0.9, 0.22), ZIndex = 2 })
	local play = guiFrame(billboard, { Name = "PlayPill", Anchor = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromScale(0.5, 0.3), Color = Color3.fromRGB(62, 214, 112), Corner = 0.5, Stroke = Color3.fromRGB(24, 132, 66), StrokeThickness = 3, Gradient = Color3.fromRGB(200, 200, 210), ZIndex = 1 })
	guiText(billboard, { Name = "Play", Text = "PLAY", Font = Enum.Font.FredokaOne, Color = Color3.fromRGB(255, 255, 255), Stroke = Color3.fromRGB(24, 132, 66), StrokeThickness = 2, Position = UDim2.fromScale(0.25, 0.71), Size = UDim2.fromScale(0.5, 0.24), ZIndex = 3 })
	return { Index = index, Pad = pad, Center = Vector3.new(x, FLOOR_TOP, z), Radius = 5.2, Title = title, Status = status }
end

-- Grand logo du jeu (plaque bleu nuit à bord doré, texte blanc et jaune).
function Hub.Logo(parent, x, y, z, width)
	local height = width * 0.3
	local plaque = block(parent, "LogoPlaque", Vector3.new(width, height, 0.4), Vector3.new(x, y, z), Hub.NavyDark, "SmoothPlastic", { CanCollide = false, Transparency = 1 })
	local gui = surface(plaque, Enum.NormalId.Back, 24)
	gui.Name = "LogoGui"
	local card = guiFrame(gui, { Name = "Card", Color = Hub.Navy, Corner = 0.18, Stroke = Hub.Gold, StrokeThickness = 10, Gradient = Color3.fromRGB(120, 120, 160) })
	local fullTitle = string.upper(TidyConfig.GameTitle)
	local first, second = string.match(fullTitle, "^(.-!)%s*(.*)$")
	if not first then
		first, second = fullTitle, ""
	end
	local main = guiText(card, { Name = "Title", Text = first, Font = Enum.Font.FredokaOne, Color = Color3.fromRGB(255, 226, 92), Stroke = Color3.fromRGB(120, 60, 0), StrokeThickness = 10, Position = UDim2.fromScale(0.05, 0.06), Size = UDim2.fromScale(0.9, 0.58) })
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 190, 60))
	shine.Rotation = 90
	shine.Parent = main
	guiText(card, { Name = "Subtitle", Text = second, Font = Enum.Font.FredokaOne, Color = Color3.fromRGB(255, 255, 255), Stroke = Hub.NavyDark, StrokeThickness = 6, Position = UDim2.fromScale(0.1, 0.64), Size = UDim2.fromScale(0.8, 0.28) })
	return plaque
end

-- Enseigne lumineuse (lettres blanches contour vert sur fond transparent).
function Hub.SignText(parent, name, text, size, position, color, strokeColor)
	local part = block(parent, name, size, position, Color3.new(1, 1, 1), "SmoothPlastic", { CanCollide = false, Transparency = 1 })
	local gui = surface(part, Enum.NormalId.Back, 30)
	guiText(gui, { Text = text, Font = Enum.Font.FredokaOne, Color = color, Stroke = strokeColor, StrokeThickness = 8 })
	return part
end

-- Décor vivant du hall : jardinières fleuries entre les plateformes, deux coins salon,
-- tableau "WHAT'S NEW" près de l'entrée. Peu de pièces, aucune lumière en plus.
function Hub.Planter(parent, x, z, alongZ)
	local model = newModel(parent, "FlowerPlanter")
	local length = 7
	local size = if alongZ then Vector3.new(2.4, 2, length) else Vector3.new(length, 2, 2.4)
	block(model, "Box", size, Vector3.new(x, FLOOR_TOP + 1, z), Hub.Navy, "SmoothPlastic")
	block(model, "Rim", size + Vector3.new(0.3, -1.75, 0.3), Vector3.new(x, FLOOR_TOP + 2.05, z), Hub.Gold, "Foil", { CanCollide = false })
	block(model, "Soil", size - Vector3.new(0.4, 1.9, 0.4), Vector3.new(x, FLOOR_TOP + 2.0, z), Color3.fromRGB(96, 66, 44), "Ground", { CanCollide = false })
	local flowers = { Color3.fromRGB(255, 94, 170), Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 106, 255) }
	for k = 0, 4 do
		local t = (k - 2) / 2.3
		local px = if alongZ then x else x + t * length / 2
		local pz = if alongZ then z + t * length / 2 else z
		local bush = block(model, "Bush", Vector3.new(1.7, 1.7, 1.7), Vector3.new(px, FLOOR_TOP + 2.6, pz), Color3.fromRGB(70, 160, 80), "Grass", { CanCollide = false })
		bush.Shape = Enum.PartType.Ball
		for f = 0, 1 do
			local flower = block(model, "Flower", Vector3.new(0.45, 0.45, 0.45), Vector3.new(px + (f - 0.5) * 0.7, FLOOR_TOP + 3.35, pz + (0.5 - f) * 0.5), flowers[(k + f) % #flowers + 1], "SmoothPlastic", { CanCollide = false, CastShadow = false })
			flower.Shape = Enum.PartType.Ball
		end
	end
	return model
end

function Hub.Lounge(parent, cx, cz)
	local model = newModel(parent, "Lounge")
	local rug = cylinder(model, "Rug", 0.06, 14, Vector3.new(cx, FLOOR_TOP + 0.03, cz), Hub.Navy, "Fabric")
	rug.CanCollide = false
	local rugEdge = cylinder(model, "RugEdge", 0.05, 14.8, Vector3.new(cx, FLOOR_TOP + 0.025, cz), Hub.Gold, "Fabric")
	rugEdge.CanCollide = false
	-- Table basse ronde.
	cylinder(model, "TableTop", 0.3, 4, Vector3.new(cx, FLOOR_TOP + 1.6, cz), Hub.Cream, "Marble")
	cylinder(model, "TableFoot", 1.4, 0.6, Vector3.new(cx, FLOOR_TOP + 0.75, cz), Hub.Gold, "Foil")
	local vase = cylinder(model, "Vase", 0.9, 0.6, Vector3.new(cx, FLOOR_TOP + 2.2, cz), Color3.fromRGB(72, 154, 255), "Glass")
	vase.CanCollide = false
	-- Deux fauteuils face à face.
	for _, side in { -1, 1 } do
		local x = cx + side * 4.6
		local seatColor = Color3.fromRGB(150, 106, 255)
		block(model, "ChairBase", Vector3.new(3, 1.4, 3), Vector3.new(x, FLOOR_TOP + 0.7, cz), seatColor:Lerp(Color3.new(0, 0, 0), 0.25), "Fabric")
		block(model, "ChairSeat", Vector3.new(2.8, 0.5, 2.8), Vector3.new(x, FLOOR_TOP + 1.65, cz), seatColor, "Fabric")
		block(model, "ChairBack", Vector3.new(0.7, 2.2, 3), Vector3.new(x + side * 1.2, FLOOR_TOP + 2.4, cz), seatColor:Lerp(Color3.new(0, 0, 0), 0.1), "Fabric")
		for _, arm in { -1, 1 } do
			block(model, "ChairArm", Vector3.new(2.6, 1.2, 0.5), Vector3.new(x, FLOOR_TOP + 2, cz + arm * 1.3), seatColor:Lerp(Color3.new(0, 0, 0), 0.15), "Fabric")
		end
	end
	-- Lampadaire.
	cylinder(model, "LampFoot", 0.2, 1.4, Vector3.new(cx, FLOOR_TOP + 0.1, cz - 6), Hub.NavyDark, "Metal")
	cylinder(model, "LampPole", 6, 0.2, Vector3.new(cx, FLOOR_TOP + 3.1, cz - 6), Hub.Gold, "Foil")
	cylinder(model, "LampShade", 1.4, 2, Vector3.new(cx, FLOOR_TOP + 6.5, cz - 6), Hub.Cream, "Fabric")
	return model
end

function Hub.NewsBoard(parent, x, z)
	local model = newModel(parent, "NewsBoard")
	for _, side in { -1, 1 } do
		block(model, "Leg", Vector3.new(0.4, 6, 0.4), Vector3.new(x + side * 3.4, FLOOR_TOP + 3, z), Hub.NavyDark, "SmoothPlastic")
	end
	local board = block(model, "Board", Vector3.new(7.6, 5, 0.4), Vector3.new(x, FLOOR_TOP + 5, z), Hub.Navy, "SmoothPlastic")
	block(model, "Frame", Vector3.new(7.9, 5.3, 0.3), Vector3.new(x, FLOOR_TOP + 5, z + 0.1), Hub.Gold, "Foil", { CanCollide = false })
	local gui = surface(board, Enum.NormalId.Front, 40)
	guiText(gui, { Text = "WHAT'S NEW", Font = Enum.Font.FredokaOne, Color = Color3.fromRGB(255, 226, 92), Stroke = Hub.NavyDark, StrokeThickness = 3, Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.2) })
	local lines = { "🏭  Start in the Warehouse", "🔓  Finish a level to unlock the next", "🏙️  Corporate Offices: top of the tower!", "🧲  Buy the Magnet in Upgrades" }
	for i, text in lines do
		guiText(gui, { Text = text, Font = Enum.Font.BuilderSansBold, Color = Color3.fromRGB(255, 255, 255), AlignX = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.07, 0.28 + (i - 1) * 0.17), Size = UDim2.fromScale(0.86, 0.13) })
	end
	return model
end

function Hub.Decorate(parent, minX, maxX, minZ, maxZ)
	for _, side in { -1, 1 } do
		for _, z in { minZ + 45, minZ + 75 } do
			Hub.Planter(parent, side * (maxX - 2.6), z, true)
		end
		Hub.Lounge(parent, side * 27, maxZ - 30)
	end
	Hub.NewsBoard(parent, -11, maxZ - 4.5)
end

function Hub.Build(root)
	setFloor(1)
	local minX, maxX, minZ, maxZ = Hub.MinX, Hub.MaxX, Hub.MinZ, Hub.MaxZ
	local cx, cz = 0, (minZ + maxZ) / 2
	local width, depth = maxX - minX, maxZ - minZ
	local wallTop = 26
	local structure = newFolder(root, "HallStructure")
	local decor = newFolder(root, "HallDecor")

	-- Sol en damier (crème et lavande), dalle sous le damier.
	block(structure, "HallFloor", Vector3.new(width, 1, depth), Vector3.new(cx, FLOOR_TOP - 0.6, cz), Hub.Cream, "SmoothPlastic")
	local tile = 10
	local tileA, tileB = Color3.fromRGB(244, 238, 226), Color3.fromRGB(222, 216, 240)
	for i = 0, math.floor(width / tile) - 1 do
		for j = 0, math.floor(depth / tile) - 1 do
			local color = if (i + j) % 2 == 0 then tileA else tileB
			block(structure, "FloorTile", Vector3.new(tile, 0.1, tile), Vector3.new(minX + tile / 2 + i * tile, FLOOR_TOP - 0.05, minZ + tile / 2 + j * tile), color, "SmoothPlastic", { Reflectance = 0.06 })
		end
	end
	-- Rosace autour de la fontaine.
	for _, ringData in { { 30, Hub.Navy, 0.02 }, { 28.6, Hub.Gold, 0.03 }, { 27.4, Hub.Cream, 0.04 } } do
		local disk = cylinder(structure, "Rosette", ringData[3], ringData[1], Vector3.new(cx, FLOOR_TOP + ringData[3] / 2, cz), ringData[2], "SmoothPlastic")
		disk.CanCollide = false
	end
	-- Tapis bleu nuit à bords dorés de l'entrée jusqu'à la fontaine.
	block(structure, "Runner", Vector3.new(10, 0.06, 40), Vector3.new(cx, FLOOR_TOP + 0.03, maxZ - 20), Hub.Navy, "Fabric", { CanCollide = false })
	for _, side in { -1, 1 } do
		block(structure, "RunnerEdge", Vector3.new(0.5, 0.07, 40), Vector3.new(cx + side * 5, FLOOR_TOP + 0.035, maxZ - 20), Hub.Gold, "SmoothPlastic", { CanCollide = false })
	end

	-- Murs : soubassement bleu nuit, liseré doré, enduit crème, corniche blanche.
	local function wall(name, size, position)
		local low = 6
		block(structure, name .. "Low", Vector3.new(size.X, low + FLOOR_TOP, size.Z), Vector3.new(position.X, (low + FLOOR_TOP) / 2, position.Z), Hub.Navy, "SmoothPlastic")
		block(structure, name .. "High", Vector3.new(size.X, wallTop - low - FLOOR_TOP, size.Z), Vector3.new(position.X, low + FLOOR_TOP + (wallTop - low - FLOOR_TOP) / 2, position.Z), Hub.Cream, "Plaster")
	end
	wall("NorthWall", Vector3.new(width + 2, 0, 1), Vector3.new(cx, 0, minZ - 0.5))
	wall("WestWall", Vector3.new(1, 0, depth), Vector3.new(minX - 0.5, 0, cz))
	wall("EastWall", Vector3.new(1, 0, depth), Vector3.new(maxX + 0.5, 0, cz))
	for _, piece in { { minX - 1, -7 }, { 7, maxX + 1 } } do
		wall("SouthWall", Vector3.new(piece[2] - piece[1], 0, 1), Vector3.new((piece[1] + piece[2]) / 2, 0, maxZ + 0.5))
	end
	block(structure, "EntranceLintel", Vector3.new(14, wallTop - FLOOR_TOP - 12, 1), Vector3.new(0, FLOOR_TOP + 12 + (wallTop - FLOOR_TOP - 12) / 2, maxZ + 0.5), Hub.Cream, "Plaster")
	block(structure, "EntranceFrame", Vector3.new(15, 0.8, 1.4), Vector3.new(0, FLOOR_TOP + 12.4, maxZ + 0.3), Hub.Gold, "Foil", { CanCollide = false })
	for _, side in { -1, 1 } do
		block(structure, "EntranceDoor", Vector3.new(6.9, 12, 0.3), Vector3.new(side * 3.5, FLOOR_TOP + 6, maxZ + 0.7), Color3.fromRGB(180, 220, 255), "Glass", { Transparency = 0.45 })
	end
	local railY = FLOOR_TOP + 6
	for _, line in {
		{ Vector3.new(width, 0.5, 0.3), Vector3.new(cx, railY, minZ + 0.15) },
		{ Vector3.new(0.3, 0.5, depth), Vector3.new(minX + 0.15, railY, cz) },
		{ Vector3.new(0.3, 0.5, depth), Vector3.new(maxX - 0.15, railY, cz) },
		{ Vector3.new(width, 0.5, 0.3), Vector3.new(cx, railY, maxZ - 0.15) },
		{ Vector3.new(width, 0.8, 0.6), Vector3.new(cx, wallTop - 0.4, minZ + 0.3) },
		{ Vector3.new(0.6, 0.8, depth), Vector3.new(minX + 0.3, wallTop - 0.4, cz) },
		{ Vector3.new(0.6, 0.8, depth), Vector3.new(maxX - 0.3, wallTop - 0.4, cz) },
		{ Vector3.new(width, 0.8, 0.6), Vector3.new(cx, wallTop - 0.4, maxZ - 0.3) },
	} do
		local isRail = line[2].Y < wallTop - 1
		block(structure, if isRail then "GoldRail" else "Cornice", line[1], line[2], if isRail then Hub.Gold else Color3.fromRGB(255, 255, 255), if isRail then "Foil" else "SmoothPlastic", { CanCollide = false })
	end
	-- Pilastres crème à chapiteau doré le long des murs est et ouest (rythme régulier).
	for _, side in { -1, 1 } do
		for _, z in { minZ + 15, minZ + 45, minZ + 75, minZ + 105 } do
			block(decor, "Pilaster", Vector3.new(0.8, wallTop - FLOOR_TOP - 1, 2.6), Vector3.new(side * (maxX - 0.4), FLOOR_TOP + (wallTop - FLOOR_TOP - 1) / 2, z), Color3.fromRGB(255, 252, 246), "SmoothPlastic", { CanCollide = false })
			block(decor, "PilasterCap", Vector3.new(1.2, 0.6, 3.2), Vector3.new(side * (maxX - 0.6), wallTop - 1.6, z), Hub.Gold, "Foil", { CanCollide = false })
		end
	end

	-- Plafond blanc avec une grande verrière à caissons au centre.
	local skylight = 56
	local ceilingY = wallTop + 0.5
	local sideWidth = (width - skylight) / 2
	local sideDepth = (depth - skylight) / 2
	block(structure, "Ceiling", Vector3.new(sideWidth, 1, depth), Vector3.new(minX + sideWidth / 2, ceilingY, cz), Color3.fromRGB(252, 250, 246), "SmoothPlastic")
	block(structure, "Ceiling", Vector3.new(sideWidth, 1, depth), Vector3.new(maxX - sideWidth / 2, ceilingY, cz), Color3.fromRGB(252, 250, 246), "SmoothPlastic")
	block(structure, "Ceiling", Vector3.new(skylight, 1, sideDepth), Vector3.new(cx, ceilingY, minZ + sideDepth / 2), Color3.fromRGB(252, 250, 246), "SmoothPlastic")
	block(structure, "Ceiling", Vector3.new(skylight, 1, sideDepth), Vector3.new(cx, ceilingY, maxZ - sideDepth / 2), Color3.fromRGB(252, 250, 246), "SmoothPlastic")
	block(structure, "SkylightGlass", Vector3.new(skylight, 0.3, skylight), Vector3.new(cx, ceilingY + 3.5, cz), Color3.fromRGB(200, 230, 255), "Glass", { Transparency = 0.55, CastShadow = false })
	for k = 0, 4 do
		local offset = -skylight / 2 + k * skylight / 4
		block(structure, "SkylightBeam", Vector3.new(0.8, 3.6, skylight), Vector3.new(cx + offset, ceilingY + 1.7, cz), Color3.fromRGB(255, 255, 255), "SmoothPlastic", { CanCollide = false, CastShadow = false })
		block(structure, "SkylightBeam", Vector3.new(skylight, 3.6, 0.8), Vector3.new(cx, ceilingY + 1.7, cz + offset), Color3.fromRGB(255, 255, 255), "SmoothPlastic", { CanCollide = false, CastShadow = false })
	end
	-- Bandeaux lumineux doux le long du plafond (au lieu de dizaines de lampes).
	for _, side in { -1, 1 } do
		block(structure, "CeilingGlow", Vector3.new(1.2, 0.1, depth - 20), Vector3.new(side * (skylight / 2 + sideWidth / 2), ceilingY - 0.55, cz), Color3.fromRGB(255, 244, 224), "Neon", { CanCollide = false, CastShadow = false, Transparency = 0.35 })
	end
	for _, p in { { -26, minZ + 26 }, { 26, minZ + 26 }, { -26, maxZ - 26 }, { 26, maxZ - 26 } } do
		local holder = block(structure, "HallLight", Vector3.new(0.2, 0.2, 0.2), Vector3.new(p[1], wallTop - 4, p[2]), Color3.new(1, 1, 1), "SmoothPlastic", { CanCollide = false, CastShadow = false, Transparency = 1 })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 236, 210)
		light.Range = 40
		light.Brightness = lampPower(0.7)
		light.Parent = holder
	end
	Deco.Chandelier(decor, cx, ceilingY + 3.3, cz, 2.4)

	-- Fontaine au centre, bancs autour, palmiers dans les coins.
	HQ.Fountain(decor, cx, cz)
	for _, p in { { -17, cz }, { 17, cz } } do
		createBench(decor, p[1], p[2])
	end
	for _, p in { { minX + 6, minZ + 6 }, { maxX - 6, minZ + 6 }, { minX + 6, maxZ - 6 }, { maxX - 6, maxZ - 6 } } do
		Deco.Palm(decor, p[1], p[2], 1.2)
	end

	-- Boutique (mur nord) : logo du jeu, enseigne SHOP, comptoir bleu nuit et or, affiches des articles.
	Hub.Logo(decor, cx, FLOOR_TOP + 19.5, minZ + 0.3, 30)
	local shop = newModel(decor, "Shop")
	local counter = block(shop, "Counter", Vector3.new(16, 3.8, 3.6), Vector3.new(cx, FLOOR_TOP + 1.9, minZ + 6), Hub.Navy, "SmoothPlastic")
	block(shop, "CounterTop", Vector3.new(16.6, 0.4, 4.2), Vector3.new(cx, FLOOR_TOP + 4, minZ + 6), Hub.Cream, "Marble")
	block(shop, "CounterTrim", Vector3.new(16.2, 0.3, 3.8), Vector3.new(cx, FLOOR_TOP + 3.3, minZ + 6), Hub.Gold, "Foil", { CanCollide = false })
	local front = block(shop, "CounterFront", Vector3.new(12, 2, 0.1), Vector3.new(cx, FLOOR_TOP + 1.8, minZ + 7.85), Hub.NavyDark, "SmoothPlastic", { CanCollide = false })
	local frontGui = surface(front, Enum.NormalId.Back, 30)
	guiText(frontGui, { Text = "🛒  OPEN SHOP", Font = Enum.Font.FredokaOne, Color = Color3.fromRGB(255, 226, 92), Position = UDim2.fromScale(0.05, 0.12), Size = UDim2.fromScale(0.9, 0.76) })
	-- Écran de caisse.
	block(shop, "RegisterStand", Vector3.new(0.4, 1.4, 0.4), Vector3.new(cx + 5, FLOOR_TOP + 4.9, minZ + 5.6), COLORS.DarkMetal, "Metal", { CanCollide = false })
	local screen = block(shop, "RegisterScreen", Vector3.new(3, 2, 0.3), Vector3.new(cx + 5, FLOOR_TOP + 6.4, minZ + 5.6), Hub.NavyDark, "SmoothPlastic", { CanCollide = false })
	local screenGui = surface(screen, Enum.NormalId.Back, 50)
	local screenBg = guiFrame(screenGui, { Position = UDim2.fromScale(0.05, 0.07), Size = UDim2.fromScale(0.9, 0.86), Color = Color3.fromRGB(72, 154, 255), Corner = 0.12, Gradient = Color3.fromRGB(160, 160, 200) })
	guiText(screenBg, { Text = Hub.Robux, Font = Enum.Font.FredokaOne, Position = UDim2.fromScale(0.2, 0.1), Size = UDim2.fromScale(0.6, 0.8) })
	-- Cercle lumineux au sol devant le comptoir.
	local ring = cylinder(shop, "ShopRing", 0.1, 13, Vector3.new(cx, FLOOR_TOP + 0.05, minZ + 12), Hub.Gold, "Neon")
	ring.CanCollide = false
	ring.Transparency = 0.25
	local ringInner = cylinder(shop, "ShopRingInner", 0.12, 12, Vector3.new(cx, FLOOR_TOP + 0.06, minZ + 12), Hub.NavyDark, "SmoothPlastic")
	ringInner.CanCollide = false
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "ShopPrompt"
	shopPrompt.ActionText = "Open Shop"
	shopPrompt.ObjectText = "Shop"
	shopPrompt.HoldDuration = 0
	shopPrompt.MaxActivationDistance = 12
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = counter
	Hub.SignText(shop, "ShopSign", "SHOP", Vector3.new(18, 5, 0.2), Vector3.new(cx, FLOOR_TOP + 10, minZ + 0.35), Color3.fromRGB(255, 255, 255), Color3.fromRGB(24, 132, 66))
	local featured = {
		{ "Product", TidyConfig.GetProduct("Deal"), Color3.fromRGB(255, 94, 170) },
		{ "Pass", TidyConfig.GetPass("Carry15"), Color3.fromRGB(72, 154, 255) },
		{ "Pass", TidyConfig.GetPass("DoublePoints"), Color3.fromRGB(62, 214, 112) },
		{ "Pass", TidyConfig.GetPass("InfiniteMagnet"), Color3.fromRGB(255, 80, 96) },
		{ "Pass", TidyConfig.GetPass("VIP"), Color3.fromRGB(255, 200, 64) },
		{ "Product", TidyConfig.GetProduct("Helper"), Color3.fromRGB(150, 106, 255) },
	}
	local posterX = { -46, -34, -22, 22, 34, 46 }
	for i, f in featured do
		if f[2] then
			Hub.Poster(decor, f[2], f[1], posterX[i], minZ + 1.2, f[3])
		end
	end

	-- Plateformes de départ le long des murs est et ouest, sous des fenêtres en arc.
	local pads = {}
	local index = 0
	for _, side in { -1, 1 } do
		for _, z in { minZ + 30, minZ + 60, minZ + 90 } do
			index += 1
			table.insert(pads, Hub.QueuePad(decor, index, side * (maxX - 10), z, side))
		end
	end
	
	-- Mur des classements à l'entrée (de chaque côté de la porte).
	local boards = {}
	local monuments = {
		{ "Wins", -44, "TOP WINS", Color3.fromRGB(110, 240, 230) },
		{ "Agency", -24, "AGENCY  FASTEST", Color3.fromRGB(200, 120, 255) },
		{ "Warehouse", 24, "WAREHOUSE  FASTEST", Color3.fromRGB(255, 90, 100) },
		{ "Headquarters", 44, "HQ  FASTEST", Color3.fromRGB(90, 140, 255) },
	}
	for _, m in monuments do
		boards[m[1]] = Hub.Monument(decor, "Leaderboard_" .. m[1], m[2], maxZ - 2, Vector3.new(0, 0, -1), m[3], m[4])
	end

	-- Un peu de vie : jardinières fleuries, coins salon, tableau des nouveautés.
	Hub.Decorate(decor, minX, maxX, minZ, maxZ)

	-- Borne "rejoindre un ami" près de l'entrée.
	local kiosk = newModel(decor, "JoinKiosk")
	block(kiosk, "KioskBase", Vector3.new(3, 0.8, 2), Vector3.new(11, FLOOR_TOP + 0.4, maxZ - 4), Hub.NavyDark, "SmoothPlastic")
	local kioskBody = block(kiosk, "KioskBody", Vector3.new(2.4, 5, 1.4), Vector3.new(11, FLOOR_TOP + 3.3, maxZ - 4), Hub.Navy, "SmoothPlastic")
	block(kiosk, "KioskTrim", Vector3.new(2.6, 0.3, 1.6), Vector3.new(11, FLOOR_TOP + 5.9, maxZ - 4), Hub.Gold, "Foil", { CanCollide = false })
	local kioskScreen = block(kiosk, "KioskScreen", Vector3.new(2, 2.4, 0.1), Vector3.new(11, FLOOR_TOP + 4, maxZ - 4.75), Color3.fromRGB(72, 154, 255), "SmoothPlastic", { CanCollide = false })
	local kioskGui = surface(kioskScreen, Enum.NormalId.Front, 60)
	guiText(kioskGui, { Text = "🤝", Position = UDim2.fromScale(0.15, 0.05), Size = UDim2.fromScale(0.7, 0.5) })
	guiText(kioskGui, { Text = "JOIN A FRIEND", Font = Enum.Font.FredokaOne, Color = Color3.fromRGB(255, 255, 255), Stroke = Hub.NavyDark, StrokeThickness = 3, Position = UDim2.fromScale(0.05, 0.6), Size = UDim2.fromScale(0.9, 0.3) })
	local kioskPrompt = Instance.new("ProximityPrompt")
	kioskPrompt.Name = "JoinPrompt"
	kioskPrompt.ActionText = "Enter a code"
	kioskPrompt.ObjectText = "Join a friend"
	kioskPrompt.HoldDuration = 0
	kioskPrompt.MaxActivationDistance = 10
	kioskPrompt.RequiresLineOfSight = false
	kioskPrompt.Parent = kioskBody

	local spawn = createSpawn(root, "HubSpawn", Vector3.new(0, FLOOR_TOP, maxZ - 10))
	return spawn, pads, boards
end

---------------------------------------------------------------------------
-- Fonctions principales
---------------------------------------------------------------------------
local itemsFolder = nil
local currentItems = {}
local currentMap = nil

-- Limites de chaque niveau (pour lâcher les objets à l'intérieur).
local MAP_BOUNDS = {
	Agency = { -HALF_X, AG.MaxX, MIN_Z, MAX_Z }, -- avec l'aile est
	Warehouse = { WH.MinX, WH.MaxX, WH.MinZ, WH.MaxZ },
	Headquarters = { HQ.MinX, HQ.MaxX, HQ.MinZ, HQ.MaxZ },
}

-- Grand panneau sur pieds (14 x 10 studs) à quelques pas du point d'arrivée, tourné vers lui.
-- Réglages par niveau : distance devant l'arrivée et décalage sur le côté (pour éviter les meubles).
AG.TutorialSpots = {
	Warehouse = { Distance = 14, Side = -16 },
	Agency = { Distance = 9, Side = -18 },
	Headquarters = { Distance = 10, Side = 0 },
}
function AG.TutorialBoard(root, mapId, spawnPosition)
	local bounds = MAP_BOUNDS[mapId]
	local center = Vector3.new((bounds[1] + bounds[2]) / 2, spawnPosition.Y, (bounds[3] + bounds[4]) / 2)
	local toward = center - spawnPosition
	local dir = if math.abs(toward.X) > math.abs(toward.Z) then Vector3.new(math.sign(toward.X), 0, 0) else Vector3.new(0, 0, math.sign(toward.Z))
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local spot = AG.TutorialSpots[mapId] or { Distance = 10, Side = 0 }
	local base = Vector3.new(spawnPosition.X, spawnPosition.Y, spawnPosition.Z) + dir * spot.Distance + right * spot.Side
	local floorY = spawnPosition.Y
	local model = newModel(root, "TutorialStand")
	local facing = CFrame.lookAt(base, base - dir)
	for _, offset in { -6, 6 } do
		newPart(model, "Leg", Vector3.new(0.5, 11.5, 0.5), facing * CFrame.new(offset, 5.75, 0.45), Color3.fromRGB(28, 30, 70), "SmoothPlastic")
		newPart(model, "Foot", Vector3.new(1.4, 0.3, 2.4), facing * CFrame.new(offset, 0.15, 0.45), Color3.fromRGB(28, 30, 70), "SmoothPlastic")
	end
	newPart(model, "Frame", Vector3.new(14.6, 10.6, 0.3), facing * CFrame.new(0, 6.6, 0.25), Color3.fromRGB(240, 190, 74), "Foil")
	local board = newPart(model, "TutorialBoard", Vector3.new(14, 10, 0.2), facing * CFrame.new(0, 6.6, 0), Color3.fromRGB(30, 30, 66), "SmoothPlastic")
	board.CastShadow = false
	if collectObstacles then
		table.insert(obstacles, { base.X - 7.5, base.X + 7.5, base.Z - 7.5, base.Z + 7.5, floorY })
	end
	return board
end


-- Supprime le point d'apparition du modèle Baseplate (les joueurs apparaissent dans le hall).
function AgencyBuilder.ClearTemplate()
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

-- Allège le rendu : seuls les grands éléments (murs, toits, gros meubles) projettent une ombre.
-- Les petites pièces, le verre et les néons n'en projettent plus (beaucoup moins de calcul, moins de lag).
local function optimizeRender(root, everything)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local s = d.Size
			if everything or math.max(s.X, s.Y, s.Z) < 10 or d.Transparency > 0.2 or d.Material == Enum.Material.Neon or d.Material == Enum.Material.Glass then
				d.CastShadow = false
			end
		elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			d.Shadows = false
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
	table.clear(Cat.Zones)

	setupLighting(mapId)
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
	-- Panneau du tutoriel face au point d'arrivée (les cartes sont dessinées par l'écran du joueur).
	AG.TutorialBoard(root, mapId, map.Spawn)
	-- Porte de sortie de fin de niveau, près de l'arrivée.
	AG.ExitDoor(root, mapId, map.Spawn)
	collectObstacles = false
	-- Catégorie de chaque meuble de rangement (étiquettes, panneaux, places).
	Cat.Assign(mapId)
	setFloor(GROUND_TOP)

	local spawn = createSpawn(root, "LevelSpawn", map.Spawn)
	optimizeRender(root, false)
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
		local floorTop = if room.Map == "Agency" then TidyConfig.FloorHeights[room.Floor or 1] elseif room.Map == "Headquarters" then HQ.Floor else 1
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
	-- Les objets à ranger ne projettent pas d'ombre (des milliers de petites pièces).
	optimizeRender(itemsFolder, true)
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
	local spawn, pads, boards = Hub.Build(root)
	collectObstacles = wasCollecting
	setFloor(GROUND_TOP)
	optimizeRender(root, false)
	root.Parent = Workspace
	return { Spawn = spawn, Pads = pads, Boards = boards, Root = root }
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

-- Fabrique un objet seul (aperçus et tests).
function AgencyBuilder.PreviewItem(itemType, index, categoryId)
	local model, main = buildItemParts(itemType, index, categoryId)
	return model, main, REST_HEIGHTS[itemType]
end

AgencyBuilder.FloorTop = FLOOR_TOP
return AgencyBuilder
