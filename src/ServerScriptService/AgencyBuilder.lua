-- AgencyBuilder (ModuleScript)
-- Location: ServerScriptService
-- Builds the whole employment agency when the game starts: building, furniture,
-- signs, lights, the places where objects belong, and the misplaced objects.
-- It is used by the TidyManager script. It does nothing on its own.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TidyConfig = require(ReplicatedStorage:WaitForChild("TidyConfig"))

local AgencyBuilder = {}

---------------------------------------------------------------------------
-- Dimensions (in studs). The inside of the building goes from
-- X = -40 to 40 and from Z = -30 to 30. The floor surface is at Y = 1.
---------------------------------------------------------------------------
local FLOOR_TOP = 1
local HALF_X = 40
local HALF_Z = 30
local WALL_HEIGHT = 12
local CEILING_BOTTOM = FLOOR_TOP + WALL_HEIGHT
local DESK_HEIGHT = 2.5
local COUNTER_HEIGHT = 3.75

-- Size of the main part of each object. Used for the objects and their places.
local ITEM_SIZES = {
	Folder = Vector3.new(1.3, 0.15, 1.6),
	Paper = Vector3.new(1.1, 0.25, 1.5),
	Chair = Vector3.new(2, 0.35, 2),
	Box = Vector3.new(2.4, 1.8, 1.8),
}

-- Distance between the floor and the center of each object's main part.
local REST_HEIGHTS = {
	Folder = 0.075,
	Paper = 0.125,
	Chair = 1.8,
	Box = 0.9,
}
local TIPPED_CHAIR_HEIGHT = 1

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

local BINDER_COLORS = {
	Color3.fromRGB(40, 60, 110),
	Color3.fromRGB(120, 40, 40),
	Color3.fromRGB(50, 50, 55),
	Color3.fromRGB(200, 180, 120),
}

---------------------------------------------------------------------------
-- Where the misplaced objects start.
-- X / Z : position on the map. Surface : height of what it lies on
-- (0 = floor, DESK_HEIGHT = on a desk). Yaw : rotation in degrees.
-- Tipped : the chair lies on its side.
---------------------------------------------------------------------------
local MISPLACED_ITEMS = {
	{ Type = "Folder", X = -22, Z = 4, Surface = 0, Yaw = 25 },
	{ Type = "Folder", X = -18, Z = -4, Surface = DESK_HEIGHT, Yaw = 25 },
	{ Type = "Folder", X = -12, Z = 20, Surface = 0, Yaw = 70 },
	{ Type = "Folder", X = 2, Z = -24, Surface = 0, Yaw = -40 },
	{ Type = "Folder", X = 8, Z = 6, Surface = 0, Yaw = 10 },
	{ Type = "Folder", X = 34, Z = 15, Surface = 0, Yaw = 55 },

	{ Type = "Paper", X = -24, Z = -11, Surface = 0, Yaw = 15 },
	{ Type = "Paper", X = -6, Z = 24, Surface = 0, Yaw = 40 },
	{ Type = "Paper", X = 30, Z = -18, Surface = 0, Yaw = -20 },
	{ Type = "Paper", X = 12, Z = -20, Surface = 0, Yaw = 80 },
	{ Type = "Paper", X = 18, Z = 26, Surface = 0, Yaw = -60 },
	{ Type = "Paper", X = -32.2, Z = -18, Surface = DESK_HEIGHT, Yaw = 20 },

	{ Type = "Chair", X = -6, Z = -10, Surface = 0, Yaw = 30, Tipped = true },
	{ Type = "Chair", X = -36, Z = 14, Surface = 0, Yaw = 120 },
	{ Type = "Chair", X = 12, Z = 10, Surface = 0, Yaw = -15, Tipped = true },
	{ Type = "Chair", X = -22, Z = -26, Surface = 0, Yaw = 200 },
	{ Type = "Chair", X = 36, Z = -16, Surface = 0, Yaw = 90, Tipped = true },
	{ Type = "Chair", X = 18, Z = -6, Surface = 0, Yaw = 45 },

	{ Type = "Box", X = -10, Z = 16, Surface = 0, Yaw = 20 },
	{ Type = "Box", X = 2, Z = -14, Surface = 0, Yaw = -30 },
	{ Type = "Box", X = -36, Z = -10, Surface = 0, Yaw = 10 },
	{ Type = "Box", X = 36, Z = 27, Surface = 0, Yaw = 70 },
}

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

