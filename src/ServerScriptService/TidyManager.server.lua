-- TidyManager (Script)
-- Emplacement : ServerScriptService
-- Logique principale du jeu : construit l'agence et la zone d'accueil, gère le sac du
-- joueur (ramasser, ranger, lâcher, changer d'objet), l'aimant, les points, les
-- améliorations, les compteurs, la sauvegarde, les rangs, le bonus quotidien,
-- les salons privés multijoueur, et relance une journée quand tout est rangé.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local TidyConfig = require(ReplicatedStorage:WaitForChild("TidyConfig"))
local AgencyBuilder = require(ServerScriptService:WaitForChild("AgencyBuilder"))

-- Serveur de salon privé (créé depuis la zone d'accueil) : on joue directement dans l'agence.
local isRoomServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

local agency = AgencyBuilder.Build()
local itemsFolder = AgencyBuilder.GetItemsFolder()
local agencySpawn = agency.Spawn
local lobbySpawn, leaderboardGui = nil, nil
if not isRoomServer then
	lobbySpawn, leaderboardGui = AgencyBuilder.BuildHub()
end
ReplicatedStorage:SetAttribute("IsRoomServer", isRoomServer)

local MAX_DISTANCE = TidyConfig.ReachDistance + TidyConfig.ServerDistanceMargin
local MAGNET_COOLDOWN = 0.5

---------------------------------------------------------------------------
-- Canaux de communication avec l'écran du joueur
---------------------------------------------------------------------------
local oldRemotes = ReplicatedStorage:FindFirstChild("TidyRemotes")
if oldRemotes then
	oldRemotes:Destroy()
end
local remotes = Instance.new("Folder")
remotes.Name = "TidyRemotes"

local actionEvent = Instance.new("RemoteEvent")
actionEvent.Name = "Action"
actionEvent.Parent = remotes

local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = remotes

local upgradeFunction = Instance.new("RemoteFunction")
upgradeFunction.Name = "BuyUpgrade"
upgradeFunction.Parent = remotes

local lobbyFunction = Instance.new("RemoteFunction")
lobbyFunction.Name = "Lobby"
lobbyFunction.Parent = remotes

remotes.Parent = ReplicatedStorage

-- Les objets du sac qui ne sont pas en main sont cachés ici.
local heldStorage = Instance.new("Folder")
heldStorage.Name = "TidyHeldItems"
heldStorage.Parent = ServerStorage

---------------------------------------------------------------------------
-- Partie en cours et compteurs
---------------------------------------------------------------------------
local roundNumber = 0
local totals = {}
local placedCounts = {}
local totalItems = 0
local remainingItems = 0
local roomTotals = {}
local roomPlaced = {}

-- Pièces ouvertes : celles qui ne coûtent rien le sont dès le début.
local unlockedRooms = {}
for _, room in TidyConfig.Rooms do
	unlockedRooms[room.Id] = room.Cost <= 0
end

-- Une pièce est ouverte si elle a été payée et si la pièce dont elle dépend est ouverte
-- (les pièces de l'étage dépendent du hall de l'étage, ouvert avec l'ascenseur).
local function isRoomUnlocked(roomId)
	if unlockedRooms[roomId] ~= true then
		return false
	end
	local room = TidyConfig.GetRoom(roomId)
	if room and room.Requires then
		return isRoomUnlocked(room.Requires)
	end
	return true
end

local function updateBillboards()
	for _, zone in agency.Zones do
		local itemType = zone:GetAttribute("ItemType")
		local billboard = zone:FindFirstChild("CategoryBillboard")
		local label = billboard and billboard:FindFirstChild("Text")
		if label then
			label.Text = string.format(
				"%s\n%s: %d / %d",
				zone:GetAttribute("ZoneLabel"),
				TidyConfig.ItemTypes[itemType].Plural,
				placedCounts[itemType] or 0,
				totals[itemType] or 0
			)
		end
	end
end

-- Partage la progression avec l'écran du joueur.
local function publishProgress()
	ReplicatedStorage:SetAttribute("TidyTotal", totalItems)
	ReplicatedStorage:SetAttribute("TidyRemaining", remainingItems)
	for _, itemType in TidyConfig.TypeOrder do
		ReplicatedStorage:SetAttribute("Total_" .. itemType, totals[itemType] or 0)
		ReplicatedStorage:SetAttribute("Placed_" .. itemType, placedCounts[itemType] or 0)
	end
	for _, room in TidyConfig.Rooms do
		ReplicatedStorage:SetAttribute("RoomTotal_" .. room.Id, roomTotals[room.Id] or 0)
		ReplicatedStorage:SetAttribute("RoomPlaced_" .. room.Id, roomPlaced[room.Id] or 0)
		ReplicatedStorage:SetAttribute("Unlocked_" .. room.Id, isRoomUnlocked(room.Id))
	end
	ReplicatedStorage:SetAttribute("AgencyInOrder", totalItems > 0 and remainingItems <= 0)
	updateBillboards()
end

---------------------------------------------------------------------------
-- Joueurs : sac, points, améliorations
---------------------------------------------------------------------------
-- states[player] = { Held = {objets}, Selected = n° en main, Visible = objet affiché,
--                    Weld = soudure à la main, Levels = {...}, Points = n, LastMagnet = t }
local states = {}

local function capacityOf(state)
	return TidyConfig.BaseCapacity + state.Levels.Capacity
end

local function walkSpeedOf(state)
	return TidyConfig.BaseWalkSpeed + 2 * state.Levels.Speed
end

local function magnetRadiusOf(state)
	return TidyConfig.MagnetBaseRadius + TidyConfig.MagnetRadiusPerLevel * (state.Levels.Magnet - 1)
end

local function notify(player, kind, text)
	notifyEvent:FireClient(player, kind, text)
end

-- Partage l'état du joueur avec son écran (sac, points, niveaux).
local function publishPlayer(player, state)
	local types = {}
	local categories = {}
	for index, item in state.Held do
		types[index] = item:GetAttribute("ItemType")
		categories[index] = item:GetAttribute("Category") or "-"
	end
	player:SetAttribute("Held", table.concat(types, ","))
	player:SetAttribute("HeldCategories", table.concat(categories, ","))
	player:SetAttribute("Selected", state.Selected)
	player:SetAttribute("Carrying", types[state.Selected] or "")
	local carriedCategory = categories[state.Selected]
	player:SetAttribute("CarryingCategory", if carriedCategory and carriedCategory ~= "-" then carriedCategory else "")
	player:SetAttribute("Lifetime", state.Lifetime)
	player:SetAttribute("Rank", TidyConfig.GetRank(state.Lifetime).Name)
	if state.RankValue then
		state.RankValue.Value = TidyConfig.GetRank(state.Lifetime).Name
	end
	player:SetAttribute("Capacity", capacityOf(state))
	player:SetAttribute("Points", state.Points)
	for id, level in state.Levels do
		player:SetAttribute("Level_" .. id, level)
	end
	state.PointsValue.Value = state.Points
end

-- Renvoie le HumanoidRootPart d'un personnage vivant, ou nil.
local function getLivingRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return root
end

local function applyWalkSpeed(player, state)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = walkSpeedOf(state)
	end
end

-- Fait passer un objet de "tenu en main" à "posé dans le décor", et inversement.
local function setHeldPhysics(item, held)
	for _, part in item:GetDescendants() do
		if part:IsA("BasePart") then
			if part:GetAttribute("RestCanCollide") == nil then
				part:SetAttribute("RestCanCollide", part.CanCollide)
			end
			if held then
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Massless = true
				part.Anchored = false
			else
				part.Anchored = true
				part.Massless = false
				part.CanTouch = true
				part.CanQuery = true
				part.CanCollide = part:GetAttribute("RestCanCollide")
			end
		end
	end
end

-- Range l'objet tenu en main dans le sac (il devient invisible).
local function stowVisible(state)
	if state.Weld then
		state.Weld:Destroy()
		state.Weld = nil
	end
	local item = state.Visible
	state.Visible = nil
	if item and item.Parent then
		setHeldPhysics(item, false)
		item.Parent = heldStorage
	end
end

-- Met dans les mains l'objet sélectionné du sac.
local function syncHands(player, state)
	local wanted = state.Held[state.Selected]
	if state.Visible == wanted and wanted ~= nil and state.Weld then
		return
	end
	stowVisible(state)
	local root = getLivingRoot(player)
	if not wanted or not root then
		return
	end
	local offset = TidyConfig.ItemTypes[wanted:GetAttribute("ItemType")].CarryOffset
	wanted.Parent = itemsFolder
	wanted:PivotTo(root.CFrame * offset)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = wanted.PrimaryPart
	weld.Parent = wanted.PrimaryPart

	setHeldPhysics(wanted, true)
	state.Visible = wanted
	state.Weld = weld
end

-- Ajoute un objet dans le sac (caché tant qu'il n'est pas en main).
local function addToBag(state, item)
	item:SetAttribute("State", "Carried")
	item.Parent = heldStorage
	table.insert(state.Held, item)
end

-- Remet tous les objets du sac à leur place de départ (mort, départ du joueur).
local function returnAllItems(player)
	local state = states[player]
	if not state then
		return
	end
	stowVisible(state)
	for _, item in state.Held do
		if item.Parent then
			setHeldPhysics(item, false)
			item.Parent = itemsFolder
			item:PivotTo(item:GetAttribute("HomeCFrame"))
			item:SetAttribute("State", "Loose")
		end
	end
	table.clear(state.Held)
	state.Selected = 0
	if player.Parent then
		publishPlayer(player, state)
	end
end

-- Un objet de plus rangé pour une pièce.
-- Renvoie l'identifiant de la pièce si elle vient d'être entièrement terminée.
local function advanceRoom(state, roomId)
	if not roomId or not roomTotals[roomId] then
		return nil
	end
	roomPlaced[roomId] = (roomPlaced[roomId] or 0) + 1
	if roomPlaced[roomId] == roomTotals[roomId] then
		state.Points += TidyConfig.RoomBonus
		return roomId
	end
	return nil
end

local function announceRoom(player, roomId)
	if roomId then
		local room = TidyConfig.GetRoom(roomId)
		notify(player, "room", room.Name .. " is in order. +" .. TidyConfig.RoomBonus .. " bonus points")
	end
end

-- Déclarées ici, définies plus bas (sauvegarde et classement).
local saveData
local updateLeaderboard

---------------------------------------------------------------------------
-- Actions du joueur
---------------------------------------------------------------------------

local function pick(player, state, item)
	if typeof(item) ~= "Instance" or not item:IsDescendantOf(itemsFolder) then
		return
	end
	if not CollectionService:HasTag(item, TidyConfig.ItemTag) or item:GetAttribute("State") ~= "Loose" then
		return
	end
	if not isRoomUnlocked(item:GetAttribute("Room")) then
		notify(player, "error", "This room is still locked.")
		return
	end
	local root = getLivingRoot(player)
	local main = item.PrimaryPart
	if not root or not main then
		return
	end
	if (root.Position - main.Position).Magnitude > MAX_DISTANCE then
		notify(player, "error", "Too far away. Move closer.")
		return
	end
	if #state.Held >= capacityOf(state) then
		notify(player, "error", "Your bag is full. Put some items away first.")
		return
	end

	addToBag(state, item)
	state.Selected = #state.Held
	syncHands(player, state)
	publishPlayer(player, state)
end

local function place(player, state, zone)
	if typeof(zone) ~= "Instance" or not CollectionService:HasTag(zone, TidyConfig.ZoneTag) then
		return
	end
	local zoneType = zone:GetAttribute("ItemType")
	local zoneInfo = TidyConfig.ItemTypes[zoneType]
	if not zoneInfo or not isRoomUnlocked(zone:GetAttribute("Room")) then
		return
	end
	if #state.Held == 0 then
		notify(player, "info", "This spot is for: " .. string.lower(zoneInfo.Plural) .. ".")
		return
	end

	-- L'objet en main s'il convient, sinon le premier objet du sac qui convient.
	-- Livres et colis doivent aussi avoir la même couleur (catégorie) que le meuble.
	local zoneCategory = zone:GetAttribute("Category")
	local function fits(item)
		return item:GetAttribute("ItemType") == zoneType and (zoneCategory == nil or item:GetAttribute("Category") == zoneCategory)
	end
	local index = nil
	local selectedItem = state.Held[state.Selected]
	if selectedItem and fits(selectedItem) then
		index = state.Selected
	else
		for i, item in state.Held do
			if fits(item) then
				index = i
				break
			end
		end
	end
	if not index then
		local category = zoneCategory and TidyConfig.GetCategory(zoneType, zoneCategory)
		if category then
			notify(player, "error", "Wrong shelf. This one is for: " .. category.Name .. ".")
		else
			notify(player, "error", "Wrong place. This spot is for: " .. string.lower(zoneInfo.Plural) .. ".")
		end
		return
	end

	local root = getLivingRoot(player)
	local spots = zone:FindFirstChild("Spots")
	if not root or not spots then
		return
	end

	-- La place libre la plus proche du joueur.
	local bestSlot, bestDistance = nil, math.huge
	for _, slot in spots:GetChildren() do
		if slot:GetAttribute("Occupied") ~= true then
			local distance = (slot.Position - root.Position).Magnitude
			if distance < bestDistance then
				bestSlot, bestDistance = slot, distance
			end
		end
	end
	if not bestSlot then
		notify(player, "error", "This spot is full.")
		return
	end
	if bestDistance > MAX_DISTANCE then
		notify(player, "error", "Move closer to put it away.")
		return
	end

	local item = table.remove(state.Held, index)
	-- Point de départ de l'animation (la main, ou devant le joueur si l'objet était dans le sac).
	local startCFrame = if item.PrimaryPart then item.PrimaryPart.CFrame else bestSlot.CFrame
	if state.Visible ~= item then
		startCFrame = root.CFrame * CFrame.new(0, 0, -2)
	end
	if state.Visible == item then
		stowVisible(state)
	end
	if index < state.Selected then
		state.Selected -= 1
	end
	state.Selected = math.clamp(state.Selected, math.min(1, #state.Held), #state.Held)

	setHeldPhysics(item, false)
	item.Parent = zone
	item:PivotTo(bestSlot.CFrame)
	item:SetAttribute("State", "Placed")
	bestSlot:SetAttribute("Occupied", true)

	state.Points += zoneInfo.Points
	placedCounts[zoneType] = (placedCounts[zoneType] or 0) + 1
	remainingItems -= 1

	local oldRank = TidyConfig.GetRank(state.Lifetime)
	state.Lifetime += 1
	local newRank = TidyConfig.GetRank(state.Lifetime)

	local roomDone = advanceRoom(state, item:GetAttribute("Room"))

	syncHands(player, state)
	publishPlayer(player, state)
	publishProgress()
	notifyEvent:FireClient(player, "placed", "+" .. zoneInfo.Points .. " points", bestSlot.Position, item, startCFrame)
	announceRoom(player, roomDone)
	if newRank ~= oldRank then
		notify(player, "room", "Promotion! You are now: " .. newRank.Name)
	end
	-- Journée terminée : tout est rangé.
	if remainingItems <= 0 then
		for otherPlayer, otherState in states do
			otherState.DaysCompleted += 1
			task.spawn(saveData, otherPlayer, otherState)
		end
	end
end

-- Ouvre une pièce verrouillée avec les points du joueur.
local function unlock(player, state, door)
	if typeof(door) ~= "Instance" or not CollectionService:HasTag(door, TidyConfig.DoorTag) then
		return
	end
	local roomId = door:GetAttribute("Room")
	local room = TidyConfig.GetRoom(roomId)
	if not room or isRoomUnlocked(roomId) then
		return
	end
	local root = getLivingRoot(player)
	if not root or (root.Position - door.Position).Magnitude > MAX_DISTANCE then
		notify(player, "error", "Move closer to the door.")
		return
	end
	if state.Points < room.Cost then
		notify(player, "error", "You need " .. room.Cost .. " points to open the " .. room.Name .. ".")
		return
	end
	state.Points -= room.Cost
	unlockedRooms[roomId] = true
	for _, other in agency.Doors do
		if other.Parent and other:GetAttribute("Room") == roomId then
			other:Destroy()
		end
	end
	publishPlayer(player, state)
	publishProgress()
	notify(player, "room", "The " .. room.Name .. " is now open.")
end

-- Hauteur de la surface sous un point (sol, bureau...), sinon le sol.
local function findSurfaceY(position, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, itemsFolder }
	local result = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
	if result then
		return result.Position.Y
	end
	return position.Y - 3
end

local function drop(player, state)
	local item = state.Held[state.Selected]
	local root = getLivingRoot(player)
	if not item or not root then
		return
	end
	table.remove(state.Held, state.Selected)
	if state.Visible == item then
		stowVisible(state)
	end
	state.Selected = math.min(state.Selected, #state.Held)

	local front = (root.CFrame * CFrame.new(0, 0, -3)).Position
	local x = math.clamp(front.X, -AgencyBuilder.HalfX + 1.5, AgencyBuilder.HalfX - 1.5)
	local z = math.clamp(front.Z, AgencyBuilder.MinZ + 1.5, AgencyBuilder.MaxZ - 1.5)
	local surfaceY = findSurfaceY(Vector3.new(x, root.Position.Y, z), player.Character)
	local home = CFrame.new(x, surfaceY + item:GetAttribute("RestHeight"), z) * root.CFrame.Rotation

	setHeldPhysics(item, false)
	item.Parent = itemsFolder
	item:PivotTo(home)
	item:SetAttribute("HomeCFrame", home)
	item:SetAttribute("State", "Loose")

	syncHands(player, state)
	publishPlayer(player, state)
end

local function cycle(player, state, direction)
	local count = #state.Held
	if count <= 1 or (direction ~= 1 and direction ~= -1) then
		return
	end
	state.Selected = ((state.Selected - 1 + direction) % count) + 1
	syncHands(player, state)
	publishPlayer(player, state)
end

local function useMagnet(player, state)
	if state.Levels.Magnet < 1 then
		notify(player, "error", "Unlock the magnet in the upgrades menu.")
		return
	end
	local now = os.clock()
	if now - state.LastMagnet < MAGNET_COOLDOWN then
		return
	end
	state.LastMagnet = now

	local root = getLivingRoot(player)
	if not root then
		return
	end
	local free = capacityOf(state) - #state.Held
	if free <= 0 then
		notify(player, "error", "Your bag is full. Put some items away first.")
		return
	end

	local radius = magnetRadiusOf(state)
	local candidates = {}
	for _, item in itemsFolder:GetChildren() do
		if item:GetAttribute("State") == "Loose" and item.PrimaryPart and isRoomUnlocked(item:GetAttribute("Room")) then
			local distance = (item.PrimaryPart.Position - root.Position).Magnitude
			if distance <= radius then
				table.insert(candidates, { Item = item, Distance = distance })
			end
		end
	end
	if #candidates == 0 then
		notify(player, "info", "No items within the magnet's range.")
		return
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)

	local taken = math.min(free, #candidates)
	for i = 1, taken do
		addToBag(state, candidates[i].Item)
	end
	state.Selected = #state.Held
	syncHands(player, state)
	publishPlayer(player, state)
	notify(player, "info", "Magnet: " .. taken .. " item(s) collected.")
end

---------------------------------------------------------------------------
-- Parties
---------------------------------------------------------------------------
local function startRound()
	for player in states do
		returnAllItems(player)
	end

	roundNumber += 1
	local items = AgencyBuilder.ScatterItems(Random.new():NextInteger(1, 1000000000))

	totals = {}
	placedCounts = {}
	roomTotals = {}
	roomPlaced = {}
	for _, item in items do
		local itemType = item:GetAttribute("ItemType")
		totals[itemType] = (totals[itemType] or 0) + 1
		local roomId = item:GetAttribute("Room")
		roomTotals[roomId] = (roomTotals[roomId] or 0) + 1
	end

	totalItems = #items
	remainingItems = totalItems

	publishProgress()
	-- Annoncé en dernier : l'écran du joueur voit déjà les nouveaux compteurs.
	ReplicatedStorage:SetAttribute("RoundNumber", roundNumber)
end

actionEvent.OnServerEvent:Connect(function(player, action, target)
	local state = states[player]
	if not state or type(action) ~= "string" then
		return
	end
	if action == "pick" then
		pick(player, state, target)
	elseif action == "place" then
		place(player, state, target)
	elseif action == "drop" then
		drop(player, state)
	elseif action == "cycle" then
		cycle(player, state, target)
	elseif action == "magnet" then
		useMagnet(player, state)
	elseif action == "unlock" then
		unlock(player, state, target)

	elseif action == "restart" then
		if remainingItems <= 0 then
			startRound()
		end
	end
end)

upgradeFunction.OnServerInvoke = function(player, upgradeId)
	local state = states[player]
	if not state or type(upgradeId) ~= "string" then
		return false, "Not possible right now."
	end
	local upgrade = TidyConfig.GetUpgrade(upgradeId)
	if not upgrade then
		return false, "Unknown upgrade."
	end
	local level = state.Levels[upgradeId] or 0
	if level >= upgrade.MaxLevel then
		return false, "Already at the maximum level."
	end
	local cost = TidyConfig.GetUpgradeCost(upgrade, level)
	if state.Points < cost then
		return false, "Not enough points. You need " .. cost .. "."
	end

	state.Points -= cost
	state.Levels[upgradeId] = level + 1
	if upgradeId == "Speed" then
		applyWalkSpeed(player, state)
	end
	publishPlayer(player, state)
	return true, upgrade.Name .. ": level " .. (level + 1)
end

---------------------------------------------------------------------------
-- Sauvegarde de la progression (points, améliorations, pièces ouvertes, rang, bonus quotidien)
---------------------------------------------------------------------------
local SAVE_VERSION = 1
local dataStore = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("NorthfieldAgency_v1")
	end)
	if ok then
		dataStore = store
	end
end

local lifetimeStore = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("NorthfieldLifetime_v1")
	end)
	if ok then
		lifetimeStore = store
	end
end

local function saveKey(player)
	return "player_" .. player.UserId
end

-- Charge la sauvegarde. Renvoie (true, données ou nil) si la lecture a réussi, false sinon.
local function loadData(player)
	if not dataStore then
		return false, nil
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return dataStore:GetAsync(saveKey(player))
		end)
		if ok then
			return true, result
		end
		task.wait(attempt)
	end
	return false, nil
end

local function buildSaveData(state)
	local unlocked = {}
	for _, room in TidyConfig.Rooms do
		if unlockedRooms[room.Id] or state.SavedUnlocked[room.Id] then
			table.insert(unlocked, room.Id)
		end
	end
	return {
		Version = SAVE_VERSION,
		Points = state.Points,
		Levels = state.Levels,
		Unlocked = unlocked,
		Lifetime = state.Lifetime,
		Streak = state.Streak,
		LastDay = state.LastDay,
		DaysCompleted = state.DaysCompleted,
	}
end

function saveData(player, state)
	-- Jamais d'écriture si la lecture a échoué : on ne doit pas écraser une vraie sauvegarde.
	if not dataStore or not state or not state.CanSave then
		return
	end
	local data = buildSaveData(state)
	for attempt = 1, 3 do
		local ok = pcall(function()
			dataStore:UpdateAsync(saveKey(player), function()
				return data
			end)
		end)
		if ok then
			if lifetimeStore then
				pcall(function()
					lifetimeStore:SetAsync(tostring(player.UserId), state.Lifetime)
				end)
			end
			return
		end
		task.wait(attempt)
	end
	warn("[TidyManager] Could not save progress for " .. player.Name)
end

-- Applique une sauvegarde chargée à l'état du joueur.
local function applySaveData(player, state, data)
	if type(data) ~= "table" then
		return
	end
	state.Points = math.max(0, tonumber(data.Points) or 0)
	state.Lifetime = math.max(0, tonumber(data.Lifetime) or 0)
	state.Streak = math.max(0, tonumber(data.Streak) or 0)
	state.LastDay = tonumber(data.LastDay) or 0
	state.DaysCompleted = math.max(0, tonumber(data.DaysCompleted) or 0)
	if type(data.Levels) == "table" then
		for _, upgrade in TidyConfig.Upgrades do
			local level = tonumber(data.Levels[upgrade.Id]) or 0
			state.Levels[upgrade.Id] = math.clamp(math.floor(level), 0, upgrade.MaxLevel)
		end
	end
	if type(data.Unlocked) == "table" then
		local changed = false
		for _, roomId in data.Unlocked do
			if TidyConfig.GetRoom(roomId) then
				state.SavedUnlocked[roomId] = true
				if not unlockedRooms[roomId] then
					unlockedRooms[roomId] = true
					changed = true
					for _, door in agency.Doors do
						if door.Parent and door:GetAttribute("Room") == roomId then
							door:Destroy()
						end
					end
				end
			end
		end
		if changed then
			publishProgress()
		end
	end
end

-- Bonus quotidien : plus on revient de jours de suite, plus il est grand.
local function giveDailyBonus(player, state)
	local today = math.floor(os.time() / 86400)
	if state.LastDay == today then
		return
	end
	if state.LastDay == today - 1 then
		state.Streak += 1
	else
		state.Streak = 1
	end
	state.LastDay = today
	local bonus = TidyConfig.DailyBonusPerDay * math.min(state.Streak, TidyConfig.DailyBonusMaxDays)
	state.Points += bonus
	notify(player, "room", "Daily bonus: +" .. bonus .. " points (day " .. state.Streak .. " in a row)")
end

---------------------------------------------------------------------------
-- Zone d'accueil : jouer ici, créer un salon privé, rejoindre avec un code
---------------------------------------------------------------------------
local CODE_LETTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local roomCodes = nil
do
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap("NorthfieldRoomCodes")
	end)
	if ok then
		roomCodes = map
	end
end

local function newRoomCode()
	local chars = {}
	for i = 1, 6 do
		local n = math.random(1, #CODE_LETTERS)
		chars[i] = string.sub(CODE_LETTERS, n, n)
	end
	return table.concat(chars)
end

-- Envoie le joueur dans l'agence de ce serveur.
local function enterAgency(player)
	player:SetAttribute("InAgency", true)
	player.RespawnLocation = agencySpawn
	local character = player.Character
	if character then
		character:PivotTo(agencySpawn.CFrame + Vector3.new(0, 3, 0))
	end
end

local function teleportToRoom(player, accessCode, code)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData({ RoomCode = code })
	TeleportService:TeleportAsync(game.PlaceId, { player }, options)
end

lobbyFunction.OnServerInvoke = function(player, action, argument)
	if action == "PlayHere" then
		enterAgency(player)
		return true, "Welcome to the agency."
	end
	if RunService:IsStudio() or game.PlaceId == 0 then
		return false, "Private rooms only work in the published game. Use Play here to test."
	end
	if action == "Create" then
		local ok, accessCode = pcall(function()
			return TeleportService:ReserveServer(game.PlaceId)
		end)
		if not ok or not accessCode or not roomCodes then
			return false, "Could not create a room right now. Please try again."
		end
		local code = newRoomCode()
		local saved = pcall(function()
			roomCodes:SetAsync(code, accessCode, TidyConfig.RoomCodeLifetime)
		end)
		if not saved then
			return false, "Could not create a room right now. Please try again."
		end
		local sent = pcall(teleportToRoom, player, accessCode, code)
		if not sent then
			return false, "Teleport failed. Please try again."
		end
		return true, "Room " .. code .. " created. Teleporting..."
	elseif action == "Join" then
		local code = string.upper(string.gsub(tostring(argument or ""), "%s", ""))
		if #code ~= 6 or not roomCodes then
			return false, "Please enter a 6-character room code."
		end
		local ok, accessCode = pcall(function()
			return roomCodes:GetAsync(code)
		end)
		if not ok or type(accessCode) ~= "string" then
			return false, "No room found with this code."
		end
		local sent = pcall(teleportToRoom, player, accessCode, code)
		if not sent then
			return false, "Teleport failed. Please try again."
		end
		return true, "Joining room " .. code .. "..."
	end
	return false, "Unknown action."
end

TeleportService.TeleportInitFailed:Connect(function(player, _, message)
	notify(player, "error", "Teleport failed: " .. tostring(message))
end)

---------------------------------------------------------------------------
-- Arrivée et départ des joueurs
---------------------------------------------------------------------------

local function onCharacterAdded(player, character)
	local state = states[player]
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and state then
		humanoid.WalkSpeed = walkSpeedOf(state)
		humanoid.Died:Connect(function()
			returnAllItems(player)
		end)
	end
end

local function onPlayerAdded(player)
	if states[player] then
		return
	end
	-- Point d'apparition : la zone d'accueil (serveurs publics) ou l'agence (salons privés).
	if isRoomServer or not lobbySpawn then
		player:SetAttribute("InAgency", true)
		player.RespawnLocation = agencySpawn
	else
		player:SetAttribute("InAgency", false)
		player.RespawnLocation = lobbySpawn
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local pointsValue = Instance.new("IntValue")
	pointsValue.Name = "Points"
	pointsValue.Value = 0
	pointsValue.Parent = leaderstats
	local rankValue = Instance.new("StringValue")
	rankValue.Name = "Rank"
	rankValue.Value = TidyConfig.Ranks[1].Name
	rankValue.Parent = leaderstats
	leaderstats.Parent = player

	local state = {
		Held = {},
		Selected = 0,
		Visible = nil,
		Weld = nil,
		Levels = { Capacity = 0, Speed = 0, Magnet = 0, Magnifier = 0 },
		Points = 0,
		Lifetime = 0,
		Streak = 0,
		LastDay = 0,
		DaysCompleted = 0,
		SavedUnlocked = {},
		CanSave = false,
		LastMagnet = -math.huge,
		PointsValue = pointsValue,
		RankValue = rankValue,
	}
	states[player] = state
	publishPlayer(player, state)

	-- Code du salon privé, pour l'afficher aux joueurs (et qu'ils invitent leurs amis).
	if isRoomServer then
		local joinData = player:GetJoinData()
		local teleportData = joinData and joinData.TeleportData
		if type(teleportData) == "table" and type(teleportData.RoomCode) == "string" then
			ReplicatedStorage:SetAttribute("RoomCode", teleportData.RoomCode)
		end
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		returnAllItems(player)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	-- Chargement de la sauvegarde (sans bloquer l'arrivée du joueur).
	task.spawn(function()
		local ok, data = loadData(player)
		if not player.Parent or states[player] ~= state then
			return
		end
		if ok then
			applySaveData(player, state, data)
			state.CanSave = true
		else
			notify(player, "error", "Progress could not be loaded. It will not be saved this session.")
		end
		giveDailyBonus(player, state)
		applyWalkSpeed(player, state)
		publishPlayer(player, state)
		task.spawn(updateLeaderboard)
	end)
end

---------------------------------------------------------------------------
-- Ascenseur : marcher sur le plateau de la cabine fait changer d'étage
---------------------------------------------------------------------------
local lastLift = {}
for _, pad in CollectionService:GetTagged("TidyLift") do
	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		if lastLift[player] and now - lastLift[player] < 2 then
			return
		end
		local requires = pad:GetAttribute("RequiresRoom")
		if requires and not isRoomUnlocked(requires) then
			return
		end
		local target = pad:GetAttribute("Target")
		if typeof(target) ~= "Vector3" then
			return
		end
		lastLift[player] = now
		character:PivotTo(CFrame.new(target) * CFrame.Angles(0, math.pi, 0))
		notify(player, "info", if target.Y > 10 then "Upper floor" else "Ground floor")
	end)
end

---------------------------------------------------------------------------
-- Classement du lobby : meilleurs ranger (sauvegarde globale, sinon joueurs présents)
---------------------------------------------------------------------------
function updateLeaderboard()
	if not leaderboardGui then
		return
	end
	local entries = {}
	local ok = pcall(function()
		local pages = lifetimeStore:GetSortedAsync(false, 10)
		for _, entry in pages:GetCurrentPage() do
			local name = "Player"
			pcall(function()
				name = Players:GetNameFromUserIdAsync(tonumber(entry.key))
			end)
			table.insert(entries, { Name = name, Items = entry.value })
		end
	end)
	if not ok or #entries == 0 then
		entries = {}
		for player, state in states do
			table.insert(entries, { Name = player.Name, Items = state.Lifetime })
		end
		table.sort(entries, function(a, b)
			return a.Items > b.Items
		end)
	end
	for i = 1, 10 do
		local line = leaderboardGui:FindFirstChild("Line" .. i)
		local entry = entries[i]
		if line then
			line.Text = if entry then (i .. ".  " .. entry.Name .. "  -  " .. entry.Items .. " items") else (i .. ".  ---")
		end
	end
end

startRound()

task.spawn(function()
	while true do
		updateLeaderboard()
		task.wait(60)
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	returnAllItems(player)
	local state = states[player]
	states[player] = nil
	saveData(player, state)
end)

-- Sauvegarde automatique toutes les 2 minutes, et à la fermeture du serveur.
task.spawn(function()
	while true do
		task.wait(120)
		for player, state in states do
			task.spawn(saveData, player, state)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player, state in states do
		pending += 1
		task.spawn(function()
			saveData(player, state)
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait(0.5)
	end
end)
