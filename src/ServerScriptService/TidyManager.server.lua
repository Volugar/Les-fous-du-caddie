-- TidyManager (Script)
-- Emplacement : ServerScriptService
-- Logique principale du jeu : construit l'agence, permet au joueur de ramasser les objets,
-- de les remettre à leur place, et compte combien il en reste.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TidyConfig = require(ReplicatedStorage:WaitForChild("TidyConfig"))
local AgencyBuilder = require(ServerScriptService:WaitForChild("AgencyBuilder"))

local agency = AgencyBuilder.Build()

local totalItems = #agency.Items
local remainingItems = totalItems

-- Progression partagée, lue par le script TidyUI sur l'écran du joueur.
ReplicatedStorage:SetAttribute("TidyTotal", totalItems)
ReplicatedStorage:SetAttribute("TidyRemaining", remainingItems)
ReplicatedStorage:SetAttribute("AgencyInOrder", false)

-- Ce que porte chaque joueur : carried[player] = { Item = model, Weld = weld }
local carried = {}

---------------------------------------------------------------------------
-- Fonctions utilitaires
---------------------------------------------------------------------------

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

-- Vérification côté serveur que le joueur est vraiment assez proche.
local function isWithinReach(root, part)
	local limit = TidyConfig.MaxDistance + TidyConfig.ServerDistanceMargin
	return (root.Position - part.Position).Magnitude <= limit
end

-- Fait passer un objet de "porté en main" à "posé dans le décor", et inversement.
local function setHeldPhysics(item, held)
	for _, part in item:GetDescendants() do
		if part:IsA("BasePart") then
			if part:GetAttribute("RestCanCollide") == nil then
				part:SetAttribute("RestCanCollide", part.CanCollide)
			end
			if held then
				part.CanCollide = false
				part.CanTouch = false
				part.Massless = true
				part.Anchored = false
			else
				part.Anchored = true
				part.Massless = false
				part.CanTouch = true
				part.CanCollide = part:GetAttribute("RestCanCollide")
			end
		end
	end
end

local function setCarrying(player, itemType)
	player:SetAttribute("Carrying", itemType or "")
end

-- Remet un objet porté à sa position de départ (si le joueur meurt ou quitte le jeu).
local function returnCarriedItem(player)
	local entry = carried[player]
	if not entry then
		return
	end
	carried[player] = nil

	local item = entry.Item
	if entry.Weld then
		entry.Weld:Destroy()
	end
	if item.Parent then
		setHeldPhysics(item, false)
		item:PivotTo(item:GetAttribute("HomeCFrame"))
		item:SetAttribute("State", "Loose")
	end
	if player.Parent then
		setCarrying(player, nil)
	end
end

---------------------------------------------------------------------------
-- Ramasser et ranger
---------------------------------------------------------------------------

local function pickUp(player, item)
	if carried[player] then
		return
	end
	if item:GetAttribute("State") ~= "Loose" then
		return
	end
	local root = getLivingRoot(player)
	local main = item.PrimaryPart
	if not root or not main or not isWithinReach(root, main) then
		return
	end

	local itemType = item:GetAttribute("ItemType")
	local typeInfo = TidyConfig.ItemTypes[itemType]
	if not typeInfo then
		return
	end

	item:SetAttribute("State", "Carried")
	item:PivotTo(root.CFrame * typeInfo.CarryOffset)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = main
	weld.Parent = main

	setHeldPhysics(item, true)

	carried[player] = { Item = item, Weld = weld }
	setCarrying(player, itemType)
end

local function putAway(player, slot)
	local entry = carried[player]
	if not entry then
		return
	end
	local item = entry.Item
	if slot:GetAttribute("Occupied") then
		return
	end
	if slot:GetAttribute("ItemType") ~= item:GetAttribute("ItemType") then
		return
	end
	local root = getLivingRoot(player)
	if not root or not isWithinReach(root, slot) then
		return
	end

	carried[player] = nil
	entry.Weld:Destroy()
	setHeldPhysics(item, false)
	item:PivotTo(slot.CFrame)

	item:SetAttribute("State", "Placed")
	slot:SetAttribute("Occupied", true)

	-- L'objet et son emplacement sont terminés : on retire leurs boutons d'action.
	local pickupPrompt = item:FindFirstChild("PickupPrompt", true)
	if pickupPrompt then
		pickupPrompt:Destroy()
	end
	local placePrompt = slot:FindFirstChild("PlacePrompt")
	if placePrompt then
		placePrompt:Destroy()
	end

	setCarrying(player, nil)

	remainingItems -= 1
	ReplicatedStorage:SetAttribute("TidyRemaining", remainingItems)
	if remainingItems <= 0 then
		ReplicatedStorage:SetAttribute("AgencyInOrder", true)
	end
end

---------------------------------------------------------------------------
-- Branchement des boutons d'action
---------------------------------------------------------------------------

for _, item in agency.Items do
	local prompt = item:FindFirstChild("PickupPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			pickUp(player, item)
		end)
	end
end

for _, slot in agency.Slots do
	local prompt = slot:FindFirstChild("PlacePrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			putAway(player, slot)
		end)
	end
end

---------------------------------------------------------------------------
-- Joueurs
---------------------------------------------------------------------------

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			returnCarriedItem(player)
		end)
	end
end

local function onPlayerAdded(player)
	setCarrying(player, nil)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		returnCarriedItem(player)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	returnCarriedItem(player)
end)
