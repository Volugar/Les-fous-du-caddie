-- TidyUI (LocalScript)
-- Emplacement : StarterPlayer > StarterPlayerScripts
-- Écran du joueur et commandes : clic / appui pour ramasser et ranger, sac,
-- barre d'outils (main, aimant, loupe), chronomètre, compteurs par catégorie,
-- points, améliorations, zone actuelle, messages, et écrans d'accueil et de fin.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local TidyConfig = require(ReplicatedStorage:WaitForChild("TidyConfig"))
local remotes = ReplicatedStorage:WaitForChild("TidyRemotes")
local actionEvent = remotes:WaitForChild("Action")
local notifyEvent = remotes:WaitForChild("Notify")
local upgradeFunction = remotes:WaitForChild("BuyUpgrade")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------------
-- Couleurs et fonctions pour construire l'interface
---------------------------------------------------------------------------
local TEXT_COLOR = Color3.fromRGB(238, 238, 236) -- texte clair sur les panneaux sombres
local OVERLAY_COLOR = Color3.fromRGB(255, 255, 255) -- texte blanc contouré sur le décor
local MUTED_COLOR = Color3.fromRGB(160, 166, 176)
local PANEL_COLOR = Color3.fromRGB(26, 29, 34)
local SOFT_COLOR = Color3.fromRGB(52, 57, 66)
local ACCENT_COLOR = Color3.fromRGB(96, 168, 124)
local ERROR_COLOR = Color3.fromRGB(226, 104, 92)
local GOLD_COLOR = Color3.fromRGB(226, 196, 120)
local POINTS_COLOR = Color3.fromRGB(226, 196, 120)
local LOCKED_COLOR = Color3.fromRGB(62, 66, 74)
local BUTTON_TEXT = Color3.fromRGB(255, 255, 255)

local function make(className, properties)
	local instance = Instance.new(className)
	local parent = properties.Parent
	properties.Parent = nil
	for key, value in properties do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function addCorner(parent, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function addStroke(parent)
	make("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.88, Thickness = 1, Parent = parent })
end

local function makePanel(properties)
	properties.BackgroundColor3 = properties.BackgroundColor3 or PANEL_COLOR
	properties.BackgroundTransparency = properties.BackgroundTransparency or 0.15
	properties.BorderSizePixel = 0
	local frame = make("Frame", properties)
	addCorner(frame, 8)
	addStroke(frame)
	return frame
end

local function makeLabel(parent, properties)
	properties.Parent = parent
	properties.BackgroundTransparency = 1
	properties.TextScaled = true
	properties.TextWrapped = true
	properties.TextColor3 = properties.TextColor3 or TEXT_COLOR
	properties.Font = properties.Font or Enum.Font.GothamMedium
	local maxSize = properties.MaxTextSize
	properties.MaxTextSize = nil
	local label = make("TextLabel", properties)
	if maxSize then
		make("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = label })
	end
	return label
end

local function makeButton(parent, properties)
	properties.Parent = parent
	properties.BackgroundColor3 = properties.BackgroundColor3 or ACCENT_COLOR
	properties.AutoButtonColor = true
	properties.BorderSizePixel = 0
	properties.Font = properties.Font or Enum.Font.GothamBold
	properties.TextColor3 = properties.TextColor3 or BUTTON_TEXT
	properties.TextScaled = true
	local button = make("TextButton", properties)
	addCorner(button, 6)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = button,
	})
	return button
end

-- Nom de touche adapté au clavier du joueur (AZERTY, QWERTY...).
local function keyName(keyCode)
	local ok, text = pcall(function()
		return UserInputService:GetStringForKeyCode(keyCode)
	end)
	if ok and type(text) == "string" and text ~= "" then
		return string.upper(text)
	end
	return keyCode.Name
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local function plural(itemType)
	local info = TidyConfig.ItemTypes[itemType]
	return info and info.Plural or itemType
end

---------------------------------------------------------------------------
-- Construction de l'interface
---------------------------------------------------------------------------
local screenGui = make("ScreenGui", {
	Name = "TidyGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

-- Chronomètre (en haut au centre) et consigne.
local timerLabel = makeLabel(screenGui, {
	Name = "Timer",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 4),
	Size = UDim2.new(0, 170, 0, 46),
	Font = Enum.Font.GothamBold,
	Text = "00:00",
	TextColor3 = OVERLAY_COLOR,
	TextStrokeTransparency = 0.2,
	MaxTextSize = 42,
})

local hintLabel = makeLabel(screenGui, {
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 52),
	Size = UDim2.new(0.5, 0, 0, 26),
	Font = Enum.Font.GothamBold,
	Text = "",
	TextColor3 = OVERLAY_COLOR,
	TextStrokeTransparency = 0.3,
	MaxTextSize = 18,
})

-- Progression (en haut à droite).
local progressPanel = makePanel({
	Name = "Progress",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 8),
	Size = UDim2.new(0, 230, 0, 80 + #TidyConfig.TypeOrder * 24),
	Parent = screenGui,
})
makeLabel(progressPanel, {
	Name = "Title",
	Position = UDim2.new(0, 12, 0, 8),
	Size = UDim2.new(1, -24, 0, 16),
	Font = Enum.Font.GothamMedium,
	Text = "PROGRESS",
	TextColor3 = MUTED_COLOR,
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxTextSize = 13,
})
local totalLabel = makeLabel(progressPanel, {
	Name = "Total",
	Position = UDim2.new(0, 12, 0, 28),
	Size = UDim2.new(1, -24, 0, 24),
	Font = Enum.Font.GothamBold,
	Text = "Items left to put away: ...",
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxTextSize = 18,
})
local progressBack = make("Frame", {
	Name = "Bar",
	Position = UDim2.new(0, 12, 0, 60),
	Size = UDim2.new(1, -24, 0, 6),
	BackgroundColor3 = SOFT_COLOR,
	BorderSizePixel = 0,
	Parent = progressPanel,
})
addCorner(progressBack, 3)
local progressFill = make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = ACCENT_COLOR,
	BorderSizePixel = 0,
	Parent = progressBack,
})
addCorner(progressFill, 3)