-- Applies a material by name, with a safe fallback if it does not exist.
local function setMaterial(part, materialName)
	local ok = pcall(function()
		part.Material = Enum.Material[materialName]
	end)
	if not ok then
		part.Material = Enum.Material.SmoothPlastic
	end
end

-- Creates an anchored part. "options" can set extra properties.
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
	part.Parent = parent
	return part
end

-- Creates an anchored part from a center position (no rotation).
local function block(parent, name, size, position, color, materialName, options)
	return newPart(parent, name, size, CFrame.new(position), color, materialName, options)
end

-- Creates a vertical cylinder (Roblox cylinders lie along X, so we rotate it).
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

-- Creates a flat sign with text. "facing" is the direction the text looks at.
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
-- Building: floors, walls, windows, entrance, ceiling and lights
---------------------------------------------------------------------------
local function buildStructure(parent)
	local floorY = FLOOR_TOP / 2

	-- Floors (they touch each other without overlapping).
	block(parent, "OfficeCarpet", Vector3.new(64, 1, 38), Vector3.new(-8, floorY, -11), COLORS.Carpet, "Carpet")
	block(parent, "CorridorCarpet", Vector3.new(16, 1, 20), Vector3.new(32, floorY, -2), COLORS.Carpet, "Carpet")
	block(parent, "StorageFloor", Vector3.new(16, 1, 18), Vector3.new(32, floorY, -21), COLORS.Concrete, "Concrete")
	block(parent, "LobbyTiles", Vector3.new(80, 1, 22), Vector3.new(0, floorY, 19), COLORS.Tiles, "Marble")

	-- Outer walls (outside the inner area, so they never overlap the floor).
	local wallHeight = CEILING_BOTTOM
	local wallY = wallHeight / 2
	local fullLengthX = HALF_X * 2 + 2
	local fullLengthZ = HALF_Z * 2 + 2
	local sideWallLength = HALF_Z * 2 -- east/west walls fit between the north and south walls

	block(parent, "NorthWall", Vector3.new(fullLengthX, wallHeight, 1), Vector3.new(0, wallY, -HALF_Z - 0.5), COLORS.Wall, "Plaster")
	block(parent, "EastWall", Vector3.new(1, wallHeight, sideWallLength), Vector3.new(HALF_X + 0.5, wallY, 0), COLORS.Wall, "Plaster")

	-- South wall with the entrance (8 studs wide, 8 studs high).
	local doorHalf = 4
	local doorTop = FLOOR_TOP + 8
	local sideLength = HALF_X + 1 - doorHalf
	block(parent, "SouthWallLeft", Vector3.new(sideLength, wallHeight, 1), Vector3.new(-(doorHalf + sideLength / 2), wallY, HALF_Z + 0.5), COLORS.Wall, "Plaster")
	block(parent, "SouthWallRight", Vector3.new(sideLength, wallHeight, 1), Vector3.new(doorHalf + sideLength / 2, wallY, HALF_Z + 0.5), COLORS.Wall, "Plaster")
	block(parent, "EntranceLintel", Vector3.new(doorHalf * 2, wallHeight - doorTop, 1), Vector3.new(0, (doorTop + wallHeight) / 2, HALF_Z + 0.5), COLORS.Wall, "Plaster")

	-- Closed glass entrance doors (the agency is not open to the public yet).
	for _, side in { -1, 1 } do
		block(parent, "GlassDoor", Vector3.new(3.9, 8, 0.3), Vector3.new(side * 2, FLOOR_TOP + 4, HALF_Z + 0.5), COLORS.Glass, "Glass", { Transparency = 0.6 })
		block(parent, "DoorHandle", Vector3.new(0.15, 1.5, 0.5), Vector3.new(side * 0.4, FLOOR_TOP + 3.75, HALF_Z + 0.2), COLORS.Metal, "Metal")
	end
	block(parent, "DoorFrame", Vector3.new(0.3, 8, 0.4), Vector3.new(0, FLOOR_TOP + 4, HALF_Z + 0.5), COLORS.DarkMetal, "Metal")

	-- West wall with two large windows.
	local sillY = FLOOR_TOP + 3
	local windowTop = FLOOR_TOP + 9
	local westX = -HALF_X - 0.5
	block(parent, "WestWallLow", Vector3.new(1, sillY, sideWallLength), Vector3.new(westX, sillY / 2, 0), COLORS.Wall, "Plaster")
	block(parent, "WestWallHigh", Vector3.new(1, wallHeight - windowTop, sideWallLength), Vector3.new(westX, (windowTop + wallHeight) / 2, 0), COLORS.Wall, "Plaster")
	local windowHeight = windowTop - sillY
	local windowY = (sillY + windowTop) / 2
	-- Pillars between the windows: {from Z, to Z}
	for _, range in { { -HALF_Z, -24 }, { -4, 4 }, { 24, HALF_Z } } do
		local length = range[2] - range[1]
		block(parent, "WestPillar", Vector3.new(1, windowHeight, length), Vector3.new(westX, windowY, range[1] + length / 2), COLORS.Wall, "Plaster")
	end
	for _, range in { { -24, -4 }, { 4, 24 } } do
		local length = range[2] - range[1]
		block(parent, "Window", Vector3.new(0.3, windowHeight, length), Vector3.new(westX, windowY, range[1] + length / 2), COLORS.Glass, "Glass", { Transparency = 0.5 })
		block(parent, "WindowSill", Vector3.new(0.6, 0.2, length), Vector3.new(-HALF_X + 0.3, sillY + 0.1, range[1] + length / 2), COLORS.Wall, "SmoothPlastic")
	end

	-- Storage room partitions (room from X = 24 to 40 and Z = -30 to -12).
	local partitionX = 24
	local doorFromZ, doorToZ = -22, -16
	block(parent, "StoragePartition", Vector3.new(0.5, WALL_HEIGHT, doorFromZ + HALF_Z), Vector3.new(partitionX, FLOOR_TOP + WALL_HEIGHT / 2, (-HALF_Z + doorFromZ) / 2), COLORS.Partition, "Plaster")
	block(parent, "StoragePartition", Vector3.new(0.5, WALL_HEIGHT, -12 - doorToZ), Vector3.new(partitionX, FLOOR_TOP + WALL_HEIGHT / 2, (doorToZ - 12) / 2), COLORS.Partition, "Plaster")
	block(parent, "StorageDoorLintel", Vector3.new(0.5, WALL_HEIGHT - 8, doorToZ - doorFromZ), Vector3.new(partitionX, FLOOR_TOP + 8 + (WALL_HEIGHT - 8) / 2, (doorFromZ + doorToZ) / 2), COLORS.Partition, "Plaster")
	block(parent, "StoragePartition", Vector3.new(HALF_X - partitionX + 0.25, WALL_HEIGHT, 0.5), Vector3.new((partitionX - 0.25 + HALF_X) / 2, FLOOR_TOP + WALL_HEIGHT / 2, -11.75), COLORS.Partition, "Plaster")

	-- Ceiling.
	block(parent, "Ceiling", Vector3.new(fullLengthX, 1, fullLengthZ), Vector3.new(0, CEILING_BOTTOM + 0.5, 0), COLORS.Ceiling, "SmoothPlastic")

	-- Ceiling light panels.
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

	-- Entrance mat.
	block(parent, "EntranceMat", Vector3.new(6, 0.05, 3), Vector3.new(0, FLOOR_TOP + 0.025, HALF_Z - 2.5), COLORS.DarkMetal, "Fabric")
