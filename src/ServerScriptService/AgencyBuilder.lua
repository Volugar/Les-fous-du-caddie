-- AgencyBuilder (ModuleScript)
-- Emplacement : ServerScriptService
-- Construit toute l'agence pour l'emploi au lancement du jeu : bâtiment, mobilier,
-- panneaux, lumières, zones de rangement avec leurs places, et objets éparpillés.
-- Il est utilisé par le script TidyManager. Il ne fait rien tout seul.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TidyConfig = require(ReplicatedStorage:WaitForChild("TidyConfig"))

local AgencyBuilder = {}

---------------------------------------------------------------------------
-- Dimensions (en studs). L'intérieur du bâtiment va de
-- X = -40 à 40 et de Z = -30 à 30. La surface du sol est à Y = 1.
---------------------------------------------------------------------------
local FLOOR_TOP = 1
local HALF_X = 40
local HALF_Z = 30
local WALL_HEIGHT = 12
local CEILING_BOTTOM = FLOOR_TOP + WALL_HEIGHT
local DESK_HEIGHT = 2.5
local COUNTER_HEIGHT = 3.75

-- Taille de la pièce principale de chaque objet. Sert aux objets et à leurs places.
local ITEM_SIZES = {
	Folder = Vector3.new(1.3, 0.15, 1.6),
	Paper = Vector3.new(1.1, 0.25, 1.5),
	Chair = Vector3.new(2, 0.35, 2),
	Box = Vector3.new(2.1, 1.6, 1.6),
}

-- Distance entre le sol et le centre de la pièce principale de chaque objet.
local REST_HEIGHTS = {
	Folder = 0.075,
	Paper = 0.125,
	Chair = 1.8,
	Box = 0.8,
}
local TIPPED_CHAIR_HEIGHT = 1

-- Rayon occupé au sol par chaque objet (pour ne pas les poser les uns sur les autres).
local ITEM_RADIUS = {
	Folder = 1.1,
	Paper = 1,
	Chair = 1.6,
	Box = 1.5,
}
local TIPPED_CHAIR_RADIUS = 2.4

local COLORS = {
	Wall = Color3.fromRGB(226, 222, 212),
	Partition = Color3.fromRGB(205, 203, 196),
	Ceiling = Color3.fromRGB(240, 240, 236),
	Carpet = Color3.fromRGB(84, 92, 104),
	Tiles = Color3.fromRGB(196, 196, 190),
	Concrete = Color3.fromRGB(150, 150, 146),
	Wood = Color3.fromRGB(176, 150, 116),
	DarkWood = Color3.fromRGB(104, 78, 56),
	Metal = Color3.fromRGB(150, 154, 160),
	DarkMetal = Color3.fromRGB(70, 72, 78),
	Black = Color3.fromRGB(28, 28, 30),
	OfficeChair = Color3.fromRGB(40, 42, 48),
	WaitingChair = Color3.fromRGB(64, 92, 128),
	Rug = Color3.fromRGB(46, 70, 112),
	Paper = Color3.fromRGB(240, 240, 234),
	Cardboard = Color3.fromRGB(178, 140, 94),
	Tape = Color3.fromRGB(206, 176, 128),
	Glass = Color3.fromRGB(190, 215, 230),
	Light = Color3.fromRGB(255, 250, 240),
	Plant = Color3.fromRGB(62, 112, 64),
	Pot = Color3.fromRGB(90, 90, 92),
	Cork = Color3.fromRGB(172, 132, 92),
	SignBlue = Color3.fromRGB(30, 52, 84),
	Ghost = Color3.fromRGB(90, 220, 130),
}