local categoryLabels = {}
for index, itemType in TidyConfig.TypeOrder do
	categoryLabels[itemType] = makeLabel(progressPanel, {
		Name = "Category_" .. itemType,
		Position = UDim2.new(0, 12, 0, 50 + index * 24),
		Size = UDim2.new(1, -24, 0, 20),
		Text = plural(itemType) .. ": 0 / 0",
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
	})
end

-- Points et bouton des améliorations (à gauche).
local leftPanel = makePanel({
	Name = "PointsPanel",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.42, 0),
	Size = UDim2.new(0, 190, 0, 92),
	Parent = screenGui,
})
local pointsLabel = makeLabel(leftPanel, {
	Name = "Points",
	Position = UDim2.new(0, 10, 0, 8),
	Size = UDim2.new(1, -20, 0, 28),
	Font = Enum.Font.GothamBold,
	Text = "Points: 0",
	TextColor3 = POINTS_COLOR,
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxTextSize = 22,
})
local upgradesButton = makeButton(leftPanel, {
	Name = "UpgradesButton",
	Position = UDim2.new(0, 10, 0, 44),
	Size = UDim2.new(1, -20, 0, 38),
	Text = "Upgrades [" .. keyName(Enum.KeyCode.G) .. "]",
	BackgroundColor3 = ACCENT_COLOR,
	TextColor3 = BUTTON_TEXT,
})

-- Zone actuelle, sac et barre d'outils (en bas au centre).
local areaLabel = makeLabel(screenGui, {
	Name = "Area",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -128),
	Size = UDim2.new(0, 420, 0, 22),
	Font = Enum.Font.GothamBold,
	Text = "",
	TextColor3 = OVERLAY_COLOR,
	TextStrokeTransparency = 0.3,
	MaxTextSize = 18,
})

local bagBar = make("Frame", {
	Name = "Bag",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -82),
	Size = UDim2.new(0, 520, 0, 40),
	BackgroundTransparency = 1,
	Parent = screenGui,
})
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = bagBar,
})
local previousButton = makeButton(bagBar, {
	Name = "Previous",
	LayoutOrder = 1,
	Size = UDim2.new(0, 36, 0, 36),
	Text = "<",
	BackgroundColor3 = SOFT_COLOR,
	TextColor3 = TEXT_COLOR,
})
local chipsFrame = make("Frame", {
	Name = "Chips",
	LayoutOrder = 2,
	Size = UDim2.new(0, 0, 0, 36),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Parent = bagBar,
})
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = chipsFrame,
})
local nextButton = makeButton(bagBar, {
	Name = "Next",
	LayoutOrder = 3,
	Size = UDim2.new(0, 36, 0, 36),
	Text = ">",
	BackgroundColor3 = SOFT_COLOR,
	TextColor3 = TEXT_COLOR,
})
local dropButton = makeButton(bagBar, {
	Name = "Drop",
	LayoutOrder = 4,
	Size = UDim2.new(0, 86, 0, 36),
	Text = "Drop",
	BackgroundColor3 = Color3.fromRGB(150, 110, 90),
})