end

---------------------------------------------------------------------------
-- Decorative furniture (cannot be picked up)
---------------------------------------------------------------------------

-- Office chair. "floorPosition" is on the floor; the chair faces -Z before rotation.
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

-- Empty document tray. Returns the position where a stack of papers goes.
local function createTray(parent, position)
	block(parent, "DocumentTray", Vector3.new(1.4, 0.1, 1.8), position + Vector3.new(0, 0.05, 0), COLORS.DarkMetal, "Metal")
	return CFrame.new(position + Vector3.new(0, 0.1 + REST_HEIGHTS.Paper, 0))
end

-- Advisor desk with computer and two chairs. Returns the paper tray spot.
local function createAdvisorDesk(parent, index, cx, cz)
	local model = newModel(parent, "AdvisorDesk" .. index)
	local top = FLOOR_TOP + DESK_HEIGHT

	block(model, "Desktop", Vector3.new(6, 0.2, 3), Vector3.new(cx, top - 0.1, cz), COLORS.Wood, "Wood")
	for _, side in { -1, 1 } do
		block(model, "SidePanel", Vector3.new(0.2, DESK_HEIGHT - 0.2, 2.8), Vector3.new(cx + side * 2.85, FLOOR_TOP + (DESK_HEIGHT - 0.2) / 2, cz), COLORS.Metal, "SmoothPlastic")
	end
	block(model, "ModestyPanel", Vector3.new(5.5, 1.5, 0.1), Vector3.new(cx, FLOOR_TOP + 1.55, cz + 1.3), COLORS.Metal, "SmoothPlastic")
	block(model, "MonitorStand", Vector3.new(0.4, 0.5, 0.3), Vector3.new(cx, top + 0.25, cz + 0.7), COLORS.Black, "SmoothPlastic")
	block(model, "Monitor", Vector3.new(2.2, 1.3, 0.1), Vector3.new(cx, top + 1.15, cz + 0.7), COLORS.Black, "SmoothPlastic")
	block(model, "Keyboard", Vector3.new(1.6, 0.08, 0.5), Vector3.new(cx, top + 0.04, cz - 0.6), COLORS.Black, "SmoothPlastic")

	-- Advisor sits on the north side, the job seeker on the south side.
	createOfficeChair(model, Vector3.new(cx, FLOOR_TOP, cz - 2.4), math.pi)
	createOfficeChair(model, Vector3.new(cx, FLOOR_TOP, cz + 2.4), 0)

	return createTray(model, Vector3.new(cx + 2, top, cz))