local FOLDER_COLORS = {
	Color3.fromRGB(222, 196, 140),
	Color3.fromRGB(70, 100, 160),
	Color3.fromRGB(160, 62, 56),
	Color3.fromRGB(80, 130, 90),
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

	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
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

-- Transforme un meuble en zone de rangement : on clique dessus pour y ranger.
-- Un panneau flottant affiche le compteur de la catégorie.
local function makeZone(model, itemType, anchorPart, billboardHeight)
	model:SetAttribute("ItemType", itemType)
	model:SetAttribute("ZoneLabel", TidyConfig.ItemTypes[itemType].PlaceName)
	CollectionService:AddTag(model, TidyConfig.ZoneTag)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CategoryBillboard"
	billboard.Adornee = anchorPart
	billboard.Size = UDim2.fromOffset(220, 52)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, billboardHeight, 0)
	billboard.MaxDistance = 70
	billboard.LightInfluence = 0
	billboard.Parent = model

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = COLORS.SignBlue
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.GothamBold
	label.Text = TidyConfig.ItemTypes[itemType].PlaceName
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextScaled = true
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
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
	slot:SetAttribute("Order", #allSlots + 1)
	CollectionService:AddTag(slot, TidyConfig.SlotTag)

	-- Aucune chaise ne doit apparaître là où une chaise se range.
	if itemType == "Chair" then
		local p = targetCFrame.Position
		addObstacle(p.X - 1.4, p.X + 1.4, p.Z - 1.4, p.Z + 1.4)
	end

	table.insert(allSlots, slot)
	return slot
end

---------------------------------------------------------------------------
-- Bâtiment : sols, murs, fenêtres, entrée, plafond et lumières
---------------------------------------------------------------------------
local function buildStructure(parent)
	local floorY = FLOOR_TOP / 2

	-- Sols (ils se touchent sans se chevaucher).
	block(parent, "OfficeCarpet", Vector3.new(64, 1, 38), Vector3.new(-8, floorY, -11), COLORS.Carpet, "Carpet")
	block(parent, "CorridorCarpet", Vector3.new(16, 1, 20), Vector3.new(32, floorY, -2), COLORS.Carpet, "Carpet")
	block(parent, "StorageFloor", Vector3.new(16, 1, 18), Vector3.new(32, floorY, -21), COLORS.Concrete, "Concrete")
	block(parent, "LobbyTiles", Vector3.new(80, 1, 22), Vector3.new(0, floorY, 19), COLORS.Tiles, "Marble")

	-- Murs extérieurs (hors de la zone intérieure, ils ne chevauchent jamais le sol).
	local wallHeight = CEILING_BOTTOM
	local wallY = wallHeight / 2
	local fullLengthX = HALF_X * 2 + 2
	local fullLengthZ = HALF_Z * 2 + 2
	local sideWallLength = HALF_Z * 2 -- les murs est/ouest tiennent entre les murs nord et sud

	block(parent, "NorthWall", Vector3.new(fullLengthX, wallHeight, 1), Vector3.new(0, wallY, -HALF_Z - 0.5), COLORS.Wall, "Plaster")
	block(parent, "EastWall", Vector3.new(1, wallHeight, sideWallLength), Vector3.new(HALF_X + 0.5, wallY, 0), COLORS.Wall, "Plaster")

	-- Mur sud avec l'entrée (8 studs de large, 8 studs de haut).
	local doorHalf = 4
	local doorTop = FLOOR_TOP + 8
	local sideLength = HALF_X + 1 - doorHalf
	block(parent, "SouthWallLeft", Vector3.new(sideLength, wallHeight, 1), Vector3.new(-(doorHalf + sideLength / 2), wallY, HALF_Z + 0.5), COLORS.Wall, "Plaster")
	block(parent, "SouthWallRight", Vector3.new(sideLength, wallHeight, 1), Vector3.new(doorHalf + sideLength / 2, wallY, HALF_Z + 0.5), COLORS.Wall, "Plaster")
	block(parent, "EntranceLintel", Vector3.new(doorHalf * 2, wallHeight - doorTop, 1), Vector3.new(0, (doorTop + wallHeight) / 2, HALF_Z + 0.5), COLORS.Wall, "Plaster")

	-- Portes vitrées fermées (l'agence n'est pas encore ouverte au public).
	for _, side in { -1, 1 } do
		block(parent, "GlassDoor", Vector3.new(3.9, 8, 0.3), Vector3.new(side * 2, FLOOR_TOP + 4, HALF_Z + 0.5), COLORS.Glass, "Glass", { Transparency = 0.6 })
		block(parent, "DoorHandle", Vector3.new(0.15, 1.5, 0.5), Vector3.new(side * 0.4, FLOOR_TOP + 3.75, HALF_Z + 0.2), COLORS.Metal, "Metal")
	end
	block(parent, "DoorFrame", Vector3.new(0.3, 8, 0.4), Vector3.new(0, FLOOR_TOP + 4, HALF_Z + 0.5), COLORS.DarkMetal, "Metal")

	-- Mur ouest avec deux grandes fenêtres.
	local sillY = FLOOR_TOP + 3
	local windowTop = FLOOR_TOP + 9
	local westX = -HALF_X - 0.5
	block(parent, "WestWallLow", Vector3.new(1, sillY, sideWallLength), Vector3.new(westX, sillY / 2, 0), COLORS.Wall, "Plaster")
	block(parent, "WestWallHigh", Vector3.new(1, wallHeight - windowTop, sideWallLength), Vector3.new(westX, (windowTop + wallHeight) / 2, 0), COLORS.Wall, "Plaster")
	local windowHeight = windowTop - sillY
	local windowY = (sillY + windowTop) / 2
	-- Piliers entre les fenêtres : {de Z, à Z}
	for _, range in { { -HALF_Z, -24 }, { -4, 4 }, { 24, HALF_Z } } do
		local length = range[2] - range[1]
		block(parent, "WestPillar", Vector3.new(1, windowHeight, length), Vector3.new(westX, windowY, range[1] + length / 2), COLORS.Wall, "Plaster")
	end
	for _, range in { { -24, -4 }, { 4, 24 } } do
		local length = range[2] - range[1]
		block(parent, "Window", Vector3.new(0.3, windowHeight, length), Vector3.new(westX, windowY, range[1] + length / 2), COLORS.Glass, "Glass", { Transparency = 0.5 })
		block(parent, "WindowSill", Vector3.new(0.6, 0.2, length), Vector3.new(-HALF_X + 0.3, sillY + 0.1, range[1] + length / 2), COLORS.Wall, "SmoothPlastic")
	end

	-- Cloisons de la réserve (pièce de X = 24 à 40 et de Z = -30 à -12).
	local partitionX = 24
	local doorFromZ, doorToZ = -22, -16
	block(parent, "StoragePartition", Vector3.new(0.5, WALL_HEIGHT, doorFromZ + HALF_Z), Vector3.new(partitionX, FLOOR_TOP + WALL_HEIGHT / 2, (-HALF_Z + doorFromZ) / 2), COLORS.Partition, "Plaster")
	block(parent, "StoragePartition", Vector3.new(0.5, WALL_HEIGHT, -12 - doorToZ), Vector3.new(partitionX, FLOOR_TOP + WALL_HEIGHT / 2, (doorToZ - 12) / 2), COLORS.Partition, "Plaster")
	block(parent, "StorageDoorLintel", Vector3.new(0.5, WALL_HEIGHT - 8, doorToZ - doorFromZ), Vector3.new(partitionX, FLOOR_TOP + 8 + (WALL_HEIGHT - 8) / 2, (doorFromZ + doorToZ) / 2), COLORS.Partition, "Plaster")
	block(parent, "StoragePartition", Vector3.new(HALF_X - partitionX + 0.25, WALL_HEIGHT, 0.5), Vector3.new((partitionX - 0.25 + HALF_X) / 2, FLOOR_TOP + WALL_HEIGHT / 2, -11.75), COLORS.Partition, "Plaster")

	-- Plafond.
	block(parent, "Ceiling", Vector3.new(fullLengthX, 1, fullLengthZ), Vector3.new(0, CEILING_BOTTOM + 0.5, 0), COLORS.Ceiling, "SmoothPlastic")

	-- Dalles lumineuses du plafond.
	for _, x in { -30, -15, 0, 15, 31 } do
		for _, z in { -21, -6, 9, 22 } do
			local panel = block(parent, "CeilingLight", Vector3.new(4, 0.2, 2), Vector3.new(x, CEILING_BOTTOM - 0.1, z), COLORS.Light, "Neon", { CanCollide = false, CastShadow = false })
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Angle = 110
			light.Range = 16
			light.Brightness = 1.5
			light.Color = Color3.fromRGB(255, 246, 232)
			light.Shadows = false
			light.Parent = panel
		end
	end

	-- Tapis d'entrée.
	block(parent, "EntranceMat", Vector3.new(6, 0.05, 3), Vector3.new(0, FLOOR_TOP + 0.025, HALF_Z - 2.5), COLORS.DarkMetal, "Fabric", { CanCollide = false })
end

---------------------------------------------------------------------------
-- Mobilier
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

-- Bureau de conseiller avec ordinateur, deux chaises et un bac à documents.
local function createAdvisorDesk(parent, index, cx, cz)
	local model = newModel(parent, "AdvisorDesk" .. index)
	local top = FLOOR_TOP + DESK_HEIGHT

	local desktop = block(model, "Desktop", Vector3.new(6, 0.2, 3), Vector3.new(cx, top - 0.1, cz), COLORS.Wood, "Wood")
	for _, side in { -1, 1 } do
		block(model, "SidePanel", Vector3.new(0.2, DESK_HEIGHT - 0.2, 2.8), Vector3.new(cx + side * 2.85, FLOOR_TOP + (DESK_HEIGHT - 0.2) / 2, cz), COLORS.Metal, "SmoothPlastic")
	end
	block(model, "ModestyPanel", Vector3.new(5.5, 1.5, 0.1), Vector3.new(cx, FLOOR_TOP + 1.55, cz + 1.3), COLORS.Metal, "SmoothPlastic")
	block(model, "MonitorStand", Vector3.new(0.4, 0.5, 0.3), Vector3.new(cx, top + 0.25, cz + 0.7), COLORS.Black, "SmoothPlastic")
	block(model, "Monitor", Vector3.new(2.2, 1.3, 0.1), Vector3.new(cx, top + 1.15, cz + 0.7), COLORS.Black, "SmoothPlastic")
	block(model, "Keyboard", Vector3.new(1.6, 0.08, 0.5), Vector3.new(cx, top + 0.04, cz - 0.6), COLORS.Black, "SmoothPlastic")

	-- Le conseiller est assis côté nord, le demandeur d'emploi côté sud.
	createOfficeChair(model, Vector3.new(cx, FLOOR_TOP, cz - 2.4), math.pi)
	createOfficeChair(model, Vector3.new(cx, FLOOR_TOP, cz + 2.4), 0)

	local spots = makeZone(model, "Paper", desktop, 3.5)
	createTray(model, spots, Vector3.new(cx + 2, top, cz))
end

-- Comptoir d'accueil du hall, avec 4 bacs à documents.
local function createReception(parent)
	local model = newModel(parent, "Reception")
	local cz = 13
	local top = FLOOR_TOP + COUNTER_HEIGHT

	block(model, "CounterBody", Vector3.new(12, COUNTER_HEIGHT - 0.25, 2.5), Vector3.new(0, FLOOR_TOP + (COUNTER_HEIGHT - 0.25) / 2, cz), COLORS.DarkWood, "Wood")
	local counterTop = block(model, "CounterTop", Vector3.new(12.4, 0.25, 2.9), Vector3.new(0, top - 0.125, cz), COLORS.Tiles, "Marble")
	newSign(model, "ReceptionSign", "ACCUEIL", Vector3.new(5, 1, 0.05), Vector3.new(0, FLOOR_TOP + 2.2, cz + 1.275), Vector3.new(0, 0, 1))

	block(model, "MonitorStand", Vector3.new(0.4, 0.5, 0.3), Vector3.new(0, top + 0.25, cz - 0.6), COLORS.Black, "SmoothPlastic")
	block(model, "Monitor", Vector3.new(2.2, 1.3, 0.1), Vector3.new(0, top + 1.15, cz - 0.6), COLORS.Black, "SmoothPlastic")
	createOfficeChair(model, Vector3.new(0, FLOOR_TOP, 10), math.pi)

	-- Nom de l'agence, suspendu au plafond au-dessus du comptoir.
	local signY = FLOOR_TOP + 9
	newSign(model, "AgencySign", string.upper(TidyConfig.AgencyName), Vector3.new(16, 1.8, 0.3), Vector3.new(0, signY, 12), Vector3.new(0, 0, 1))
	local wireLength = CEILING_BOTTOM - (signY + 0.9)
	for _, x in { -6, 6 } do
		block(model, "SignWire", Vector3.new(0.05, wireLength, 0.05), Vector3.new(x, signY + 0.9 + wireLength / 2, 12), COLORS.DarkMetal, "Metal", { CanCollide = false })
	end

	local spots = makeZone(model, "Paper", counterTop, 3)
	for _, x in { -4.5, -2.6, 2.6, 4.5 } do
		createTray(model, spots, Vector3.new(x, top, cz))
	end
end

-- Étagère des dossiers : 3 tablettes de 6 dossiers debout.
local function createArchiveShelf(parent, index, cx)
	local model = newModel(parent, "ArchiveShelf" .. index)
	local cz = -29
	local width, depth, height = 6, 2, 6.2

	local backPanel = block(model, "BackPanel", Vector3.new(width, height, 0.2), Vector3.new(cx, FLOOR_TOP + height / 2, -HALF_Z + 0.1), COLORS.Wood, "Wood")
	for _, side in { -1, 1 } do
		block(model, "SidePanel", Vector3.new(0.2, height, depth - 0.2), Vector3.new(cx + side * (width / 2 - 0.1), FLOOR_TOP + height / 2, cz + 0.1), COLORS.Wood, "Wood")
	end

	local shelfTops = { 0.2, 2.2, 4.2, height }
	for _, shelfTop in shelfTops do
		block(model, "Shelf", Vector3.new(width - 0.4, 0.15, depth - 0.2), Vector3.new(cx, FLOOR_TOP + shelfTop - 0.075, cz + 0.1), COLORS.Wood, "Wood")
	end

	local spots = makeZone(model, "Folder", backPanel, 4.5)
	for level = 1, 3 do
		for slotIndex = 0, 5 do
			local x = cx - 2 + slotIndex * 0.8
			local y = FLOOR_TOP + shelfTops[level] + ITEM_SIZES.Folder.X / 2
			createSlot(spots, "Folder", CFrame.new(x, y, cz + 0.05) * CFrame.Angles(0, 0, math.rad(90)))
		end
	end
end

-- Meuble à tiroirs décoratif contre le mur nord.
local function createFilingCabinet(parent, cx)
	local model = newModel(parent, "FilingCabinet")
	local depth = 2.2
	local frontZ = -HALF_Z + depth
	block(model, "Body", Vector3.new(1.8, 4.5, depth), Vector3.new(cx, FLOOR_TOP + 2.25, -HALF_Z + depth / 2), COLORS.Metal, "Metal")
	for i = 0, 3 do
		local y = FLOOR_TOP + 0.6 + i * 1.1
		block(model, "DrawerLine", Vector3.new(1.7, 0.04, 0.02), Vector3.new(cx, y - 0.5, frontZ + 0.01), COLORS.DarkMetal, "Metal", { CanCollide = false })
		block(model, "Handle", Vector3.new(0.6, 0.1, 0.1), Vector3.new(cx, y, frontZ + 0.05), COLORS.DarkMetal, "Metal")
	end
	return model
end

-- Étagère métallique de la réserve : 3 niveaux de 2 cartons.
local function createStorageShelf(parent, index, cx)
	local model = newModel(parent, "StorageShelf" .. index)
	local width, depth, height = 4.8, 3, 7
	local cz = -HALF_Z + depth / 2

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

-- Salle d'attente : un tapis bleu avec 18 places de chaises face à l'écran.
local function createWaitingArea(parent)
	local model = newModel(parent, "WaitingArea")
	local rug = block(model, "WaitingRug", Vector3.new(16, 0.05, 16), Vector3.new(29, FLOOR_TOP + 0.025, 21.5), COLORS.Rug, "Fabric", { CanCollide = false })
	rug.CanCollide = true -- on peut cliquer dessus et marcher dessus
	addObstacle(21, 37, 13.5, 29.5) -- aucun objet n'apparaît sur le tapis

	local spots = makeZone(model, "Chair", rug, 6)
	for _, x in { 24, 28, 32 } do
		for _, z in { 15, 17.5, 20, 22.5, 25, 27.5 } do
			createSlot(spots, "Chair", CFrame.new(x, FLOOR_TOP + REST_HEIGHTS.Chair, z) * CFrame.Angles(0, math.rad(-90), 0))
		end
	end

	newSign(model, "NowServingScreen", "NUMÉRO APPELÉ   A-047", Vector3.new(6, 2, 0.2), Vector3.new(HALF_X - 0.1, FLOOR_TOP + 6.5, 21), Vector3.new(-1, 0, 0), COLORS.Black, Color3.fromRGB(255, 90, 70))
	newSign(model, "WaitingSign", "SALLE D'ATTENTE", Vector3.new(6, 0.9, 0.2), Vector3.new(HALF_X - 0.1, FLOOR_TOP + 8.6, 21), Vector3.new(-1, 0, 0))
end

-- Décoration du hall : fontaine à eau, tableau des offres d'emploi, plantes.
local function createLobbyDecor(parent)
	local cooler = newModel(parent, "WaterCooler")
	block(cooler, "Body", Vector3.new(1.2, 3.2, 1.2), Vector3.new(-38.5, FLOOR_TOP + 1.6, 20), Color3.fromRGB(235, 235, 235), "SmoothPlastic")
	local bottle = cylinder(cooler, "Bottle", 1.2, 0.9, Vector3.new(-38.5, FLOOR_TOP + 3.8, 20), Color3.fromRGB(150, 200, 240), "Glass")
	bottle.Transparency = 0.3

	local board = newModel(parent, "JobOffersBoard")
	local boardZ = HALF_Z - 0.08
	block(board, "Cork", Vector3.new(8, 4, 0.15), Vector3.new(-20, FLOOR_TOP + 5, boardZ), COLORS.Cork, "Fabric")
	newSign(board, "Title", "OFFRES D'EMPLOI", Vector3.new(8, 0.9, 0.1), Vector3.new(-20, FLOOR_TOP + 7.6, HALF_Z - 0.05), Vector3.new(0, 0, -1))
	local tilt = { -4, 3, -2, 5, -3, 2 }
	local n = 0
	for _, y in { FLOOR_TOP + 5.9, FLOOR_TOP + 4.1 } do
		for _, x in { -23, -20, -17 } do
			n += 1
			newPart(board, "JobOffer", Vector3.new(1.6, 1.4, 0.02), CFrame.new(x, y, boardZ - 0.085) * CFrame.Angles(0, 0, math.rad(tilt[n])), COLORS.Paper, "SmoothPlastic", { CanCollide = false })
		end
	end

	for _, position in { { -38, 28 }, { -38, 10 }, { -38, -28 }, { 20, -28 }, { 38, 9 } } do
		createPlant(parent, position[1], position[2])
	end
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
		local sheet = newPart(model, "TopSheet", Vector3.new(1.05, 0.02, 1.45), CFrame.new(0.05, 0.135, -0.03) * CFrame.Angles(0, math.rad(7), 0), Color3.fromRGB(250, 250, 248), "SmoothPlastic")
		sheet.CanCollide = false
		weldToMain(main, sheet)
	elseif itemType == "Chair" then
		-- La pièce principale est l'assise. La chaise regarde vers -Z.
		main = newPart(model, "Main", size, CFrame.new(), COLORS.WaitingChair, "Plastic")
		local back = newPart(model, "Back", Vector3.new(2, 2, 0.25), CFrame.new(0, 1.175, 0.875), COLORS.WaitingChair, "Plastic")
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
	else
		error("Unknown item type: " .. tostring(itemType))
	end

	model.PrimaryPart = main
	return model, main
end

local function createItem(parent, itemType, index, homeCFrame)
	local model = buildItemParts(itemType, index)
	model:PivotTo(homeCFrame)
	model:SetAttribute("ItemType", itemType)
	model:SetAttribute("State", "Loose")
	model:SetAttribute("HomeCFrame", homeCFrame)
	model:SetAttribute("RestHeight", REST_HEIGHTS[itemType])
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
	Lighting.Ambient = Color3.fromRGB(88, 88, 94)
	Lighting.OutdoorAmbient = Color3.fromRGB(125, 125, 130)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true

	local colorCorrection = Lighting:FindFirstChild("AgencyColorCorrection")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "AgencyColorCorrection"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Saturation = -0.08
	colorCorrection.Contrast = 0.05
	colorCorrection.TintColor = Color3.fromRGB(255, 252, 246)
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

	setupLighting()

	local root = Instance.new("Model")
	root.Name = "EmploymentAgency"

	local structure = newFolder(root, "Building")
	local furniture = newFolder(root, "Furniture")
	itemsFolder = newFolder(root, "MisplacedItems")

	collectObstacles = true
	buildStructure(structure)
	createLobbyDecor(furniture)
	createReception(furniture)
	for index, position in { { -30, -4 }, { -16, -4 }, { -30, -18 }, { -16, -18 } } do
		createAdvisorDesk(furniture, index, position[1], position[2])
	end
	createArchiveShelf(furniture, 1, 0)
	createArchiveShelf(furniture, 2, 8)
	createFilingCabinet(furniture, 12.6)
	createFilingCabinet(furniture, 14.6)
	for index, cx in { 27, 32.2, 37.4 } do
		createStorageShelf(furniture, index, cx)
	end
	newSign(furniture, "StorageSign", "RÉSERVE", Vector3.new(4, 1, 0.1), Vector3.new(23.7, FLOOR_TOP + 9.5, -19), Vector3.new(-1, 0, 0))
	newSign(furniture, "ArchiveSign", "DOSSIERS", Vector3.new(5, 0.9, 0.1), Vector3.new(4, FLOOR_TOP + 7.4, -HALF_Z + 0.05), Vector3.new(0, 0, 1))
	createWaitingArea(furniture)
	collectObstacles = false

	-- Endroits laissés libres : arrivée du joueur et passage de la porte de la réserve.
	addObstacle(-5, 5, 19, HALF_Z)
	addObstacle(20, 28, -24, -14)

	createSpawn(root)
	root.Parent = Workspace

	return {
		Root = root,
		Zones = allZones,
		Slots = allSlots,
	}
end

-- Éparpille de nouveaux objets dans l'agence. Supprime ceux de la partie précédente.
-- Renvoie la liste des objets créés.
function AgencyBuilder.ScatterItems(seed)
	for _, item in currentItems do
		item:Destroy()
	end
	table.clear(currentItems)
	for _, slot in allSlots do
		slot:SetAttribute("Occupied", false)
	end

	local slotCounts = {}
	for _, slot in allSlots do
		local itemType = slot:GetAttribute("ItemType")
		slotCounts[itemType] = (slotCounts[itemType] or 0) + 1
	end

	local rng = Random.new(seed)
	local placed = {}
	for _, itemType in TidyConfig.TypeOrder do
		local wanted = TidyConfig.ItemCounts[itemType] or 0
		local count = math.min(wanted, slotCounts[itemType] or 0)
		if count < wanted then
			warn(string.format("[AgencyBuilder] Only %d places for %s, %d objects requested", count, itemType, wanted))
		end
		for index = 1, count do
			local tipped = itemType == "Chair" and rng:NextNumber() < 0.5
			local radius = if tipped then TIPPED_CHAIR_RADIUS else ITEM_RADIUS[itemType]
			local found = false
			local x, z = 0, 0
			for _ = 1, 400 do
				x = rng:NextNumber(-HALF_X + radius + 0.3, HALF_X - radius - 0.3)
				z = rng:NextNumber(-HALF_Z + radius + 0.3, HALF_Z - radius - 0.3)
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
					home = base * CFrame.new(0, TIPPED_CHAIR_HEIGHT, 0) * CFrame.Angles(0, 0, math.rad(90))
				else
					home = base * CFrame.new(0, REST_HEIGHTS[itemType], 0)
				end
				table.insert(currentItems, createItem(itemsFolder, itemType, index, home))
			else
				warn("[AgencyBuilder] No free floor space for " .. itemType .. index)
			end
		end
	end

	return table.clone(currentItems)
end

-- Dossier où vivent les objets qui traînent.
function AgencyBuilder.GetItemsFolder()
	return itemsFolder
end

-- Hauteur du sol (utile pour lâcher un objet).
AgencyBuilder.FloorTop = FLOOR_TOP

return AgencyBuilder