local hotbar = make("Frame", {
	Name = "Hotbar",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0, 300, 0, 62),
	BackgroundTransparency = 1,
	Parent = screenGui,
})
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = hotbar,
})

local TOOLS = {
	{ Id = "Hand", Name = "Hand", Key = Enum.KeyCode.One, Upgrade = nil },
	{ Id = "Magnet", Name = "Magnet", Key = Enum.KeyCode.Two, Upgrade = "Magnet" },
	{ Id = "Magnifier", Name = "Magnifier", Key = Enum.KeyCode.Three, Upgrade = "Magnifier" },
}
local toolButtons = {}
for index, tool in TOOLS do
	toolButtons[tool.Id] = makeButton(hotbar, {
		Name = "Tool_" .. tool.Id,
		LayoutOrder = index,
		Size = UDim2.new(0, 92, 0, 60),
		Text = index .. "\n" .. tool.Name,
		BackgroundColor3 = PANEL_COLOR,
		TextColor3 = TEXT_COLOR,
	})
end

-- Aide des commandes (en bas à droite, ordinateur seulement).
local controlsLabel = makeLabel(screenGui, {
	Name = "Controls",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -12),
	Size = UDim2.new(0, 260, 0, 110),
	Text = "Click: pick up / put away\n"
		.. keyName(Enum.KeyCode.E)
		.. ": next item\n"
		.. keyName(Enum.KeyCode.Q)
		.. ": drop item\n1, 2, 3: tools\n"
		.. keyName(Enum.KeyCode.G)
		.. ": upgrades",
	Font = Enum.Font.GothamBold,
	TextColor3 = OVERLAY_COLOR,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextYAlignment = Enum.TextYAlignment.Bottom,
	TextStrokeTransparency = 0.3,
	MaxTextSize = 16,
})
controlsLabel.Visible = not (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)

-- Message temporaire (au centre).
local toastLabel = makeLabel(screenGui, {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.3, 0),
	Size = UDim2.new(0.6, 0, 0, 34),
	Font = Enum.Font.GothamBold,
	Text = "",
	TextColor3 = OVERLAY_COLOR,
	TextStrokeTransparency = 0.2,
	TextTransparency = 1,
	MaxTextSize = 26,
})

-- Fenêtre des améliorations.
local upgradesPanel = makePanel({
	Name = "Upgrades",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 440, 0, 80 + #TidyConfig.Upgrades * 66),
	BackgroundTransparency = 0.05,
	Visible = false,
	Parent = screenGui,
})
makeLabel(upgradesPanel, {
	Name = "Title",
	Position = UDim2.new(0, 16, 0, 12),
	Size = UDim2.new(1, -120, 0, 30),
	Font = Enum.Font.GothamBold,
	Text = "Upgrades",
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxTextSize = 24,
})
local closeUpgradesButton = makeButton(upgradesPanel, {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.new(0, 90, 0, 30),
	Text = "Close",
	BackgroundColor3 = SOFT_COLOR,
	TextColor3 = TEXT_COLOR,
})

local upgradeRows = {}
for index, upgrade in TidyConfig.Upgrades do
	local row = make("Frame", {
		Name = "Row_" .. upgrade.Id,
		Position = UDim2.new(0, 12, 0, 54 + (index - 1) * 66),
		Size = UDim2.new(1, -24, 0, 58),
		BackgroundColor3 = SOFT_COLOR,
		BorderSizePixel = 0,
		Parent = upgradesPanel,
	})
	addCorner(row, 6)
	local title = makeLabel(row, {
		Name = "Name",
		Position = UDim2.new(0, 10, 0, 6),
		Size = UDim2.new(1, -150, 0, 22),
		Font = Enum.Font.GothamBold,
		Text = upgrade.Name,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
	})
	local description = makeLabel(row, {
		Name = "Description",
		Position = UDim2.new(0, 10, 0, 30),
		Size = UDim2.new(1, -150, 0, 20),
		Text = upgrade.Description,
		TextColor3 = MUTED_COLOR,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
	})
	local buyButton = makeButton(row, {
		Name = "Buy",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0, 128, 0, 42),
		Text = "",
	})
	upgradeRows[upgrade.Id] = { Title = title, Description = description, Button = buyButton, Upgrade = upgrade }
end