end

-- Reception counter in the lobby. Returns the two paper tray spots.
local function createReception(parent)
	local model = newModel(parent, "Reception")
	local cz = 13
	local top = FLOOR_TOP + COUNTER_HEIGHT

	block(model, "CounterBody", Vector3.new(12, COUNTER_HEIGHT - 0.25, 2.5), Vector3.new(0, FLOOR_TOP + (COUNTER_HEIGHT - 0.25) / 2, cz), COLORS.DarkWood, "Wood")
	block(model, "CounterTop", Vector3.new(12.4, 0.25, 2.9), Vector3.new(0, top - 0.125, cz), COLORS.Tiles, "Marble")
	newSign(model, "ReceptionSign", "RECEPTION", Vector3.new(5, 1, 0.05), Vector3.new(0, FLOOR_TOP + 2.2, cz + 1.275), Vector3.new(0, 0, 1))

	block(model, "MonitorStand", Vector3.new(0.4, 0.5, 0.3), Vector3.new(0, top + 0.25, cz - 0.6), COLORS.Black, "SmoothPlastic")
	block(model, "Monitor", Vector3.new(2.2, 1.3, 0.1), Vector3.new(0, top + 1.15, cz - 0.6), COLORS.Black, "SmoothPlastic")
	createOfficeChair(model, Vector3.new(0, FLOOR_TOP, 10), math.pi)

	-- Agency name, hanging from the ceiling above the counter.
	local signY = FLOOR_TOP + 9
	newSign(model, "AgencySign", string.upper(TidyConfig.AgencyName), Vector3.new(16, 1.8, 0.3), Vector3.new(0, signY, 12), Vector3.new(0, 0, 1))
	local wireLength = CEILING_BOTTOM - (signY + 0.9)
	for _, x in { -6, 6 } do
		block(model, "SignWire", Vector3.new(0.05, wireLength, 0.05), Vector3.new(x, signY + 0.9 + wireLength / 2, 12), COLORS.DarkMetal, "Metal", { CanCollide = false })
	end

	return {
		createTray(model, Vector3.new(-4, top, cz)),
		createTray(model, Vector3.new(4, top, cz)),
	}
