-- TidyManager (Script)
-- Emplacement : ServerScriptService
-- Logique principale du jeu : construit l'agence, gère le sac du joueur (ramasser
-- au clic, ranger, lâcher, changer d'objet), l'aimant, les points, les améliorations,
-- les compteurs, et relance une partie quand tout est rangé.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local TidyConfig = require(ReplicatedStorage:WaitForChild("TidyConfig"))
local AgencyBuilder = require(ServerScriptService:WaitForChild("AgencyBuilder"))

local agency = AgencyBuilder.Build()
local itemsFolder = AgencyBuilder.GetItemsFolder()

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

local function updateBillboards()
	for _, zone in agency.Zones do
		local itemType = zone:GetAttribute("ItemType")
		local billboard = zone:FindFirstChild("CategoryBillboard")
		local label = billboard and billboard:FindFirstChild("Text")
		if label then
			label.Text = string.format(
				"%s\n%s : %d / %d",
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
	for index, item in state.Held do
		types[index] = item:GetAttribute("ItemType")
	end
	player:SetAttribute("Held", table.concat(types, ","))
	player:SetAttribute("Selected", state.Selected)
	player:SetAttribute("Carrying", types[state.Selected] or "")
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
	local root = getLivingRoot(player)
	local main = item.PrimaryPart
	if not root or not main then
		return
	end
	if (root.Position - main.Position).Magnitude > MAX_DISTANCE then
		notify(player, "error", "Trop loin ! Approchez-vous.")
		return
	end
	if #state.Held >= capacityOf(state) then
		notify(player, "error", "Sac plein ! Rangez d'abord vos objets.")
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
	if not zoneInfo then
		return
	end
	if #state.Held == 0 then
		notify(player, "info", "Ici, on range : " .. string.lower(zoneInfo.Plural) .. ".")
		return
	end

	-- L'objet en main s'il convient, sinon le premier objet du sac qui convient.
	local index = nil
	local selectedItem = state.Held[state.Selected]
	if selectedItem and selectedItem:GetAttribute("ItemType") == zoneType then
		index = state.Selected
	else
		for i, item in state.Held do
			if item:GetAttribute("ItemType") == zoneType then
				index = i
				break
			end
		end
	end
	if not index then
		notify(player, "error", "Ce n'est pas le bon endroit. Ici, on range : " .. string.lower(zoneInfo.Plural) .. ".")
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
		notify(player, "error", "Cet endroit est complet.")
		return
	end
	if bestDistance > MAX_DISTANCE then
		notify(player, "error", "Approchez-vous pour ranger.")
		return
	end

	local item = table.remove(state.Held, index)
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

	syncHands(player, state)
	publishPlayer(player, state)
	publishProgress()
	notify(player, "points", "+" .. zoneInfo.Points .. " points")
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
	return AgencyBuilder.FloorTop
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
	local x = math.clamp(front.X, -38.5, 38.5)
	local z = math.clamp(front.Z, -28.5, 28.5)
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
		notify(player, "error", "Débloquez l'aimant dans les améliorations.")
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
		notify(player, "error", "Sac plein ! Rangez d'abord vos objets.")
		return
	end

	local radius = magnetRadiusOf(state)
	local candidates = {}
	for _, item in itemsFolder:GetChildren() do
		if item:GetAttribute("State") == "Loose" and item.PrimaryPart then
			local distance = (item.PrimaryPart.Position - root.Position).Magnitude
			if distance <= radius then
				table.insert(candidates, { Item = item, Distance = distance })
			end
		end
	end
	if #candidates == 0 then
		notify(player, "info", "Aucun objet à portée de l'aimant.")
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
	notify(player, "info", "Aimant : " .. taken .. " objet(s) attrapé(s).")
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
	for _, item in items do
		local itemType = item:GetAttribute("ItemType")
		totals[itemType] = (totals[itemType] or 0) + 1
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
	elseif action == "restart" then
		if remainingItems <= 0 then
			startRound()
		end
	end
end)

upgradeFunction.OnServerInvoke = function(player, upgradeId)
	local state = states[player]
	if not state or type(upgradeId) ~= "string" then
		return false, "Action impossible."
	end
	local upgrade = TidyConfig.GetUpgrade(upgradeId)
	if not upgrade then
		return false, "Amélioration inconnue."
	end
	local level = state.Levels[upgradeId] or 0
	if level >= upgrade.MaxLevel then
		return false, "Niveau maximum atteint."
	end
	local cost = TidyConfig.GetUpgradeCost(upgrade, level)
	if state.Points < cost then
		return false, "Pas assez de points : il en faut " .. cost .. "."
	end

	state.Points -= cost
	state.Levels[upgradeId] = level + 1
	if upgradeId == "Speed" then
		applyWalkSpeed(player, state)
	end
	publishPlayer(player, state)
	return true, upgrade.Name .. " : niveau " .. (level + 1) .. " !"
end

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
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local pointsValue = Instance.new("IntValue")
	pointsValue.Name = "Points"
	pointsValue.Value = 0
	pointsValue.Parent = leaderstats
	leaderstats.Parent = player

	local state = {
		Held = {},
		Selected = 0,
		Visible = nil,
		Weld = nil,
		Levels = { Capacity = 0, Speed = 0, Magnet = 0, Magnifier = 0 },
		Points = 0,
		LastMagnet = -math.huge,
		PointsValue = pointsValue,
	}
	states[player] = state
	publishPlayer(player, state)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		returnAllItems(player)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

startRound()

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	returnAllItems(player)
	states[player] = nil
end)