-- Fenêtre de message centrée (accueil et fin).
local function makeMessagePanel(name, titleText)
	local panel = makePanel({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 280),
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = screenGui,
	})
	make("UISizeConstraint", { MaxSize = Vector2.new(500, 280), Parent = panel })
	makeLabel(panel, {
		Name = "Title",
		Position = UDim2.new(0, 20, 0, 18),
		Size = UDim2.new(1, -40, 0, 32),
		Font = Enum.Font.GothamBold,
		Text = titleText,
		MaxTextSize = 26,
	})
	local body = makeLabel(panel, {
		Name = "Body",
		Position = UDim2.new(0, 20, 0, 58),
		Size = UDim2.new(1, -40, 1, -130),
		Text = "",
		TextColor3 = MUTED_COLOR,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 18,
	})
	return panel, body
end

local introPanel, introBody = makeMessagePanel("Welcome", "Welcome to the agency")
introBody.Text = "The "
	.. TidyConfig.AgencyName
	.. " opens on Monday, and the place is a mess.\n\n"
	.. "Click (or tap) an item to put it in your bag, then click the place where it belongs. "
	.. "Take your time: every item has its place."
local startButton = makeButton(introPanel, {
	Name = "Start",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.new(0, 170, 0, 42),
	Text = "Start",
})
introPanel.Visible = true

local completePanel, completeBody = makeMessagePanel("Complete", "The agency is in order.")
local replayButton = makeButton(completePanel, {
	Name = "Replay",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(0.5, -6, 1, -16),
	Size = UDim2.new(0, 160, 0, 42),
	Text = "Play again",
})
local closeCompleteButton = makeButton(completePanel, {
	Name = "Close",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0.5, 6, 1, -16),
	Size = UDim2.new(0, 160, 0, 42),
	Text = "Close",
	BackgroundColor3 = SOFT_COLOR,
	TextColor3 = TEXT_COLOR,
})

---------------------------------------------------------------------------
-- Messages temporaires
---------------------------------------------------------------------------
local toastToken = 0
local function showToast(text, kind)
	if type(text) ~= "string" or text == "" then
		return
	end
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	if kind == "error" then
		toastLabel.TextColor3 = ERROR_COLOR
	elseif kind == "points" or kind == "placed" then
		toastLabel.TextColor3 = GOLD_COLOR
	elseif kind == "room" then
		toastLabel.TextColor3 = ACCENT_COLOR
	else
		toastLabel.TextColor3 = OVERLAY_COLOR
	end
	toastLabel.TextTransparency = 0
	task.delay(1.6, function()
		if token == toastToken then
			TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

-- Petit nuage de poussière discret et son doux quand un objet est rangé.
local function celebrate(position, strength)
	if typeof(position) ~= "Vector3" then
		return
	end
	local holder = make("Part", {
		Name = "TidySparkle",
		Anchored = true,
		CanCollide = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position),
		Parent = Workspace,
	})
	holder.CanTouch = false
	holder.CanQuery = false
	local emitter = make("ParticleEmitter", {
		Name = "Sparkles",
		Rate = 0,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(1, 2.5),
		SpreadAngle = Vector2.new(70, 70),
		Color = ColorSequence.new(Color3.fromRGB(235, 232, 225)),
		Transparency = NumberSequence.new(0.4),
		Size = NumberSequence.new(0.25),
		LightEmission = 0.2,
		Parent = holder,
	})
	emitter:Emit(strength or 10)
	local sound = make("Sound", {
		Name = "PlaceSound",
		SoundId = TidyConfig.PlaceSoundId,
		Volume = if (strength or 10) < 6 then 0.12 else 0.25,
		PlaybackSpeed = 0.9 + math.random() * 0.25,
		Parent = holder,
	})
	sound:Play()
	Debris:AddItem(holder, 1.5)
end

notifyEvent.OnClientEvent:Connect(function(kind, text, position)
	showToast(text, kind)
	if kind == "placed" then
		celebrate(position, 10)
	end
end)

---------------------------------------------------------------------------
-- Chronomètre et fin de partie
---------------------------------------------------------------------------
local timerStart = nil
local timerStopped = nil
local bestTime = nil
local finished = false

local function elapsed()
	if not timerStart then
		return 0
	end
	return (timerStopped or os.clock()) - timerStart
end

local function startTimer()
	if not timerStart then
		timerStart = os.clock()
		timerStopped = nil
	end
end

