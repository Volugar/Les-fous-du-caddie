-- TidyManager (Script)
-- Emplacement : ServerScriptService
-- Logique principale du jeu :
--  * construit le hall d'accueil (files d'attente, boutique) et le niveau choisi ;
--  * gère le panier du joueur (ramasser, ranger, lâcher, changer d'objet), la pile d'objets
--    portés visible dans les mains, l'aimant, le rangement rapide ;
--  * points, améliorations, pièces qui s'ouvrent selon les points GAGNÉS (rien n'est perdu),
--    victoires, rangs, bonus quotidien, quêtes du jour ;
--  * sauvegarde (y compris la progression de la journée en cours) ;
--  * boutique Robux (pass et produits) ;
--  * départ en groupe vers un serveur réservé, codes pour rejoindre un ami.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
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

-- Serveur réservé (créé par une file d'attente du hall) : on y joue directement le niveau choisi.
local isRoomServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local isTestServer = RunService:IsStudio() or game.PlaceId == 0
ReplicatedStorage:SetAttribute("IsRoomServer", isRoomServer)

local MAX_DISTANCE = TidyConfig.ReachDistance + TidyConfig.ServerDistanceMargin
local MAGNET_COOLDOWN = 0.5
local STACK_MAX_HEIGHT = 5.5

AgencyBuilder.ClearTemplate()
local hub = nil
if not isRoomServer then
	hub = AgencyBuilder.BuildHub()
end
if isRoomServer then
	-- Les personnages n'apparaissent qu'une fois le niveau construit.
	Players.CharacterAutoLoads = false
end

---------------------------------------------------------------------------
-- Canaux de communication avec l'écran du joueur
---------------------------------------------------------------------------
local oldRemotes = ReplicatedStorage:FindFirstChild("TidyRemotes")
if oldRemotes then
	oldRemotes:Destroy()
end
local remotes = Instance.new("Folder")
remotes.Name = "TidyRemotes"
local function newRemote(className, name)
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end
local actionEvent = newRemote("RemoteEvent", "Action")
local notifyEvent = newRemote("RemoteEvent", "Notify")
local upgradeFunction = newRemote("RemoteFunction", "BuyUpgrade")
local lobbyFunction = newRemote("RemoteFunction", "Lobby")
local queueEvent = newRemote("RemoteEvent", "Queue")
local shopFunction = newRemote("RemoteFunction", "Shop")
local settingsEvent = newRemote("RemoteEvent", "Settings")
remotes.Parent = ReplicatedStorage

-- Les objets du panier qui ne sont pas visibles sont cachés ici.
local heldStorage = Instance.new("Folder")
heldStorage.Name = "TidyHeldItems"
heldStorage.Parent = ServerStorage

---------------------------------------------------------------------------
-- Niveau en cours et compteurs
---------------------------------------------------------------------------
local level = nil -- résultat de AgencyBuilder.Build (nil tant qu'aucun niveau n'est construit)
local activeMap = nil
local itemsFolder = nil
local roundNumber = 0
local totals, placedCounts = {}, {}
local zoneCounts, zoneTotals = {}, {}
local totalItems, remainingItems = 0, 0
local roomTotals, roomPlaced = {}, {}
local placedRecord = {} -- "pièce|type|catégorie" -> nombre rangé aujourd'hui
local placedThisRound = 0
local roundStartedAt = os.clock()
local roundTimed = true -- faux si la journée a repris une sauvegarde (temps non comparable)
local roundRestored = false
local unlockedRooms = {}

local states = {}

local function notify(player, kind, text, ...)
	notifyEvent:FireClient(player, kind, text, ...)
end

local function notifyMap(kind, text)
	for player, state in states do
		if state.InMap then
			notify(player, kind, text)
		end
	end
end

local function categoryKey(item)
	return item:GetAttribute("ItemType") .. "|" .. (item:GetAttribute("Category") or "-")
end

-- Une pièce est ouverte si elle a atteint son seuil et si la pièce dont elle dépend est ouverte.
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

local function updateZoneBillboards(onlyKey)
	if not level then
		return
	end
	for _, zone in level.Zones do
		local key = zone:GetAttribute("ItemType") .. "|" .. (zone:GetAttribute("Category") or "-")
		if onlyKey == nil or key == onlyKey then
			local billboard = zone:FindFirstChild("CategoryBillboard")
			local panel = billboard and billboard:FindFirstChild("Panel")
			local label = panel and panel:FindFirstChild("Text")
			if label then
				local info = TidyConfig.ItemTypes[zone:GetAttribute("ItemType")]
				label.Text = string.format("%s %s\n%d / %d", info.Icon, zone:GetAttribute("ZoneLabel"), zoneCounts[key] or 0, zoneTotals[key] or 0)
			end
		end
	end
end

-- Partage la progression du niveau avec l'écran des joueurs.
local function publishProgress(changedKey)
	ReplicatedStorage:SetAttribute("ActiveMap", activeMap or "")
	ReplicatedStorage:SetAttribute("TidyTotal", totalItems)
	ReplicatedStorage:SetAttribute("TidyRemaining", remainingItems)
	for _, itemType in TidyConfig.TypeOrder do
		ReplicatedStorage:SetAttribute("Total_" .. itemType, totals[itemType] or 0)
		ReplicatedStorage:SetAttribute("Placed_" .. itemType, placedCounts[itemType] or 0)
	end
	if activeMap then
		for _, room in TidyConfig.GetMapRooms(activeMap) do
			ReplicatedStorage:SetAttribute("RoomTotal_" .. room.Id, roomTotals[room.Id] or 0)
			ReplicatedStorage:SetAttribute("RoomPlaced_" .. room.Id, roomPlaced[room.Id] or 0)
			ReplicatedStorage:SetAttribute("Unlocked_" .. room.Id, isRoomUnlocked(room.Id))
		end
	end
	ReplicatedStorage:SetAttribute("LevelInOrder", totalItems > 0 and remainingItems <= 0)
	updateZoneBillboards(changedKey)
end

---------------------------------------------------------------------------
-- Joueurs : panier, points, améliorations, pass
---------------------------------------------------------------------------
local function hasPass(state, passId)
	return state.Passes[passId] == true
end

local function capacityOf(state)
	local capacity = TidyConfig.BaseCapacity + state.Levels.Capacity
	if hasPass(state, "Carry5") then
		capacity += TidyConfig.PassEffects.Carry5
	end
	if hasPass(state, "Carry15") then
		capacity += TidyConfig.PassEffects.Carry15
	end
	if state.DealBought then
		capacity += TidyConfig.DealCarryBonus
	end
	return capacity
end

local function walkSpeedOf(state)
	if hasPass(state, "MaxSpeed") then
		local speedUpgrade = TidyConfig.GetUpgrade("Speed")
		return TidyConfig.BaseWalkSpeed + 2 * speedUpgrade.MaxLevel + TidyConfig.PassEffects.MaxSpeedBonus
	end
	return TidyConfig.BaseWalkSpeed + 2 * state.Levels.Speed
end

local function magnetUnlocked(state)
	return state.Levels.Magnet >= 1 or hasPass(state, "InfiniteMagnet")
end

local function magnetRadiusOf(state)
	if hasPass(state, "InfiniteMagnet") then
		return TidyConfig.PassEffects.InfiniteMagnetRadius
	end
	return TidyConfig.MagnetBaseRadius + TidyConfig.MagnetRadiusPerLevel * math.max(0, state.Levels.Magnet - 1)
end

local function pointsMultiplier(state)
	local multiplier = 1
	if hasPass(state, "DoublePoints") then
		multiplier *= TidyConfig.PassEffects.DoublePoints
	end
	if hasPass(state, "VIP") then
		multiplier *= TidyConfig.PassEffects.VIPPoints
	end
	return multiplier
end

-- Quêtes du jour, sous une forme lisible par l'écran du joueur.
local function questView(player, state)
	local view = {}
	for i, templateIndex in state.Quests.Indices do
		local template = TidyConfig.QuestTemplates[templateIndex]
		if template then
			table.insert(view, {
				Text = string.format(template.Text, template.Target),
				Target = template.Target,
				Progress = math.min(state.Quests.Progress[i] or 0, template.Target),
				Reward = template.Reward,
				Done = state.Quests.Done[i] == true,
			})
		end
	end
	return view
end

-- Partage l'état du joueur avec son écran.
local function publishPlayer(player, state)
	local types, categories, names = {}, {}, {}
	for index, item in state.Held do
		types[index] = item:GetAttribute("ItemType")
		categories[index] = item:GetAttribute("Category") or "-"
		names[index] = item:GetAttribute("ItemName") or types[index]
	end
	player:SetAttribute("Held", table.concat(types, ","))
	player:SetAttribute("HeldCategories", table.concat(categories, ","))
	player:SetAttribute("HeldNames", table.concat(names, "|"))
	player:SetAttribute("Selected", state.Selected)
	player:SetAttribute("Carrying", types[state.Selected] or "")
	local carriedCategory = categories[state.Selected]
	player:SetAttribute("CarryingCategory", if carriedCategory and carriedCategory ~= "-" then carriedCategory else "")
	player:SetAttribute("CarryingName", names[state.Selected] or "")
	player:SetAttribute("Capacity", capacityOf(state))
	player:SetAttribute("Points", state.Points)
	player:SetAttribute("Lifetime", state.Lifetime)
	player:SetAttribute("Rank", TidyConfig.GetRank(state.Lifetime).Name)
	player:SetAttribute("Wins", state.Wins)
	player:SetAttribute("MagnetUnlocked", magnetUnlocked(state))
	player:SetAttribute("DealBought", state.DealBought)
	for _, map in TidyConfig.Maps do
		player:SetAttribute("Earned_" .. map.Id, state.Earned[map.Id] or 0)
	end
	for id, levelValue in state.Levels do
		player:SetAttribute("Level_" .. id, levelValue)
	end
	for _, pass in TidyConfig.GamePasses do
		player:SetAttribute("Pass_" .. pass.Id, hasPass(state, pass.Id))
	end
	player:SetAttribute("Quests", HttpService:JSONEncode(questView(player, state)))
	player:SetAttribute("Settings", HttpService:JSONEncode(state.Settings))
	state.PointsValue.Value = state.Points
	state.RankValue.Value = TidyConfig.GetRank(state.Lifetime).Name
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

-- Étiquette dorée "VIP" au-dessus de la tête.
local function applyVipTag(player, state)
	local character = player.Character
	local head = character and (character:FindFirstChild("Head") or character:WaitForChild("Head", 5))
	if not head then
		return
	end
	local existing = head:FindFirstChild("VipTag")
	if not hasPass(state, "VIP") then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "VipTag"
	tag.Size = UDim2.fromScale(3, 0.9)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	tag.MaxDistance = 80
	tag.LightInfluence = 0
	tag.Adornee = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.Text = "👑 VIP"
	label.TextColor3 = Color3.fromRGB(255, 210, 70)
	label.TextStrokeColor3 = Color3.fromRGB(90, 50, 10)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = tag
	tag.Parent = head
end

-- Fait passer un objet de "porté" à "posé dans le décor", et inversement.
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

local function clearWelds(state)
	for _, weld in state.Welds do
		if weld.Parent then
			weld:Destroy()
		end
	end
	table.clear(state.Welds)
end

-- Pile d'objets portés, visible dans les mains (l'objet choisi est en haut de la pile).
local function stackHeld(player, state)
	clearWelds(state)
	local root = getLivingRoot(player)
	local selected = state.Held[state.Selected]
	local order = {}
	for index, item in state.Held do
		if index ~= state.Selected then
			table.insert(order, item)
		end
	end
	if selected then
		table.insert(order, selected)
	end
	-- On ne montre que le haut de la pile s'il y a trop d'objets.
	local shown = {}
	local height = 0
	for i = #order, 1, -1 do
		local item = order[i]
		local itemHeight = AgencyBuilder.GetItemHeight(item:GetAttribute("ItemType"))
		if root and (height + itemHeight <= STACK_MAX_HEIGHT or #shown == 0) then
			table.insert(shown, 1, item)
			height += itemHeight
		end
	end
	local visible = {}
	for _, item in shown do
		visible[item] = true
	end
	for _, item in state.Held do
		if not visible[item] and item.Parent ~= heldStorage then
			setHeldPhysics(item, true)
			item.Parent = heldStorage
		end
	end
	if not root then
		return
	end
	local base = root.CFrame * CFrame.new(1.3, -1, -2.4)
	local y = 0
	for _, item in shown do
		local main = item.PrimaryPart
		if main then
			setHeldPhysics(item, true)
			item.Parent = itemsFolder
			item:PivotTo(base * CFrame.new(0, y + (item:GetAttribute("RestHeight") or 0.3), 0))
			local weld = Instance.new("WeldConstraint")
			weld.Name = "CarryWeld"
			weld.Part0 = root
			weld.Part1 = main
			weld.Parent = main
			state.Welds[item] = weld
			y += AgencyBuilder.GetItemHeight(item:GetAttribute("ItemType"))
		end
	end
end

local function addToBag(state, item)
	item:SetAttribute("State", "Carried")
	table.insert(state.Held, item)
end

-- Remet tous les objets du panier à leur place de départ (mort, départ, changement de niveau).
local function returnAllItems(player)
	local state = states[player]
	if not state then
		return
	end
	clearWelds(state)
	for _, item in state.Held do
		if item.Parent and itemsFolder then
			setHeldPhysics(item, false)
			item.Parent = itemsFolder
			item:PivotTo(item:GetAttribute("HomeCFrame"))
			item:SetAttribute("State", "Loose")
		elseif item.Parent then
			item:Destroy()
		end
	end
	table.clear(state.Held)
	state.Selected = 0
	if player.Parent then
		publishPlayer(player, state)
	end
end

---------------------------------------------------------------------------
-- Pièces qui s'ouvrent selon les points gagnés
---------------------------------------------------------------------------
local function bestEarned()
	local best = 0
	for _, state in states do
		if state.Loaded then
			best = math.max(best, state.Earned[activeMap] or 0)
		end
	end
	return best
end

-- Ouvre toutes les pièces dont le seuil est atteint par un joueur présent.
local function refreshUnlocks(silent)
	if not activeMap or not level then
		return
	end
	local earned = bestEarned()
	local opened = {}
	for _, room in TidyConfig.GetMapRooms(activeMap) do
		if not unlockedRooms[room.Id] and earned >= room.Unlock then
			unlockedRooms[room.Id] = true
			table.insert(opened, room)
		end
	end
	if #opened == 0 then
		return
	end
	for _, room in opened do
		for _, door in level.Doors do
			if door.Parent and door:GetAttribute("Room") == room.Id then
				door:Destroy()
			end
		end
		if not silent and room.Unlock > 0 then
			notifyMap("room", "🔓 New area open: " .. room.Name .. "!")
		end
	end
	publishProgress()
end

---------------------------------------------------------------------------
-- Quêtes du jour et points
---------------------------------------------------------------------------
local function today()
	return math.floor(os.time() / 86400)
end

local function ensureQuests(player, state)
	local day = today()
	if state.Quests.Day ~= day or #state.Quests.Indices == 0 then
		state.Quests = { Day = day, Indices = TidyConfig.GetDailyQuests(player.UserId, day), Progress = {}, Done = {} }
	end
end

-- Fait avancer les quêtes d'un certain type. Les récompenses sont données automatiquement.
local function advanceQuests(player, state, kind, amount, itemType)
	ensureQuests(player, state)
	for i, templateIndex in state.Quests.Indices do
		local template = TidyConfig.QuestTemplates[templateIndex]
		if template and template.Kind == kind and not state.Quests.Done[i] and (template.ItemType == nil or template.ItemType == itemType) then
			state.Quests.Progress[i] = (state.Quests.Progress[i] or 0) + amount
			if state.Quests.Progress[i] >= template.Target then
				state.Quests.Done[i] = true
				state.Points += template.Reward
				notify(player, "quest", "Quest complete: " .. string.format(template.Text, template.Target) .. "  +" .. TidyConfig.FormatNumber(template.Reward) .. " points")
			end
		end
	end
end

-- Donne des points gagnés en rangeant (avec les bonus des pass). Renvoie le montant donné.
local function award(player, state, basePoints)
	local amount = math.floor(basePoints * pointsMultiplier(state) + 0.5)
	state.Points += amount
	if activeMap then
		state.Earned[activeMap] = (state.Earned[activeMap] or 0) + amount
	end
	advanceQuests(player, state, "Earn", amount)
	return amount
end

-- Déclarées ici, définies plus bas.
local saveData
local updateLeaderboard
local startRound

---------------------------------------------------------------------------
-- Rangement
---------------------------------------------------------------------------

-- Place libre la plus proche d'une position dans une zone, ou nil.
local function nearestFreeSlot(zone, position)
	local spots = zone:FindFirstChild("Spots")
	if not spots then
		return nil, math.huge
	end
	local bestSlot, bestDistance = nil, math.huge
	for _, slot in spots:GetChildren() do
		if slot:GetAttribute("Occupied") ~= true then
			local distance = (slot.Position - position).Magnitude
			if distance < bestDistance then
				bestSlot, bestDistance = slot, distance
			end
		end
	end
	return bestSlot, bestDistance
end

-- Pose un objet dans une place et met les compteurs à jour. Renvoie la pièce terminée (ou nil).
local function putItemInSlot(item, zone, slot)
	setHeldPhysics(item, false)
	item.Parent = zone
	item:PivotTo(slot.CFrame)
	item:SetAttribute("State", "Placed")
	slot:SetAttribute("Occupied", true)
	local itemType = item:GetAttribute("ItemType")
	local key = categoryKey(item)
	placedCounts[itemType] = (placedCounts[itemType] or 0) + 1
	zoneCounts[key] = (zoneCounts[key] or 0) + 1
	remainingItems -= 1
	placedThisRound += 1
	local roomId = item:GetAttribute("Room")
	local recordKey = (roomId or "") .. "|" .. key
	placedRecord[recordKey] = (placedRecord[recordKey] or 0) + 1
	if roomId and roomTotals[roomId] then
		roomPlaced[roomId] = (roomPlaced[roomId] or 0) + 1
		if roomPlaced[roomId] == roomTotals[roomId] then
			return roomId
		end
	end
	return nil
end

-- Journée terminée : tout le niveau est rangé. Victoire pour tous les joueurs du niveau.
local function formatDuration(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function completeDay()
	local elapsed = math.floor(os.clock() - roundStartedAt)
	for player, state in states do
		if state.InMap and roundTimed and elapsed > 0 then
			local best = state.BestTimes[activeMap]
			if not best or elapsed < best then
				state.BestTimes[activeMap] = elapsed
				notify(player, "room", "🏆 New personal record: " .. formatDuration(elapsed) .. "!")
			end
		end
		if state.InMap then
			state.Wins += 1
			state.MapWins[activeMap] = (state.MapWins[activeMap] or 0) + 1
			state.DaysCompleted += 1
			state.DayProgress[activeMap] = nil
			local bonus = award(player, state, TidyConfig.DayBonus)
			publishPlayer(player, state)
			notify(player, "complete", "Level complete! +1 win, +" .. TidyConfig.FormatNumber(bonus) .. " bonus points")
			task.spawn(saveData, player, state)
		end
	end
	task.delay(3, function()
		updateLeaderboard()
	end)
end

-- Récompenses et messages après avoir rangé un objet (joueur ou aide de la boutique).
local function rewardPlacement(player, state, item, roomDone)
	local itemType = item:GetAttribute("ItemType")
	local gained = award(player, state, TidyConfig.ItemTypes[itemType].Points)
	local oldRank = TidyConfig.GetRank(state.Lifetime)
	state.Lifetime += 1
	local newRank = TidyConfig.GetRank(state.Lifetime)
	advanceQuests(player, state, "Place", 1)
	advanceQuests(player, state, "PlaceType", 1, itemType)
	if roomDone then
		local room = TidyConfig.GetRoom(roomDone)
		local bonus = award(player, state, TidyConfig.RoomBonus)
		advanceQuests(player, state, "Room", 1)
		notify(player, "room", room.Name .. " is spotless! +" .. bonus .. " bonus points")
	end
	if newRank ~= oldRank then
		notify(player, "room", "Promotion! You are now: " .. newRank.Name)
	end
	return gained
end

local function pick(player, state, item)
	if not level or typeof(item) ~= "Instance" or not item:IsDescendantOf(itemsFolder) then
		return
	end
	if not CollectionService:HasTag(item, TidyConfig.ItemTag) or item:GetAttribute("State") ~= "Loose" then
		return
	end
	if not isRoomUnlocked(item:GetAttribute("Room")) then
		notify(player, "error", "This area is still locked.")
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
		notify(player, "error", "Your basket is full! Put some items away first.")
		return
	end
	addToBag(state, item)
	state.Selected = #state.Held
	stackHeld(player, state)
	publishPlayer(player, state)
end

-- Range l'objet en main (ou le premier qui convient). all = true : rangement rapide (tout ce qui convient).
local function place(player, state, zone, all)
	if not level or typeof(zone) ~= "Instance" or not CollectionService:HasTag(zone, TidyConfig.ZoneTag) then
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
	local zoneCategory = zone:GetAttribute("Category")
	local function fits(item)
		return item:GetAttribute("ItemType") == zoneType and (zoneCategory == nil or item:GetAttribute("Category") == zoneCategory)
	end
	local root = getLivingRoot(player)
	if not root then
		return
	end
	local quick = all == true and state.Levels.QuickStock >= 1

	local placedAny = 0
	local gainedTotal = 0
	while true do
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
			if placedAny == 0 then
				local category = zoneCategory and TidyConfig.GetCategory(zoneType, zoneCategory)
				if category then
					notify(player, "error", "Wrong shelf! This one is for: " .. category.Name .. ".")
				else
					notify(player, "error", "Wrong place! This spot is for: " .. string.lower(zoneInfo.Plural) .. ".")
				end
			end
			break
		end
		local slot, distance = nearestFreeSlot(zone, root.Position)
		if not slot then
			if placedAny == 0 then
				notify(player, "error", "This shelf is full. Find another one!")
			end
			break
		end
		if distance > MAX_DISTANCE then
			notify(player, "error", "Move closer to put it away.")
			break
		end
		local item = table.remove(state.Held, index)
		local weld = state.Welds[item]
		local startCFrame = if weld and item.PrimaryPart then item.PrimaryPart.CFrame else root.CFrame * CFrame.new(1, 0, -2)
		if weld then
			weld:Destroy()
			state.Welds[item] = nil
		end
		if index < state.Selected then
			state.Selected -= 1
		end
		state.Selected = math.clamp(state.Selected, math.min(1, #state.Held), #state.Held)
		local roomDone = putItemInSlot(item, zone, slot)
		local gained = rewardPlacement(player, state, item, roomDone)
		gainedTotal += gained
		placedAny += 1
		notifyEvent:FireClient(player, "placed", "+" .. gained, slot.Position, item, startCFrame)
		if not quick or remainingItems <= 0 then
			break
		end
	end
	if placedAny == 0 then
		return
	end
	if quick and placedAny > 1 then
		notify(player, "info", "Quick Stock: " .. placedAny .. " items put away (+" .. gainedTotal .. ")")
	end
	stackHeld(player, state)
	refreshUnlocks()
	publishPlayer(player, state)
	publishProgress(zoneType .. "|" .. (zoneCategory or "-"))
	if remainingItems <= 0 then
		completeDay()
	end
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
	if not item or not root or not level then
		return
	end
	table.remove(state.Held, state.Selected)
	local weld = state.Welds[item]
	if weld then
		weld:Destroy()
		state.Welds[item] = nil
	end
	state.Selected = math.min(state.Selected, #state.Held)
	local minX, maxX, minZ, maxZ = AgencyBuilder.GetBounds(activeMap)
	local front = (root.CFrame * CFrame.new(0, 0, -3)).Position
	local x = math.clamp(front.X, minX + 1.5, maxX - 1.5)
	local z = math.clamp(front.Z, minZ + 1.5, maxZ - 1.5)
	local surfaceY = findSurfaceY(Vector3.new(x, root.Position.Y, z), player.Character)
	local home = CFrame.new(x, surfaceY + item:GetAttribute("RestHeight"), z) * root.CFrame.Rotation
	setHeldPhysics(item, false)
	item.Parent = itemsFolder
	item:PivotTo(home)
	item:SetAttribute("HomeCFrame", home)
	item:SetAttribute("State", "Loose")
	stackHeld(player, state)
	publishPlayer(player, state)
end

local function cycle(player, state, direction)
	local count = #state.Held
	if count <= 1 or (direction ~= 1 and direction ~= -1) then
		return
	end
	state.Selected = ((state.Selected - 1 + direction) % count) + 1
	stackHeld(player, state)
	publishPlayer(player, state)
end

local function useMagnet(player, state)
	if not level then
		return
	end
	if not magnetUnlocked(state) then
		notify(player, "error", "Unlock the magnet in the upgrades menu [G].")
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
		notify(player, "error", "Your basket is full! Put some items away first.")
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
	stackHeld(player, state)
	publishPlayer(player, state)
	notify(player, "info", "🧲 Magnet: " .. taken .. " item(s) collected.")
end

-- Aide de la boutique : range tout seul des objets qui traînent dans les pièces ouvertes.
local function helperTidy(player, state, count)
	if not level then
		return 0
	end
	local freeSlots = {}
	for _, zone in level.Zones do
		if isRoomUnlocked(zone:GetAttribute("Room")) then
			local key = zone:GetAttribute("ItemType") .. "|" .. (zone:GetAttribute("Category") or "-")
			local spots = zone:FindFirstChild("Spots")
			if spots then
				for _, slot in spots:GetChildren() do
					if slot:GetAttribute("Occupied") ~= true then
						freeSlots[key] = freeSlots[key] or {}
						table.insert(freeSlots[key], { Zone = zone, Slot = slot })
					end
				end
			end
		end
	end
	local done = 0
	for _, item in itemsFolder:GetChildren() do
		if done >= count then
			break
		end
		if item:GetAttribute("State") == "Loose" and isRoomUnlocked(item:GetAttribute("Room")) then
			local list = freeSlots[categoryKey(item)]
			local target = list and table.remove(list)
			if target then
				local roomDone = putItemInSlot(item, target.Zone, target.Slot)
				rewardPlacement(player, state, item, roomDone)
				done += 1
			end
		end
	end
	if done > 0 then
		refreshUnlocks()
		publishPlayer(player, state)
		publishProgress()
		if remainingItems <= 0 then
			completeDay()
		end
	end
	return done
end

-- Remet en place la progression sauvegardée de la journée (sans redonner de points).
local function restoreDayProgress(player, state)
	if not level or roundRestored or placedThisRound > 0 then
		return
	end
	local saved = state.DayProgress[activeMap]
	if type(saved) ~= "table" or next(saved) == nil then
		return
	end
	roundRestored = true
	roundTimed = false
	local freeSlots = {}
	for _, zone in level.Zones do
		local key = zone:GetAttribute("ItemType") .. "|" .. (zone:GetAttribute("Category") or "-")
		local spots = zone:FindFirstChild("Spots")
		if spots then
			for _, slot in spots:GetChildren() do
				if slot:GetAttribute("Occupied") ~= true then
					freeSlots[key] = freeSlots[key] or {}
					table.insert(freeSlots[key], { Zone = zone, Slot = slot })
				end
			end
		end
	end
	local wanted = {}
	for recordKey, count in saved do
		if type(recordKey) == "string" and type(count) == "number" then
			wanted[recordKey] = math.floor(count)
		end
	end
	local restored = 0
	for _, item in itemsFolder:GetChildren() do
		if item:GetAttribute("State") == "Loose" then
			local recordKey = (item:GetAttribute("Room") or "") .. "|" .. categoryKey(item)
			if (wanted[recordKey] or 0) > 0 then
				local list = freeSlots[categoryKey(item)]
				local target = list and table.remove(list)
				if target then
					wanted[recordKey] -= 1
					putItemInSlot(item, target.Zone, target.Slot)
					restored += 1
				end
			end
		end
	end
	-- Ce qui a été remis en place ne compte pas comme "rangé aujourd'hui" pour la règle de restauration.
	if restored > 0 then
		publishProgress()
		notify(player, "info", "Welcome back! " .. restored .. " items you already put away are still in place.")
		if remainingItems <= 0 then
			startRound()
		end
	end
end

---------------------------------------------------------------------------
-- Journées de travail (parties)
---------------------------------------------------------------------------
function startRound()
	if not level then
		return
	end
	for player, state in states do
		if state.InMap then
			returnAllItems(player)
		end
	end
	roundNumber += 1
	local items = AgencyBuilder.ScatterItems(Random.new():NextInteger(1, 1000000000))
	totals, placedCounts, zoneCounts, zoneTotals = {}, {}, {}, {}
	roomTotals, roomPlaced, placedRecord = {}, {}, {}
	placedThisRound = 0
	roundRestored = false
	roundStartedAt = os.clock()
	roundTimed = true
	for _, item in items do
		local itemType = item:GetAttribute("ItemType")
		totals[itemType] = (totals[itemType] or 0) + 1
		local key = categoryKey(item)
		zoneTotals[key] = (zoneTotals[key] or 0) + 1
		local roomId = item:GetAttribute("Room")
		roomTotals[roomId] = (roomTotals[roomId] or 0) + 1
	end
	totalItems = #items
	remainingItems = totalItems
	publishProgress()
	-- Annoncé en dernier : l'écran du joueur voit déjà les nouveaux compteurs.
	ReplicatedStorage:SetAttribute("RoundNumber", roundNumber)
end

-- Ascenseurs de l'agence : marcher sur le plateau de la cabine fait changer d'étage.
local lastLift = {}
local function connectLifts(root)
	for _, pad in root:GetDescendants() do
		if pad:IsA("BasePart") and CollectionService:HasTag(pad, "TidyLift") then
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
	end
end

-- Construit un niveau et commence une journée.
local function buildLevel(mapId)
	level = AgencyBuilder.Build(mapId)
	activeMap = mapId
	itemsFolder = AgencyBuilder.GetItemsFolder()
	unlockedRooms = {}
	connectLifts(level.Root)
	startRound()
	refreshUnlocks(true)
	publishProgress()
end

---------------------------------------------------------------------------
-- Actions du joueur
---------------------------------------------------------------------------
actionEvent.OnServerEvent:Connect(function(player, action, target, extra)
	local state = states[player]
	if not state or type(action) ~= "string" then
		return
	end
	if action == "pick" then
		pick(player, state, target)
	elseif action == "place" then
		place(player, state, target, extra == true)
	elseif action == "drop" then
		drop(player, state)
	elseif action == "cycle" then
		cycle(player, state, target)
	elseif action == "magnet" then
		useMagnet(player, state)
	elseif action == "door" then
		if typeof(target) == "Instance" and CollectionService:HasTag(target, TidyConfig.DoorTag) then
			local room = TidyConfig.GetRoom(target:GetAttribute("Room"))
			if room then
				notify(player, "info", "🔒 " .. room.Name .. " opens at " .. TidyConfig.FormatNumber(room.Unlock) .. " points earned here (you: " .. TidyConfig.FormatNumber(state.Earned[activeMap] or 0) .. ").")
			end
		end
	elseif action == "restart" then
		if level and remainingItems <= 0 and state.InMap then
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
	local currentLevel = state.Levels[upgradeId] or 0
	if currentLevel >= upgrade.MaxLevel then
		return false, "Already at the maximum level."
	end
	local cost = TidyConfig.GetUpgradeCost(upgrade, currentLevel)
	if state.Points < cost then
		return false, "Not enough points. You need " .. TidyConfig.FormatNumber(cost) .. "."
	end
	state.Points -= cost
	state.Levels[upgradeId] = currentLevel + 1
	if upgradeId == "Speed" then
		applyWalkSpeed(player, state)
	end
	publishPlayer(player, state)
	return true, upgrade.Name .. ": level " .. (currentLevel + 1)
end

settingsEvent.OnServerEvent:Connect(function(player, settings)
	local state = states[player]
	if not state or type(settings) ~= "table" then
		return
	end
	if type(settings.Music) == "number" then
		state.Settings.Music = math.clamp(settings.Music, 0, 1)
	end
	for _, key in { "Sfx", "Tutorial", "Controls", "LowGraphics" } do
		if type(settings[key]) == "boolean" then
			state.Settings[key] = settings[key]
		end
	end
	player:SetAttribute("Settings", HttpService:JSONEncode(state.Settings))
end)

---------------------------------------------------------------------------
-- Sauvegarde
---------------------------------------------------------------------------
local SAVE_VERSION = 2
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

-- Classements du mur de l'entrée : victoires, et meilleur temps sur chaque niveau.
local winsStore = nil
local timeStores = {}
pcall(function()
	winsStore = DataStoreService:GetOrderedDataStore("NorthfieldWins_v1")
	for _, map in TidyConfig.Maps do
		timeStores[map.Id] = DataStoreService:GetOrderedDataStore("NorthfieldBestTime_" .. map.Id .. "_v1")
	end
end)

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

-- Garde la progression de la journée en cours pour le niveau où se trouve le joueur.
local function captureDayProgress(state)
	if state.InMap and activeMap and placedThisRound > 0 and remainingItems > 0 then
		state.DayProgress[activeMap] = table.clone(placedRecord)
	end
end

local function buildSaveData(player, state)
	captureDayProgress(state)
	return {
		Version = SAVE_VERSION,
		Points = state.Points,
		Levels = state.Levels,
		Lifetime = state.Lifetime,
		Earned = state.Earned,
		Wins = state.Wins,
		MapWins = state.MapWins,
		Streak = state.Streak,
		LastDay = state.LastDay,
		DaysCompleted = state.DaysCompleted,
		Quests = state.Quests,
		BestTimes = state.BestTimes,
		DayProgress = state.DayProgress,
		DealBought = state.DealBought,
		HelperCharges = state.HelperCharges,
		Receipts = state.Receipts,
		Settings = state.Settings,
	}
end

function saveData(player, state)
	-- Jamais d'écriture si la lecture a échoué : on ne doit pas écraser une vraie sauvegarde.
	if not dataStore or not state or not state.CanSave then
		return false
	end
	local data = buildSaveData(player, state)
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
			if winsStore and state.Wins > 0 then
				pcall(function()
					winsStore:SetAsync(tostring(player.UserId), state.Wins)
				end)
			end
			for mapId, seconds in state.BestTimes do
				local store = timeStores[mapId]
				if store then
					pcall(function()
						store:SetAsync(tostring(player.UserId), seconds)
					end)
				end
			end
			return true
		end
		task.wait(attempt)
	end
	warn("[TidyManager] Could not save progress for " .. player.Name)
	return false
end

local function readNumber(value, default)
	local n = tonumber(value)
	if n == nil or n ~= n then
		return default
	end
	return n
end

-- Applique une sauvegarde chargée à l'état du joueur (et convertit l'ancienne version).
local function applySaveData(player, state, data)
	if type(data) ~= "table" then
		return
	end
	state.Points = math.max(0, readNumber(data.Points, 0))
	state.Lifetime = math.max(0, readNumber(data.Lifetime, 0))
	state.Streak = math.max(0, readNumber(data.Streak, 0))
	state.LastDay = readNumber(data.LastDay, 0)
	state.DaysCompleted = math.max(0, readNumber(data.DaysCompleted, 0))
	state.Wins = math.max(0, readNumber(data.Wins, state.DaysCompleted))
	state.DealBought = data.DealBought == true
	state.HelperCharges = math.max(0, readNumber(data.HelperCharges, 0))
	if type(data.Levels) == "table" then
		for _, upgrade in TidyConfig.Upgrades do
			local value = readNumber(data.Levels[upgrade.Id], 0)
			state.Levels[upgrade.Id] = math.clamp(math.floor(value), 0, upgrade.MaxLevel)
		end
	end
	if type(data.Earned) == "table" then
		for _, map in TidyConfig.Maps do
			state.Earned[map.Id] = math.max(0, readNumber(data.Earned[map.Id], 0))
		end
	end
	if type(data.BestTimes) == "table" then
		for _, map in TidyConfig.Maps do
			local t = tonumber(data.BestTimes[map.Id])
			if t and t > 0 then
				state.BestTimes[map.Id] = math.floor(t)
			end
		end
	end
	if type(data.MapWins) == "table" then
		for _, map in TidyConfig.Maps do
			state.MapWins[map.Id] = math.max(0, readNumber(data.MapWins[map.Id], 0))
		end
	end
	-- Ancienne sauvegarde : les pièces payées restent ouvertes.
	if type(data.Unlocked) == "table" and type(data.Earned) ~= "table" then
		local best = 0
		for _, roomId in data.Unlocked do
			local room = TidyConfig.GetRoom(roomId)
			if room and room.Map == "Agency" then
				best = math.max(best, room.Unlock)
			end
		end
		state.Earned.Agency = best
	end
	if type(data.Quests) == "table" and type(data.Quests.Indices) == "table" then
		state.Quests = {
			Day = readNumber(data.Quests.Day, 0),
			Indices = data.Quests.Indices,
			Progress = if type(data.Quests.Progress) == "table" then data.Quests.Progress else {},
			Done = if type(data.Quests.Done) == "table" then data.Quests.Done else {},
		}
	end
	if type(data.DayProgress) == "table" then
		for _, map in TidyConfig.Maps do
			if type(data.DayProgress[map.Id]) == "table" then
				state.DayProgress[map.Id] = data.DayProgress[map.Id]
			end
		end
	end
	if type(data.Receipts) == "table" then
		for _, receipt in data.Receipts do
			if type(receipt) == "string" then
				table.insert(state.Receipts, receipt)
			end
		end
	end
	if type(data.Settings) == "table" then
		if type(data.Settings.Music) == "number" then
			state.Settings.Music = math.clamp(data.Settings.Music, 0, 1)
		end
		for _, key in { "Sfx", "Tutorial", "Controls", "LowGraphics" } do
			if type(data.Settings[key]) == "boolean" then
				state.Settings[key] = data.Settings[key]
			end
		end
	end
end

-- Bonus quotidien : plus on revient de jours de suite, plus il est grand (x2 pour les VIP).
local function giveDailyBonus(player, state)
	local day = today()
	if state.LastDay == day then
		return
	end
	if state.LastDay == day - 1 then
		state.Streak += 1
	else
		state.Streak = 1
	end
	state.LastDay = day
	local bonus = TidyConfig.DailyBonusPerDay * math.min(state.Streak, TidyConfig.DailyBonusMaxDays)
	if hasPass(state, "VIP") then
		bonus *= TidyConfig.PassEffects.VIPDaily
	end
	state.Points += bonus
	notify(player, "room", "🎁 Daily bonus: +" .. TidyConfig.FormatNumber(bonus) .. " points (day " .. state.Streak .. " in a row)")
end

---------------------------------------------------------------------------
-- Boutique Robux
---------------------------------------------------------------------------
local function findPassByGamePassId(gamePassId)
	for _, pass in TidyConfig.GamePasses do
		if pass.GamePassId ~= 0 and pass.GamePassId == gamePassId then
			return pass
		end
	end
	return nil
end

local function findProductByProductId(productId)
	for _, product in TidyConfig.Products do
		if product.ProductId ~= 0 and product.ProductId == productId then
			return product
		end
	end
	return nil
end

local function onPassOwned(player, state, pass)
	state.Passes[pass.Id] = true
	applyWalkSpeed(player, state)
	applyVipTag(player, state)
	publishPlayer(player, state)
end

local function grantProduct(player, state, product)
	if product.Points then
		state.Points += product.Points
	end
	if product.Id == "Deal" then
		state.DealBought = true
	end
	if product.HelperItems then
		if state.InMap and level then
			local done = helperTidy(player, state, product.HelperItems)
			notify(player, "purchase", "🤖 Tidy Helper put away " .. done .. " items for you!")
			local left = product.HelperItems - done
			if left > 0 then
				state.HelperCharges += left
			end
		else
			state.HelperCharges += product.HelperItems
			notify(player, "purchase", "🤖 Tidy Helper is ready: it will help as soon as you enter a level.")
		end
	end
	publishPlayer(player, state)
end

local function loadPasses(player, state)
	for _, pass in TidyConfig.GamePasses do
		if pass.GamePassId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.GamePassId)
			end)
			if ok and owns then
				state.Passes[pass.Id] = true
			end
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
	local state = states[player]
	local pass = findPassByGamePassId(gamePassId)
	if purchased and state and pass then
		onPassOwned(player, state, pass)
		notify(player, "purchase", "Thank you! " .. pass.Name .. " is now active.")
	end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local state = player and states[player]
	if not state or not state.Loaded then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(receiptInfo.PurchaseId)
	if table.find(state.Receipts, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = findProductByProductId(receiptInfo.ProductId)
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grantProduct(player, state, product)
	table.insert(state.Receipts, receiptId)
	while #state.Receipts > 40 do
		table.remove(state.Receipts, 1)
	end
	notify(player, "purchase", "Thank you! " .. product.Name .. " received.")
	if state.CanSave and not saveData(player, state) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

shopFunction.OnServerInvoke = function(player, kind, itemId)
	local state = states[player]
	if not state or type(itemId) ~= "string" then
		return false, "Not possible right now."
	end
	if kind == "Pass" then
		local pass = TidyConfig.GetPass(itemId)
		if not pass then
			return false, "Unknown item."
		end
		if hasPass(state, pass.Id) then
			return false, "You already own " .. pass.Name .. "."
		end
		if pass.GamePassId == 0 then
			if isTestServer then
				onPassOwned(player, state, pass)
				return true, "Studio test: " .. pass.Name .. " is active for this session."
			end
			return false, "Coming soon!"
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
		return true, ""
	elseif kind == "Product" then
		local product = TidyConfig.GetProduct(itemId)
		if not product then
			return false, "Unknown item."
		end
		if product.OneTime and state.DealBought then
			return false, "You already claimed this deal."
		end
		if product.ProductId == 0 then
			if isTestServer then
				grantProduct(player, state, product)
				return true, "Studio test: " .. product.Name .. " received."
			end
			return false, "Coming soon!"
		end
		MarketplaceService:PromptProductPurchase(player, product.ProductId)
		return true, ""
	end
	return false, "Unknown item."
end

---------------------------------------------------------------------------
-- Entrer dans un niveau / revenir au hall
---------------------------------------------------------------------------
-- Déplace un personnage en s'assurant que le décor autour est chargé chez le joueur
-- (sinon il peut tomber à travers un sol pas encore chargé).
local function moveCharacter(player, cframe)
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 4)
	end)
	local character = player.Character
	if character then
		character:PivotTo(cframe)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function enterMap(player, offsetIndex)
	local state = states[player]
	if not state or not level then
		return
	end
	state.InMap = true
	player:SetAttribute("InMap", true)
	player:SetAttribute("QueuePad", 0)
	player.RespawnLocation = level.Spawn
	local offset = Vector3.new(((offsetIndex or 1) - 2.5) * 3, 3, 0)
	moveCharacter(player, level.Spawn.CFrame + offset)
	applyWalkSpeed(player, state)
	notify(player, "enter", activeMap)
	restoreDayProgress(player, state)
	if state.HelperCharges > 0 then
		local done = helperTidy(player, state, state.HelperCharges)
		state.HelperCharges = math.max(0, state.HelperCharges - done)
		if done > 0 then
			notify(player, "purchase", "🤖 Tidy Helper put away " .. done .. " items for you!")
		end
	end
	refreshUnlocks()
end

local function returnToHub(player)
	local state = states[player]
	if not state then
		return
	end
	captureDayProgress(state)
	returnAllItems(player)
	if isRoomServer then
		task.spawn(saveData, player, state)
		local ok = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player })
		end)
		if not ok then
			notify(player, "error", "Could not go back to the lobby. Please try again.")
		end
		return
	end
	state.InMap = false
	player:SetAttribute("InMap", false)
	if hub then
		player.RespawnLocation = hub.Spawn
		moveCharacter(player, hub.Spawn.CFrame + Vector3.new(0, 3, 0))
	end
	applyWalkSpeed(player, state)