end

-- Archive shelf for case folders. Returns the 6 folder spots.
local function createArchiveShelf(parent)
	local model = newModel(parent, "ArchiveShelf")
	local cx, cz = 8, -29
	local width, depth, height = 6, 2, 6
	local spots = {}

	block(model, "BackPanel", Vector3.new(width, height, 0.2), Vector3.new(cx, FLOOR_TOP + height / 2, -HALF_Z + 0.1), COLORS.Wood, "Wood")
	for _, side in { -1, 1 } do
		block(model, "SidePanel", Vector3.new(0.2, height, depth - 0.2), Vector3.new(cx + side * (width / 2 - 0.1), FLOOR_TOP + height / 2, cz + 0.1), COLORS.Wood, "Wood")
	end

	local shelfTops = { 0.2, 2.2, 4.2, height }
	for _, shelfTop in shelfTops do
		block(model, "Shelf", Vector3.new(width - 0.4, 0.15, depth - 0.2), Vector3.new(cx, FLOOR_TOP + shelfTop - 0.075, cz + 0.1), COLORS.Wood, "Wood")
	end

	-- Bottom shelf: decorative binders (already in order).
	for i = 0, 11 do
		local x = cx - 2.55 + 0.25 + i * 0.42
		block(model, "Binder", Vector3.new(0.36, 1.5, 1.5), Vector3.new(x, FLOOR_TOP + 0.2 + 0.75, cz + 0.1), BINDER_COLORS[i % #BINDER_COLORS + 1], "SmoothPlastic")
	end

	-- Middle and top shelves: three free spots each, folders stand upright.
	for _, shelfTop in { shelfTops[2], shelfTops[3] } do
		for _, x in { cx - 1.5, cx, cx + 1.5 } do
			table.insert(spots, CFrame.new(x, FLOOR_TOP + shelfTop + ITEM_SIZES.Folder.X / 2, cz + 0.05) * CFrame.Angles(0, 0, math.rad(90)))
		end
	end

	newSign(parent, "ArchiveSign", "CASE FILES", Vector3.new(5, 0.9, 0.1), Vector3.new(cx, FLOOR_TOP + 7.2, -HALF_Z + 0.05), Vector3.new(0, 0, 1))
	return spots
end

-- Decorative filing cabinet against the north wall.
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

-- Metal shelving unit in the storage room. Returns the 2 box spots.
local function createStorageShelf(parent, index, cx)
	local model = newModel(parent, "StorageShelf" .. index)
	local width, depth, height = 5, 3, 7
	local cz = -HALF_Z + depth / 2
	local spots = {}

	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block(model, "Post", Vector3.new(0.2, height, 0.2), Vector3.new(cx + sx * (width / 2 - 0.1), FLOOR_TOP + height / 2, cz + sz * (depth / 2 - 0.1)), COLORS.DarkMetal, "Metal")
		end
	end

	local levels = { 0.3, 3.3, 6.3 }
	for _, level in levels do
		block(model, "ShelfBoard", Vector3.new(width - 0.1, 0.15, depth - 0.1), Vector3.new(cx, FLOOR_TOP + level - 0.075, cz), COLORS.Metal, "Metal")
	end

	-- Two lower levels are free for boxes.
	table.insert(spots, CFrame.new(cx, FLOOR_TOP + levels[1] + REST_HEIGHTS.Box, cz))
	table.insert(spots, CFrame.new(cx, FLOOR_TOP + levels[2] + REST_HEIGHTS.Box, cz))

	-- Top level: decorative archive boxes (already in order).
	for _, offset in { -1.2, 1.2 } do
		block(model, "ArchiveBox", Vector3.new(2.2, 0.6, 2.4), Vector3.new(cx + offset, FLOOR_TOP + levels[3] + 0.3, cz), COLORS.Cardboard, "Cardboard")
	end

	return spots
end

-- Waiting area chairs face the "Now serving" screen on the east wall.
-- Returns the 6 chair spots.
local function createWaitingArea(parent)
	local spots = {}
	for _, x in { 27, 31 } do
		for _, z in { 18.5, 21, 23.5 } do
			table.insert(spots, CFrame.new(x, FLOOR_TOP + REST_HEIGHTS.Chair, z) * CFrame.Angles(0, math.rad(-90), 0))
		end
	end

	newSign(parent, "NowServingScreen", "NOW SERVING   A-047", Vector3.new(6, 2, 0.2), Vector3.new(HALF_X - 0.1, FLOOR_TOP + 6.5, 21), Vector3.new(-1, 0, 0), COLORS.Black, Color3.fromRGB(255, 90, 70))
	newSign(parent, "WaitingSign", "WAITING AREA", Vector3.new(6, 0.9, 0.2), Vector3.new(HALF_X - 0.1, FLOOR_TOP + 8.6, 21), Vector3.new(-1, 0, 0))
	return spots
end

-- Lobby decoration: water cooler, job offers board, plants.
local function createLobbyDecor(parent)
	local cooler = newModel(parent, "WaterCooler")
	block(cooler, "Body", Vector3.new(1.2, 3.2, 1.2), Vector3.new(-38.5, FLOOR_TOP + 1.6, 20), Color3.fromRGB(235, 235, 235), "SmoothPlastic")
	local bottle = cylinder(cooler, "Bottle", 1.2, 0.9, Vector3.new(-38.5, FLOOR_TOP + 3.8, 20), Color3.fromRGB(150, 200, 240), "Glass")
	bottle.Transparency = 0.3

	local board = newModel(parent, "JobOffersBoard")
	local boardZ = HALF_Z - 0.08
	block(board, "Cork", Vector3.new(8, 4, 0.15), Vector3.new(-20, FLOOR_TOP + 5, boardZ), COLORS.Cork, "Fabric")
	newSign(board, "Title", "JOB OFFERS", Vector3.new(8, 0.9, 0.1), Vector3.new(-20, FLOOR_TOP + 7.6, HALF_Z - 0.05), Vector3.new(0, 0, -1))
	local tilt = { -4, 3, -2, 5, -3, 2 }
	local n = 0
	for _, y in { FLOOR_TOP + 5.9, FLOOR_TOP + 4.1 } do
		for _, x in { -23, -20, -17 } do
			n += 1
			newPart(board, "JobOffer", Vector3.new(1.6, 1.4, 0.02), CFrame.new(x, y, boardZ - 0.085) * CFrame.Angles(0, 0, math.rad(tilt[n])), COLORS.Paper, "SmoothPlastic", { CanCollide = false })
		end
	end

	for _, position in { { -38, 28 }, { -38, 10 }, { -38, -28 }, { 20, -28 }, { 38, 10 } } do
		createPlant(parent, position[1], position[2])
	end
end

---------------------------------------------------------------------------
-- Objects to tidy up and the places where they belong
---------------------------------------------------------------------------

local function weldToMain(main, part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = main
	weld.Part1 = part
	weld.Parent = main
end

local function createPrompt(parent, name, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = TidyConfig.MaxDistance
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = parent
	return prompt
end

-- Builds the parts of one object around the origin. Returns the model and its main part.
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
		-- The main part is the seat. The chair faces -Z.
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
		local tape = newPart(model, "Tape", Vector3.new(2.44, 0.02, 0.45), CFrame.new(0, 0.905, 0), COLORS.Tape, "SmoothPlastic")
		tape.CanCollide = false
		weldToMain(main, tape)
	else
		error("Unknown item type: " .. tostring(itemType))
	end

	model.PrimaryPart = main
	return model, main
end

local function createItem(parent, itemType, index, homeCFrame)
	local model, main = buildItemParts(itemType, index)
	model:PivotTo(homeCFrame)

	model:SetAttribute("ItemType", itemType)
	model:SetAttribute("State", "Loose")
	model:SetAttribute("HomeCFrame", homeCFrame)

	createPrompt(main, "PickupPrompt", "Pick up", TidyConfig.ItemTypes[itemType].DisplayName)

	model.Parent = parent
	CollectionService:AddTag(model, TidyConfig.ItemTag)
	return model
end

-- An invisible spot where an object belongs. It glows when the player
-- carries a matching object (handled by TidyUI).
local function createSlot(parent, itemType, index, targetCFrame)
	local slot = newPart(parent, itemType .. "Spot" .. index, ITEM_SIZES[itemType], targetCFrame, COLORS.Ghost, "Neon", {
		Transparency = 1,
		CastShadow = false,
	})
	slot.CanCollide = false
	slot.CanTouch = false
	slot.CanQuery = false

	slot:SetAttribute("ItemType", itemType)
	slot:SetAttribute("Occupied", false)

	createPrompt(slot, "PlacePrompt", "Put away", TidyConfig.ItemTypes[itemType].PlaceName)

	CollectionService:AddTag(slot, TidyConfig.SlotTag)
	return slot
end

local function startCFrame(entry)
	local base = CFrame.new(entry.X, FLOOR_TOP + entry.Surface, entry.Z) * CFrame.Angles(0, math.rad(entry.Yaw), 0)
	if entry.Type == "Chair" and entry.Tipped then
		return base * CFrame.new(0, TIPPED_CHAIR_HEIGHT, 0) * CFrame.Angles(0, 0, math.rad(90))
	end
	return base * CFrame.new(0, REST_HEIGHTS[entry.Type], 0)
end

---------------------------------------------------------------------------
-- Lighting and spawn
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
	-- Removes the default spawn of the template so players start inside the agency.
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
-- Main function
---------------------------------------------------------------------------
function AgencyBuilder.Build()
	local old = Workspace:FindFirstChild("EmploymentAgency")
	if old then
		old:Destroy()
	end

	setupLighting()

	local root = Instance.new("Model")
	root.Name = "EmploymentAgency"

	local structure = newFolder(root, "Building")
	local furniture = newFolder(root, "Furniture")
	local spotsFolder = newFolder(root, "TidySpots")
	local itemsFolder = newFolder(root, "MisplacedItems")

	buildStructure(structure)
	createLobbyDecor(furniture)

	-- Places where objects belong, grouped by type.
	local spotCFrames = { Folder = {}, Paper = {}, Chair = {}, Box = {} }

	for _, cframe in createReception(furniture) do
		table.insert(spotCFrames.Paper, cframe)
	end

	local deskPositions = { { -30, -4 }, { -16, -4 }, { -30, -18 }, { -16, -18 } }
	for index, position in deskPositions do
		table.insert(spotCFrames.Paper, createAdvisorDesk(furniture, index, position[1], position[2]))
	end

	spotCFrames.Folder = createArchiveShelf(furniture)
	createFilingCabinet(furniture, 12.6)
	createFilingCabinet(furniture, 14.6)

	for index, cx in { 28, 34 } do
		for _, cframe in createStorageShelf(furniture, index, cx) do
			table.insert(spotCFrames.Box, cframe)
		end
	end
	newSign(furniture, "StorageSign", "STORAGE", Vector3.new(4, 1, 0.1), Vector3.new(23.7, FLOOR_TOP + 9.5, -19), Vector3.new(-1, 0, 0))

	spotCFrames.Chair = createWaitingArea(furniture)

	local slots = {}
	for itemType, cframes in spotCFrames do
		for index, cframe in cframes do
			table.insert(slots, createSlot(spotsFolder, itemType, index, cframe))
		end
	end

	local items = {}
	local counts = {}
	for _, entry in MISPLACED_ITEMS do
		counts[entry.Type] = (counts[entry.Type] or 0) + 1
		table.insert(items, createItem(itemsFolder, entry.Type, counts[entry.Type], startCFrame(entry)))
	end

	-- Safety check: every object must have a free place.
	for itemType, count in counts do
		if #spotCFrames[itemType] < count then
			warn(string.format("[AgencyBuilder] Not enough places for %s: %d objects, %d places", itemType, count, #spotCFrames[itemType]))
		end
	end

	createSpawn(root)
	root.Parent = Workspace

	return {
		Root = root,
		Items = items,
		Slots = slots,
	}
end

return AgencyBuilder