local function showCompletion()
	if finished then
		return
	end
	finished = true
	startTimer()
	timerStopped = os.clock()
	local time = elapsed()
	local isRecord = bestTime == nil or time < bestTime
	if isRecord then
		bestTime = time
	end
	introPanel.Visible = false
	upgradesPanel.Visible = false
	completeBody.Text = "All "
		.. (ReplicatedStorage:GetAttribute("TidyTotal") or 0)
		.. " items have been put away.\n\n"
		.. "Time: "
		.. formatTime(time)
		.. (if isRecord then "  (personal best)" else "")
		.. "\nBest time: "
		.. formatTime(bestTime)
		.. "\nPoints: "
		.. (player:GetAttribute("Points") or 0)
		.. "\n\nThe offices are ready to welcome job seekers."
	completePanel.Visible = true
end

---------------------------------------------------------------------------
-- Mise à jour des compteurs, du sac, des points et des outils
---------------------------------------------------------------------------
local equippedTool = "Hand"

local function updateCounters()
	local total = ReplicatedStorage:GetAttribute("TidyTotal") or 0
	local remaining = ReplicatedStorage:GetAttribute("TidyRemaining") or total
	local placed = total - remaining
	totalLabel.Text = "Items left to put away: " .. remaining
	local progress = if total > 0 then placed / total else 0
	TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(progress, 1) }):Play()
	for _, itemType in TidyConfig.TypeOrder do
		local done = ReplicatedStorage:GetAttribute("Placed_" .. itemType) or 0
		local count = ReplicatedStorage:GetAttribute("Total_" .. itemType) or 0
		local label = categoryLabels[itemType]
		label.Text = plural(itemType) .. ": " .. done .. " / " .. count
		label.TextColor3 = if count > 0 and done >= count then ACCENT_COLOR else TEXT_COLOR
	end
	if total > 0 and remaining <= 0 then
		showCompletion()
	end
end

local function heldTypes()
	local text = player:GetAttribute("Held") or ""
	local list = {}
	for itemType in string.gmatch(text, "[^,]+") do
		table.insert(list, itemType)
	end
	return list
end

local function updateHint()
	if finished then
		hintLabel.Text = "Everything is in its place."
		return
	end
	local carrying = player:GetAttribute("Carrying") or ""
	local info = TidyConfig.ItemTypes[carrying]
	if info then
		hintLabel.Text = info.DisplayName .. ": " .. info.Hint
	else
		hintLabel.Text = "Click an item to pick it up."
	end
end

local function updateBag()
	for _, child in chipsFrame:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local list = heldTypes()
	local selected = player:GetAttribute("Selected") or 0
	local capacity = player:GetAttribute("Capacity") or TidyConfig.BaseCapacity
	for index, itemType in list do
		local info = TidyConfig.ItemTypes[itemType]
		local chip = makeLabel(chipsFrame, {
			Name = "Chip" .. index,
			LayoutOrder = index,
			Size = UDim2.new(0, 84, 0, 34),
			BackgroundTransparency = 0.1,
			Font = Enum.Font.GothamBold,
			Text = info and info.DisplayName or itemType,
			TextColor3 = if index == selected then BUTTON_TEXT else TEXT_COLOR,
			MaxTextSize = 14,
		})
		chip.BackgroundTransparency = 0.1
		chip.BackgroundColor3 = if index == selected then ACCENT_COLOR else PANEL_COLOR
		addCorner(chip, 6)
	end
	local counter = makeLabel(chipsFrame, {
		Name = "ChipCount",
		LayoutOrder = 100,
		Size = UDim2.new(0, 54, 0, 34),
		Font = Enum.Font.GothamBold,
		Text = #list .. "/" .. capacity,
		TextColor3 = if #list >= capacity then ERROR_COLOR else OVERLAY_COLOR,
		TextStrokeTransparency = 0.3,
		MaxTextSize = 18,
	})
	counter.BackgroundTransparency = 1
	local hasItems = #list > 0
	previousButton.Visible = #list > 1
	nextButton.Visible = #list > 1
	dropButton.Visible = hasItems
end

local function toolUnlocked(tool)
	return tool.Upgrade == nil or (player:GetAttribute("Level_" .. tool.Upgrade) or 0) >= 1
end

local function updateTools()
	for index, tool in TOOLS do
		local button = toolButtons[tool.Id]
		local unlocked = toolUnlocked(tool)
		if not unlocked and equippedTool == tool.Id then
			equippedTool = "Hand"
		end
		button.Text = index .. "\n" .. tool.Name .. (if unlocked then "" else "\n(locked)")
		if not unlocked then
			button.BackgroundColor3 = LOCKED_COLOR
			button.TextColor3 = MUTED_COLOR
		elseif equippedTool == tool.Id then
			button.BackgroundColor3 = ACCENT_COLOR
			button.TextColor3 = BUTTON_TEXT
		else
			button.BackgroundColor3 = PANEL_COLOR
			button.TextColor3 = TEXT_COLOR
		end
	end