end

---------------------------------------------------------------------------
-- Codes pour rejoindre la partie d'un ami
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

lobbyFunction.OnServerInvoke = function(player, action, argument)
	local state = states[player]
	if not state then
		return false, "Please wait a moment."
	end
	if action == "BackToLobby" then
		returnToHub(player)
		return true, ""
	elseif action == "Join" then
		if isTestServer then
			return false, "Joining a friend only works in the published game."
		end
		local code = string.upper(string.gsub(tostring(argument or ""), "%s", ""))
		if #code ~= 6 or not roomCodes then
			return false, "Please enter a 6-character code."
		end
		local ok, accessCode = pcall(function()
			return roomCodes:GetAsync(code)
		end)
		if not ok or type(accessCode) ~= "string" then
			return false, "No game found with this code."
		end
		task.spawn(saveData, player, state)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = accessCode
		options:SetTeleportData({ RoomCode = code })
		local sent = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		if not sent then
			return false, "Teleport failed. Please try again."
		end
		return true, "Joining game " .. code .. "..."
	end
	return false, "Unknown action."
end

TeleportService.TeleportInitFailed:Connect(function(player, _, message)
	notify(player, "error", "Teleport failed: " .. tostring(message))
end)

---------------------------------------------------------------------------
-- Files d'attente du hall : on choisit un niveau et le nombre de joueurs, puis on part ensemble
---------------------------------------------------------------------------
local queues = {}
if hub then
	for _, pad in hub.Pads do
		queues[pad.Index] = { Pad = pad, Members = {}, Host = nil, Map = nil, Size = 1, Countdown = nil, Launching = false }
	end