end

local function updateUpgrades()
	local points = player:GetAttribute("Points") or 0
	pointsLabel.Text = "Points: " .. points
	for id, row in upgradeRows do
		local level = player:GetAttribute("Level_" .. id) or 0
		local upgrade = row.Upgrade
		row.Title.Text = upgrade.Name .. "  (lvl " .. level .. "/" .. upgrade.MaxLevel .. ")"
		if level >= upgrade.MaxLevel then
			row.Button.Text = "MAX"
			row.Button.BackgroundColor3 = LOCKED_COLOR
			row.Button.TextColor3 = MUTED_COLOR
		else
			local cost = TidyConfig.GetUpgradeCost(upgrade, level)
			row.Button.Text = "Buy\n" .. cost .. " pts"
			row.Button.BackgroundColor3 = if points >= cost then ACCENT_COLOR else LOCKED_COLOR
			row.Button.TextColor3 = if points >= cost then BUTTON_TEXT else MUTED_COLOR
		end
	end
end

local function equipTool(toolId)
	for _, tool in TOOLS do
		if tool.Id == toolId then
			if not toolUnlocked(tool) then
				showToast("Unlock this tool in the upgrades menu [" .. keyName(Enum.KeyCode.G) .. "].", "error")
				return
			end
			equippedTool = toolId
			updateTools()
			return
		end
	end
end

---------------------------------------------------------------------------
-- Effets dans le décor : places lumineuses, zones en surbrillance, survol, loupe
---------------------------------------------------------------------------
local GHOST_TRANSPARENCY = 0.6
local zoneHighlights = {}

local function refreshWorld()
	local carrying = player:GetAttribute("Carrying") or ""
	for _, slot in CollectionService:GetTagged(TidyConfig.SlotTag) do
		if slot:IsA("BasePart") then
			local matches = carrying ~= "" and slot:GetAttribute("ItemType") == carrying and slot:GetAttribute("Occupied") ~= true
			slot.Transparency = if matches then GHOST_TRANSPARENCY else 1
		end
	end
	for _, zone in CollectionService:GetTagged(TidyConfig.ZoneTag) do
		-- Contour vert sur les meubles du bon type (créé seulement quand il sert,
		-- car Roblox limite le nombre de contours affichés en même temps).
		local matches = carrying ~= "" and zone:GetAttribute("ItemType") == carrying
		local highlight = zoneHighlights[zone]
		if matches and (not highlight or highlight.Parent ~= zone) then
			zoneHighlights[zone] = make("Highlight", {
				Name = "ZoneHighlight",
				FillColor = ACCENT_COLOR,
				FillTransparency = 0.85,
				OutlineColor = ACCENT_COLOR,
				OutlineTransparency = 0.2,
				DepthMode = Enum.HighlightDepthMode.Occluded,
				Parent = zone,
			})
		elseif not matches and highlight then
			highlight:Destroy()
			zoneHighlights[zone] = nil
		end

		-- Panneau flottant : visible pour la catégorie en main, ou quand on est tout près.
		local billboard = zone:FindFirstChild("CategoryBillboard")
		if billboard and billboard:IsA("BillboardGui") then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local anchor = billboard.Adornee
			local near = root ~= nil and anchor ~= nil and anchor:IsA("BasePart") and (anchor.Position - root.Position).Magnitude < 16
			billboard.Enabled = matches or near
		end
	end
end

local refreshQueued = false
local function requestRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		refreshWorld()
	end)
end

for _, tag in { TidyConfig.SlotTag, TidyConfig.ZoneTag } do
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		instance:GetAttributeChangedSignal("Occupied"):Connect(requestRefresh)
		requestRefresh()
	end)
	for _, instance in CollectionService:GetTagged(tag) do
		instance:GetAttributeChangedSignal("Occupied"):Connect(requestRefresh)
	end
end

local hoverHighlight = make("Highlight", {
	Name = "HoverHighlight",
	FillTransparency = 1,
	OutlineColor = Color3.fromRGB(255, 255, 255),
	OutlineTransparency = 0,
	DepthMode = Enum.HighlightDepthMode.Occluded,
	Enabled = false,
	Parent = Workspace,
})

-- Repère de la loupe : un rayon lumineux entre le joueur et sa destination.
local guidePart = make("Part", {
	Name = "TidyGuideTarget",
	Anchored = true,
	CanCollide = false,
	Transparency = 1,
	Size = Vector3.new(0.2, 0.2, 0.2),
	Parent = Workspace,
})
guidePart.CanTouch = false
guidePart.CanQuery = false
local guideAttachment = make("Attachment", { Name = "GuideEnd", Parent = guidePart })
local guideBeam = make("Beam", {
	Name = "GuideBeam",
	Attachment1 = guideAttachment,
	Color = ColorSequence.new(GOLD_COLOR),
	Transparency = NumberSequence.new(0.2),
	Width0 = 0.4,
	Width1 = 0.4,
	FaceCamera = true,
	LightEmission = 1,
	Enabled = false,
	Parent = guidePart,
})
local playerAttachment = nil

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function updateGuide()
	local root = getRoot()
	local active = equippedTool == "Magnifier" and toolUnlocked(TOOLS[3]) and root ~= nil and not finished
	if not active then
		guideBeam.Enabled = false
		return
	end
	if not playerAttachment or playerAttachment.Parent ~= root then
		playerAttachment = make("Attachment", { Name = "TidyGuideStart", Parent = root })
	end
	guideBeam.Attachment0 = playerAttachment

	local carrying = player:GetAttribute("Carrying") or ""
	local bestPosition, bestDistance = nil, math.huge
	if carrying ~= "" then
		for _, slot in CollectionService:GetTagged(TidyConfig.SlotTag) do
			if slot:GetAttribute("ItemType") == carrying and slot:GetAttribute("Occupied") ~= true then
				local distance = (slot.Position - root.Position).Magnitude
				if distance < bestDistance then
					bestPosition, bestDistance = slot.Position, distance
				end
			end
		end
	else
		for _, item in CollectionService:GetTagged(TidyConfig.ItemTag) do
			if item:GetAttribute("State") == "Loose" and item.PrimaryPart then
				local distance = (item.PrimaryPart.Position - root.Position).Magnitude
				if distance < bestDistance then
					bestPosition, bestDistance = item.PrimaryPart.Position, distance
				end
			end
		end
	end
	if bestPosition then
		guidePart.CFrame = CFrame.new(bestPosition)
		guideBeam.Enabled = true
	else
		guideBeam.Enabled = false
	end
end

---------------------------------------------------------------------------
-- Clic / appui dans le décor
---------------------------------------------------------------------------

-- Trouve ce qui a été visé : un objet qui traîne ("item"), une zone de rangement ("zone")
-- ou une porte verrouillée ("door").
local function resolveTarget(instance)
	local current = instance
	while current and current ~= Workspace do
		if CollectionService:HasTag(current, TidyConfig.DoorTag) then
			return "door", current
		end
		if CollectionService:HasTag(current, TidyConfig.ItemTag) and current:GetAttribute("State") == "Loose" then
			return "item", current
		end
		if CollectionService:HasTag(current, TidyConfig.ZoneTag) then
			return "zone", current
		end
		current = current.Parent
	end
	return nil, nil
end

local function raycastRay(ray)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, guidePart }
	return Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
end

local function handleClick(ray)
	if finished then
		return
	end
	startTimer()
	local result = raycastRay(ray)
	local kind, target = nil, nil
	if result then
		kind, target = resolveTarget(result.Instance)
	end
	if equippedTool == "Magnet" and kind ~= "zone" then
		actionEvent:FireServer("magnet")
		return
	end
	if not kind then
		return
	end
	local root = getRoot()
	if root and (result.Position - root.Position).Magnitude > TidyConfig.ReachDistance + 2 then
		showToast("Too far away. Move closer.", "error")
		return
	end
	if kind == "item" then
		actionEvent:FireServer("pick", target)
	elseif kind == "door" then
		actionEvent:FireServer("unlock", target)
	else
		actionEvent:FireServer("place", target)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local camera = Workspace.CurrentCamera
		if camera then
			local mouse = UserInputService:GetMouseLocation()
			handleClick(camera:ViewportPointToRay(mouse.X, mouse.Y))
		end
	elseif input.KeyCode == Enum.KeyCode.Q then
		actionEvent:FireServer("drop")
	elseif input.KeyCode == Enum.KeyCode.E then
		actionEvent:FireServer("cycle", 1)
	elseif input.KeyCode == Enum.KeyCode.G then
		upgradesPanel.Visible = not upgradesPanel.Visible
	else
		for _, tool in TOOLS do
			if input.KeyCode == tool.Key then
				equipTool(tool.Id)
			end
		end
	end