end

local function resetQueue(queue)
	queue.Members = {}
	queue.Host = nil
	queue.Map = nil
	queue.Size = 1
	queue.Countdown = nil
	queue.Launching = false
end

local function publishQueue(queue)
	local pad = queue.Pad
	local map = queue.Map and TidyConfig.GetMap(queue.Map)
	if #queue.Members == 0 then
		pad.Title.Text = "Empty"
		pad.Status.Text = "Waiting for players"
	elseif queue.Countdown then
		pad.Title.Text = (map and map.Icon .. " " .. map.Name) or ""
		pad.Status.Text = "Starting in " .. math.max(0, math.ceil(queue.Countdown)) .. "..."
	elseif not map then
		pad.Title.Text = "Choosing a map..."
		pad.Status.Text = queue.Host and (queue.Host.DisplayName .. " is the host") or ""
	else
		pad.Title.Text = map.Icon .. " " .. map.Name
		pad.Status.Text = "Waiting for players " .. #queue.Members .. "/" .. queue.Size
	end
	pad.Pad:SetAttribute("QueueMap", queue.Map or "")
	pad.Pad:SetAttribute("QueueCount", #queue.Members)
	pad.Pad:SetAttribute("QueueSize", queue.Size)
	pad.Pad:SetAttribute("QueueCountdown", if queue.Countdown then math.ceil(queue.Countdown) else -1)
	for _, member in queue.Members do
		member:SetAttribute("QueuePad", pad.Index)
		member:SetAttribute("QueueHost", member == queue.Host)
	end
end

local function leaveQueue(player)
	for _, queue in queues do
		local index = table.find(queue.Members, player)
		if index then
			table.remove(queue.Members, index)
			if player.Parent then
				player:SetAttribute("QueuePad", 0)
				player:SetAttribute("QueueHost", false)
			end
			if #queue.Members == 0 then
				resetQueue(queue)
			elseif queue.Host == player then
				queue.Host = queue.Members[1]
				queue.Countdown = nil
			elseif queue.Countdown and #queue.Members < queue.Size then
				queue.Countdown = nil
			end
			publishQueue(queue)
		end
	end
end

-- Départ du groupe : serveur réservé dans le jeu publié, niveau local dans Studio.
local function launchQueue(queue)
	if queue.Launching or not queue.Map then
		return
	end
	queue.Launching = true
	local members = table.clone(queue.Members)
	local mapId = queue.Map
	if isTestServer then
		local busy = false
		if activeMap and activeMap ~= mapId then
			for _, state in states do
				if state.InMap then
					busy = true
				end
			end
		end
		if busy then
			for _, member in members do
				notify(member, "error", "Studio test: another level is being played on this server.")
			end
		else
			if activeMap ~= mapId then
				buildLevel(mapId)
			end
			for i, member in members do
				leaveQueue(member)
				enterMap(member, i)
			end
		end
		resetQueue(queue)
		publishQueue(queue)
		return
	end
	task.spawn(function()
		local ok, accessCode = pcall(function()
			return TeleportService:ReserveServer(game.PlaceId)
		end)
		if ok and accessCode then
			local code = newRoomCode()
			if roomCodes then
				pcall(function()
					roomCodes:SetAsync(code, accessCode, TidyConfig.RoomCodeLifetime)
				end)
			end
			for _, member in members do
				local state = states[member]
				if state then
					task.spawn(saveData, member, state)
				end
			end
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = accessCode
			options:SetTeleportData({ Map = mapId, RoomCode = code })
			local sent = pcall(function()
				TeleportService:TeleportAsync(game.PlaceId, members, options)
			end)
			if not sent then
				for _, member in members do
					notify(member, "error", "Teleport failed. Please try again.")
				end
			end
		else
			for _, member in members do
				notify(member, "error", "Could not start the game right now. Please try again.")
			end
		end
		resetQueue(queue)
		for _, member in members do
			if member.Parent then
				member:SetAttribute("QueuePad", 0)
				member:SetAttribute("QueueHost", false)
			end
		end
		publishQueue(queue)
	end)
end

queueEvent.OnServerEvent:Connect(function(player, action, a, b)
	local state = states[player]
	if not state then
		return
	end
	if action == "Leave" then
		leaveQueue(player)
		return
	end
	local queue = nil
	for _, q in queues do
		if table.find(q.Members, player) then
			queue = q
		end
	end
	if not queue or queue.Host ~= player or queue.Launching then
		return
	end
	if action == "Configure" then
		local map = type(a) == "string" and TidyConfig.GetMap(a)
		local size = tonumber(b)
		if not map or not size then
			return
		end
		if state.Wins < map.WinsRequired then
			notify(player, "error", "🔒 " .. map.Name .. " needs " .. map.WinsRequired .. " win(s). Finish a level first!")
			return
		end
		queue.Map = map.Id
		queue.Size = math.clamp(math.floor(size), 1, TidyConfig.MaxPartySize)
		while #queue.Members > queue.Size do
			local removed = table.remove(queue.Members)
			removed:SetAttribute("QueuePad", 0)
			removed:SetAttribute("QueueHost", false)
			notify(removed, "error", "This group is now full.")
		end
		queue.Countdown = nil
		publishQueue(queue)
	elseif action == "Start" then
		if queue.Map then
			queue.Countdown = 3
			publishQueue(queue)
		end
	end
end)

-- Boucle des files d'attente : qui est sur quelle plateforme, comptes à rebours.
if hub then
	local lastFullNotice = {}
	task.spawn(function()
		local step = 0.25
		while true do
			task.wait(step)
			for player, state in states do
				if not state.InMap and state.Loaded then
					local root = getLivingRoot(player)
					local onPad = nil
					if root then
						for index, queue in queues do
							local center = queue.Pad.Center
							local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
							if flat.Magnitude <= queue.Pad.Radius and math.abs(root.Position.Y - center.Y) < 8 then
								onPad = index
							end
						end
					end
					local current = player:GetAttribute("QueuePad") or 0
					if current ~= 0 and current ~= onPad then
						leaveQueue(player)
						current = 0
					end
					if onPad and current == 0 then
						local queue = queues[onPad]
						if not queue.Launching and (queue.Host == nil or #queue.Members < queue.Size) and not queue.Countdown then
							table.insert(queue.Members, player)
							if not queue.Host then
								queue.Host = player
							end
							publishQueue(queue)
						elseif not lastFullNotice[player] or os.clock() - lastFullNotice[player] > 4 then
							lastFullNotice[player] = os.clock()
							notify(player, "error", "This group is full or about to leave.")
						end
					end
				end
			end
			for _, queue in queues do
				if queue.Map and not queue.Launching then
					if not queue.Countdown and #queue.Members >= queue.Size and #queue.Members > 0 then
						queue.Countdown = TidyConfig.QueueCountdown
					end
					if queue.Countdown then
						local before = math.ceil(queue.Countdown)
						queue.Countdown -= step
						if math.ceil(queue.Countdown) ~= before then
							publishQueue(queue)
						end
						if queue.Countdown <= 0 then
							launchQueue(queue)
						end
					end
				end
			end
		end
	end)
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
		task.defer(applyVipTag, player, state)
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
	pointsValue.Parent = leaderstats
	local rankValue = Instance.new("StringValue")
	rankValue.Name = "Rank"
	rankValue.Value = TidyConfig.Ranks[1].Name
	rankValue.Parent = leaderstats
	leaderstats.Parent = player

	local levels = {}
	for _, upgrade in TidyConfig.Upgrades do
		levels[upgrade.Id] = 0
	end
	local earned, mapWins = {}, {}
	for _, map in TidyConfig.Maps do
		earned[map.Id] = 0
		mapWins[map.Id] = 0
	end
	local state = {
		Held = {},
		Selected = 0,
		Welds = {},
		Levels = levels,
		Points = 0,
		Lifetime = 0,
		Earned = earned,
		Wins = 0,
		MapWins = mapWins,
		Streak = 0,
		LastDay = 0,
		DaysCompleted = 0,
		Quests = { Day = 0, Indices = {}, Progress = {}, Done = {} },
		BestTimes = {},
		DayProgress = {},
		Passes = {},
		DealBought = false,
		HelperCharges = 0,
		Receipts = {},
		Settings = { Music = TidyConfig.MusicVolume, Sfx = true, Tutorial = true, Controls = true, LowGraphics = false },
		CanSave = false,
		Loaded = false,
		InMap = false,
		LastMagnet = -math.huge,
		PointsValue = pointsValue,
		RankValue = rankValue,
	}
	states[player] = state
	ensureQuests(player, state)
	player:SetAttribute("InMap", false)
	player:SetAttribute("QueuePad", 0)
	if hub then
		player.RespawnLocation = hub.Spawn
	end
	publishPlayer(player, state)

	-- Serveur réservé : niveau choisi dans le hall, code pour inviter des amis.
	local teleportData = nil
	if isRoomServer then
		local joinData = player:GetJoinData()
		teleportData = joinData and joinData.TeleportData
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

	if isRoomServer then
		if not level then
			local mapId = type(teleportData) == "table" and teleportData.Map or nil
			if not TidyConfig.GetMap(mapId) then
				mapId = "Agency"
			end
			buildLevel(mapId)
			Players.CharacterAutoLoads = true
		end
		state.InMap = true
		player:SetAttribute("InMap", true)
		player.RespawnLocation = level.Spawn
		task.spawn(function()
			if not player.Character then
				player:LoadCharacter()
			end
			enterMap(player, 1)
		end)
	end

	-- Chargement de la sauvegarde et des pass (sans bloquer l'arrivée du joueur).
	task.spawn(function()
		local ok, data = loadData(player)
		if not player.Parent or states[player] ~= state then
			return
		end
		if ok then
			applySaveData(player, state, data)
			state.CanSave = true
		elseif dataStore then
			notify(player, "error", "Progress could not be loaded. It will not be saved this session.")
		end
		loadPasses(player, state)
		state.Loaded = true
		ensureQuests(player, state)
		giveDailyBonus(player, state)
		applyWalkSpeed(player, state)
		applyVipTag(player, state)
		publishPlayer(player, state)
		if state.InMap then
			restoreDayProgress(player, state)
		end
		refreshUnlocks(true)
		task.spawn(updateLeaderboard)
	end)
end

---------------------------------------------------------------------------
-- Classement du hall : meilleurs rangeurs (sauvegarde globale, sinon joueurs présents)
---------------------------------------------------------------------------
local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(name) == "string" then
		nameCache[userId] = name
		return name
	end
	return "Player"
end

-- Remplit un panneau avec des lignes { Name, Value }.
local function fillBoard(rows, entries)
	for i, row in rows do
		local entry = entries[i]
		row.Name.Text = if entry then entry.Name else "---"
		row.Value.Text = if entry then entry.Value else ""
	end
end

-- Lit un classement global ; renvoie nil si ce n'est pas possible (Studio sans accès aux données).
local function readTop(store, ascending, format)
	if not store then
		return nil
	end
	local entries = {}
	local ok = pcall(function()
		local pages = store:GetSortedAsync(ascending, 10)
		for _, entry in pages:GetCurrentPage() do
			table.insert(entries, { Name = nameOf(tonumber(entry.key) or 0), Value = format(entry.value) })
		end
	end)
	if not ok or #entries == 0 then
		return nil
	end
	return entries
end

function updateLeaderboard()
	local boards = hub and hub.Boards
	if not boards then
		return
	end
	-- Victoires
	local wins = readTop(winsStore, false, function(v)
		return TidyConfig.FormatNumber(v) .. " wins"
	end)
	if not wins then
		local list = {}
		for player, state in states do
			if state.Wins > 0 then
				table.insert(list, { Name = player.Name, Raw = state.Wins })
			end
		end
		table.sort(list, function(a, b)
			return a.Raw > b.Raw
		end)
		wins = {}
		for i, e in list do
			wins[i] = { Name = e.Name, Value = TidyConfig.FormatNumber(e.Raw) .. " wins" }
		end
	end
	if boards.Wins then
		fillBoard(boards.Wins, wins)
	end
	-- Meilleurs temps par niveau
	for _, map in TidyConfig.Maps do
		local rows = boards[map.Id]
		if rows then
			local top = readTop(timeStores[map.Id], true, formatDuration)
			if not top then
				local list = {}
				for player, state in states do
					if state.BestTimes[map.Id] then
						table.insert(list, { Name = player.Name, Raw = state.BestTimes[map.Id] })
					end
				end
				table.sort(list, function(a, b)
					return a.Raw < b.Raw
				end)
				top = {}
				for i, e in list do
					top[i] = { Name = e.Name, Value = formatDuration(e.Raw) }
				end
			end
			fillBoard(rows, top)
		end
	end
end

-- Hall d'accueil : on peut aussi tester un niveau tout de suite dans Studio sans file d'attente.
ReplicatedStorage:SetAttribute("ActiveMap", "")
publishProgress()

task.spawn(function()
	while true do
		updateLeaderboard()
		task.wait(60)
	end
end)

-- Filet de sécurité : un joueur tombé sous le sol est ramené au point d'arrivée.
task.spawn(function()
	while true do
		task.wait(1.5)
		for player, state in states do
			local root = getLivingRoot(player)
			if root and root.Position.Y < -25 then
				local spawn = if state.InMap and level then level.Spawn elseif hub then hub.Spawn else nil
				if spawn then
					moveCharacter(player, spawn.CFrame + Vector3.new(0, 3, 0))
					notify(player, "info", "Oops! You fell. Back to the start.")
				end
			end
		end
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	leaveQueue(player)
	local state = states[player]
	if state then
		-- Garde la progression de la journée avant de remettre les objets portés par terre.
		captureDayProgress(state)
	end
	returnAllItems(player)
	states[player] = nil
	lastLift[player] = nil
	saveData(player, state)
	if state and state.Loaded then
		refreshUnlocks(true)
	end
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