end)

UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
	if gameProcessed or #touchPositions == 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera then
		local position = touchPositions[1]
		handleClick(camera:ScreenPointToRay(position.X, position.Y))
	end
end)

-- Survol à la souris : contour blanc sur ce qui peut être cliqué.
local lastHoverCheck = 0
RunService.RenderStepped:Connect(function()
	if timerStart and not finished then
		timerLabel.Text = formatTime(elapsed())
	end
	if not UserInputService.MouseEnabled then
		return
	end
	local now = os.clock()
	if now - lastHoverCheck < 0.05 then
		return
	end
	lastHoverCheck = now
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local result = raycastRay(camera:ViewportPointToRay(mouse.X, mouse.Y))
	local kind, target = nil, nil
	if result then
		kind, target = resolveTarget(result.Instance)
	end
	local root = getRoot()
	if kind and root and (result.Position - root.Position).Magnitude <= TidyConfig.ReachDistance + 2 then
		hoverHighlight.Adornee = target
		hoverHighlight.Enabled = true
	else
		hoverHighlight.Enabled = false
	end
end)

---------------------------------------------------------------------------
-- Boutons
---------------------------------------------------------------------------
startButton.Activated:Connect(function()
	introPanel.Visible = false
	startTimer()
end)
upgradesButton.Activated:Connect(function()
	upgradesPanel.Visible = not upgradesPanel.Visible
end)
closeUpgradesButton.Activated:Connect(function()
	upgradesPanel.Visible = false
end)
previousButton.Activated:Connect(function()
	actionEvent:FireServer("cycle", -1)
end)
nextButton.Activated:Connect(function()
	actionEvent:FireServer("cycle", 1)
end)
dropButton.Activated:Connect(function()
	actionEvent:FireServer("drop")
end)
for _, tool in TOOLS do
	toolButtons[tool.Id].Activated:Connect(function()
		equipTool(tool.Id)
	end)
end
for id, row in upgradeRows do
	row.Button.Activated:Connect(function()
		local ok, success, message = pcall(function()
			return upgradeFunction:InvokeServer(id)
		end)
		if ok then
			showToast(message, if success then "points" else "error")
		end
	end)
end
replayButton.Activated:Connect(function()
	actionEvent:FireServer("restart")
end)
closeCompleteButton.Activated:Connect(function()
	completePanel.Visible = false
end)

---------------------------------------------------------------------------
-- Écoute des changements
---------------------------------------------------------------------------
for _, name in { "Held", "Selected", "Capacity", "Carrying" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		updateBag()
		updateHint()
		requestRefresh()
	end)
end
for _, name in { "Points", "Level_Capacity", "Level_Speed", "Level_Magnet", "Level_Magnifier" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		updateUpgrades()
		updateTools()
	end)
end
ReplicatedStorage:GetAttributeChangedSignal("TidyRemaining"):Connect(updateCounters)
ReplicatedStorage:GetAttributeChangedSignal("TidyTotal"):Connect(updateCounters)
for _, itemType in TidyConfig.TypeOrder do
	ReplicatedStorage:GetAttributeChangedSignal("Placed_" .. itemType):Connect(updateCounters)
	ReplicatedStorage:GetAttributeChangedSignal("Total_" .. itemType):Connect(updateCounters)
end

-- Nouvelle partie : le chronomètre repart de zéro.
ReplicatedStorage:GetAttributeChangedSignal("RoundNumber"):Connect(function()
	finished = false
	completePanel.Visible = false
	timerStart = os.clock()
	timerStopped = nil
	updateCounters()
	updateHint()
	requestRefresh()
end)

-- Boucle lente : zone actuelle, loupe, et filet de sécurité pour les effets.
task.spawn(function()
	while true do
		local root = getRoot()
		local room = root and TidyConfig.GetRoomAt(root.Position)
		if room then
			local done = ReplicatedStorage:GetAttribute("RoomPlaced_" .. room.Id) or 0
			local count = ReplicatedStorage:GetAttribute("RoomTotal_" .. room.Id) or 0
			areaLabel.Text = "You are in: " .. room.Name .. "  (" .. done .. " / " .. count .. " done)"
		else
			areaLabel.Text = ""
		end
		updateGuide()
		refreshWorld()
		task.wait(0.25)
	end
end)

updateCounters()
updateHint()
updateBag()
updateTools()
updateUpgrades()
refreshWorld()
