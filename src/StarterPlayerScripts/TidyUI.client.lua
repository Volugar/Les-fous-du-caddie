-- TidyUI (LocalScript)
-- Emplacement : StarterPlayer > StarterPlayerScripts
-- Écran du joueur et commandes, style "cartes crème et dorées" :
--  * chronomètre, consigne, compteurs (objets rangés, panier), offre limitée "DEAL" ;
--  * boutons Améliorations [G], Boutique [F], Quêtes [J], Paramètres [R] ;
--  * carte de l'objet en main, barre d'outils à 4 cases (main, aimant, loupe, rangement rapide) ;
--  * 6 cartes de tutoriel à l'entrée d'un niveau ;
--  * fenêtres : améliorations, boutique Robux, quêtes du jour, paramètres, fin de niveau,
--    choix du niveau dans les files d'attente du hall, rejoindre un ami ;
--  * clic / appui pour ramasser et ranger, aimant, loupe, effets et sons.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local TidyConfig = require(ReplicatedStorage:WaitForChild("TidyConfig"))
local remotes = ReplicatedStorage:WaitForChild("TidyRemotes")
local actionEvent = remotes:WaitForChild("Action")
local notifyEvent = remotes:WaitForChild("Notify")
local upgradeFunction = remotes:WaitForChild("BuyUpgrade")
local lobbyFunction = remotes:WaitForChild("Lobby")
local queueEvent = remotes:WaitForChild("Queue")
local shopFunction = remotes:WaitForChild("Shop")
local settingsEvent = remotes:WaitForChild("Settings")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local isTouchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

---------------------------------------------------------------------------
-- Thème et fonctions pour construire l'interface
---------------------------------------------------------------------------
local THEME = {
	Cream = Color3.fromRGB(252, 246, 230),
	CreamDark = Color3.fromRGB(238, 226, 200),
	Gold = Color3.fromRGB(222, 168, 66),
	GoldDark = Color3.fromRGB(176, 124, 40),
	Brown = Color3.fromRGB(96, 66, 40),
	Text = Color3.fromRGB(74, 54, 36),
	Muted = Color3.fromRGB(150, 128, 104),
	Red = Color3.fromRGB(228, 54, 48),
	Green = Color3.fromRGB(66, 176, 84),
	GreenDark = Color3.fromRGB(40, 120, 56),
	Orange = Color3.fromRGB(240, 150, 40),
	Blue = Color3.fromRGB(56, 140, 220),
	Yellow = Color3.fromRGB(255, 226, 90),
	White = Color3.fromRGB(255, 255, 255),
	Dark = Color3.fromRGB(40, 30, 22),
	Locked = Color3.fromRGB(190, 180, 166),
}
local FONT = Enum.Font.FredokaOne
local FONT_BIG = Enum.Font.LuckiestGuy

local function make(className, properties)
	local instance = Instance.new(className)
	local parent = properties.Parent
	properties.Parent = nil
	-- CanCollide d'abord : Roblox refuse CanQuery = false tant que CanCollide vaut true.
	if properties.CanCollide ~= nil then
		instance.CanCollide = properties.CanCollide
	end
	for key, value in properties do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function addCorner(parent, radius)
	return make("UICorner", { CornerRadius = radius or UDim.new(0, 12), Parent = parent })
end

local function addStroke(parent, color, thickness)
	return make("UIStroke", { Color = color or THEME.Gold, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

-- Texte blanc contouré (posé sur le décor), comme le chronomètre.
local function outlined(parent, properties)
	properties.Parent = parent
	properties.BackgroundTransparency = 1
	properties.Font = properties.Font or FONT
	properties.TextColor3 = properties.TextColor3 or THEME.White
	properties.TextStrokeColor3 = properties.TextStrokeColor3 or THEME.Dark
	properties.TextStrokeTransparency = properties.TextStrokeTransparency or 0
	properties.TextScaled = if properties.TextScaled == nil then true else properties.TextScaled
	return make("TextLabel", properties)
end

local function label(parent, properties)
	properties.Parent = parent
	properties.BackgroundTransparency = 1
	properties.Font = properties.Font or FONT
	properties.TextColor3 = properties.TextColor3 or THEME.Text
	properties.TextScaled = if properties.TextScaled == nil then true else properties.TextScaled
	return make("TextLabel", properties)
end

local function creamPanel(parent, properties)
	properties.Parent = parent
	properties.BackgroundColor3 = properties.BackgroundColor3 or THEME.Cream
	properties.BorderSizePixel = 0
	local frame = make("Frame", properties)
	addCorner(frame, UDim.new(0, 14))
	addStroke(frame, THEME.Gold, 3)
	return frame
end

local function button(parent, properties)
	properties.Parent = parent
	properties.Font = properties.Font or FONT
	properties.TextColor3 = properties.TextColor3 or THEME.White
	properties.BackgroundColor3 = properties.BackgroundColor3 or THEME.Green
	properties.AutoButtonColor = true
	properties.TextScaled = if properties.TextScaled == nil then true else properties.TextScaled
	local b = make("TextButton", properties)
	addCorner(b, UDim.new(0, 10))
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = b })
	return b
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
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local fmt = TidyConfig.FormatNumber

---------------------------------------------------------------------------
-- Écran principal
---------------------------------------------------------------------------
local screenGui = make("ScreenGui", {
	Name = "TidyUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})
make("UIScale", { Scale = if isTouchOnly then 0.75 else 1, Parent = screenGui })

local hud = {}

-- Chronomètre et consigne (en haut au centre).
hud.Timer = outlined(screenGui, { Name = "Timer", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.new(0, 260, 0, 64), Text = "00:00", Font = FONT_BIG })
hud.Hint = outlined(screenGui, {
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.27, 0),
	Size = UDim2.new(0.7, 0, 0, 34),
	Text = "",
	TextColor3 = THEME.Yellow,
	TextStrokeColor3 = Color3.fromRGB(60, 40, 10),
})

-- Compteurs en haut à droite : objets rangés et panier.
local function counter(name, y, icon)
	local holder = make("Frame", { Name = name, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, y), Size = UDim2.new(0, 300, 0, 64), Parent = screenGui })
	local text = outlined(holder, { Name = "Value", Position = UDim2.new(0, 0, 0, 10), Size = UDim2.new(1, -78, 0, 44), Text = "0/0", TextXAlignment = Enum.TextXAlignment.Right })
	outlined(holder, { Name = "Icon", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 70, 0, 64), Text = icon, TextStrokeTransparency = 1 })
	return holder, text
end
hud.PlacedHolder, hud.Placed = counter("PlacedCounter", 70, "🗄️")
hud.BagHolder, hud.Bag = counter("BagCounter", 140, "🧺")

-- Offre limitée "DEAL" (badge rond, compte à rebours).
hud.Deal = make("TextButton", {
	Name = "DealBadge",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -330, 0, 120),
	Size = UDim2.new(0, 120, 0, 120),
	BackgroundColor3 = Color3.fromRGB(255, 236, 180),
	Text = "",
	AutoButtonColor = true,
	Parent = screenGui,
})
addCorner(hud.Deal, UDim.new(1, 0))
addStroke(hud.Deal, Color3.fromRGB(150, 70, 20), 5)
do
	local ribbon = make("Frame", { Name = "Ribbon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.new(0, 96, 0, 30), BackgroundColor3 = Color3.fromRGB(30, 110, 50), Parent = hud.Deal })
	addCorner(ribbon, UDim.new(0, 10))
	addStroke(ribbon, Color3.fromRGB(250, 250, 250), 2)
	outlined(ribbon, { Size = UDim2.fromScale(1, 1), Text = "OFFER", TextStrokeTransparency = 1, Font = FONT_BIG })
	outlined(hud.Deal, { Name = "DealText", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.48, 0), Size = UDim2.new(0.95, 0, 0.36, 0), Text = "DEAL", Font = FONT_BIG, TextColor3 = Color3.fromRGB(70, 170, 255), TextStrokeColor3 = Color3.fromRGB(20, 40, 110) })
	local timerPill = make("Frame", { Name = "TimerPill", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(0, 80, 0, 26), BackgroundColor3 = Color3.fromRGB(150, 30, 30), Parent = hud.Deal })
	addCorner(timerPill, UDim.new(1, 0))
	outlined(timerPill, { Name = "Time", Size = UDim2.fromScale(1, 1), Text = "5:00", TextStrokeTransparency = 1 })
	outlined(hud.Deal, { Name = "Price", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8), Size = UDim2.new(1.5, 0, 0, 24), Text = "Only R$ " .. TidyConfig.GetProduct("Deal").Price .. "!", TextColor3 = Color3.fromRGB(120, 240, 90), TextStrokeColor3 = Color3.fromRGB(20, 60, 10) })
end

-- Points et rang (à gauche, au-dessus des boutons).
hud.PointsPanel = creamPanel(screenGui, { Name = "PointsPanel", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 22, 0.5, -140), Size = UDim2.new(0, 230, 0, 64) })
hud.Points = label(hud.PointsPanel, { Name = "Points", Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -24, 0, 30), Text = "🪙 0", TextXAlignment = Enum.TextXAlignment.Left })
hud.Rank = label(hud.PointsPanel, { Name = "Rank", Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(1, -24, 0, 20), Text = "Intern", TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left })

-- Boutons du menu à gauche (barre dorée à gauche, touche à droite).
local sideButtons = {}
local function sideButton(name, text, key, y)
	local b = make("TextButton", {
		Name = name .. "Button",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.5, y),
		Size = UDim2.new(0, 230, 0, 58),
		BackgroundColor3 = THEME.Cream,
		Text = "",
		AutoButtonColor = true,
		Parent = screenGui,
	})
	addCorner(b, UDim.new(0, 8))
	local stroke = addStroke(b, THEME.CreamDark, 3)
	local bar = make("Frame", { Name = "Bar", Position = UDim2.new(0, 10, 0.15, 0), Size = UDim2.new(0, 5, 0.7, 0), BackgroundColor3 = THEME.Gold, BorderSizePixel = 0, Parent = b })
	addCorner(bar, UDim.new(1, 0))
	label(b, { Name = "Label", Position = UDim2.new(0, 24, 0.12, 0), Size = UDim2.new(1, -90, 0.76, 0), Text = text, TextColor3 = THEME.Brown, TextXAlignment = Enum.TextXAlignment.Left })
	local badge = make("Frame", { Name = "KeyBadge", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 46, 0, 40), BackgroundColor3 = Color3.fromRGB(206, 186, 150), Parent = b })
	addCorner(badge, UDim.new(0, 8))
	label(badge, { Size = UDim2.fromScale(1, 1), Text = if isTouchOnly then "›" else keyName(key), TextColor3 = THEME.White })
	sideButtons[name] = { Button = b, Stroke = stroke }
	return b
end
sideButton("Upgrades", "Upgrades", Enum.KeyCode.G, -64)
sideButton("Shop", "Shop", Enum.KeyCode.F, 6)
sideButton("Quests", "Quests", Enum.KeyCode.J, 76)
sideButton("Settings", "Settings", Enum.KeyCode.R, 146)
-- Contour arc-en-ciel animé sur le bouton de la boutique.
local shopGradient = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 120)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 90, 255)),
	}),
	Parent = sideButtons.Shop.Stroke,
})
sideButtons.Shop.Stroke.Color = THEME.White
sideButtons.Shop.Stroke.Thickness = 4

-- Retour au hall (dans un niveau).
hud.LobbyButton = button(screenGui, { Name = "LobbyButton", Position = UDim2.new(0, 22, 0, 60), Size = UDim2.new(0, 140, 0, 40), Text = "🏠 Lobby", BackgroundColor3 = THEME.Cream, TextColor3 = THEME.Brown })
addStroke(hud.LobbyButton, THEME.Gold, 2)
hud.RoomCode = outlined(screenGui, { Name = "RoomCode", Position = UDim2.new(0, 172, 0, 64), Size = UDim2.new(0, 300, 0, 30), Text = "", TextXAlignment = Enum.TextXAlignment.Left })

-- Zone actuelle, carte de l'objet en main et barre d'outils (en bas au centre).
hud.Area = outlined(screenGui, { Name = "Area", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -128), Size = UDim2.new(0, 520, 0, 30), Text = "" })
hud.ItemCard = creamPanel(screenGui, { Name = "ItemCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -164), Size = UDim2.new(0, 400, 0, 120) })
hud.ItemSection = label(hud.ItemCard, { Name = "Section", Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -32, 0, 30), Text = "", Font = Enum.Font.Merriweather, TextColor3 = THEME.Text })
make("Frame", { Name = "Divider", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 48), Size = UDim2.new(0.8, 0, 0, 2), BackgroundColor3 = THEME.Gold, BorderSizePixel = 0, Parent = hud.ItemCard })
label(hud.ItemCard, { Name = "Star", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 49), Size = UDim2.new(0, 22, 0, 22), Text = "★", TextColor3 = THEME.Gold })
hud.ItemName = label(hud.ItemCard, { Name = "ItemName", Position = UDim2.new(0, 16, 0, 60), Size = UDim2.new(1, -32, 0, 44), Text = "", Font = Enum.Font.Merriweather, TextColor3 = THEME.Dark })
hud.ItemCount = label(hud.ItemCard, { Name = "Count", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.new(0, 70, 0, 22), Text = "", TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Right })

hud.Hotbar = make("Frame", { Name = "Hotbar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(0, 4 * 112, 0, 112), BackgroundTransparency = 1, Parent = screenGui })
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), Parent = hud.Hotbar })
local TOOLS = {
	{ Id = "Hand", Key = Enum.KeyCode.One, Number = 1, Icon = "🖐️", Name = "Hand" },
	{ Id = "Magnet", Key = Enum.KeyCode.Two, Number = 2, Icon = "🧲", Name = "Magnet" },
	{ Id = "Magnifier", Key = Enum.KeyCode.Three, Number = 3, Icon = "🔍", Name = "Magnifier" },
	{ Id = "QuickStock", Key = Enum.KeyCode.Four, Number = 4, Icon = "🗄️", Name = "Quick Stock" },
}
local toolSlots = {}
for _, tool in TOOLS do
	local slot = make("TextButton", { Name = tool.Id, Size = UDim2.new(0, 100, 0, 104), BackgroundColor3 = THEME.Cream, Text = "", AutoButtonColor = true, Parent = hud.Hotbar })
	addCorner(slot, UDim.new(0, 16))
	local stroke = addStroke(slot, THEME.CreamDark, 3)
	local badge = make("Frame", { Name = "Number", Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(0, 26, 0, 26), BackgroundColor3 = THEME.Orange, Parent = slot })
	addCorner(badge, UDim.new(0, 6))
	label(badge, { Size = UDim2.fromScale(1, 1), Text = tostring(tool.Number), TextColor3 = THEME.White })
	label(slot, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.52, 0), Size = UDim2.new(0.62, 0, 0.62, 0), Text = tool.Icon })
	local lock = label(slot, { Name = "Lock", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -4), Size = UDim2.new(0, 30, 0, 30), Text = "🔒" })
	toolSlots[tool.Id] = { Button = slot, Stroke = stroke, Lock = lock }
end

-- Boutons tactiles (mobile) : objet précédent / suivant et lâcher.
hud.TouchBar = make("Frame", { Name = "TouchBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -292), Size = UDim2.new(0, 300, 0, 50), BackgroundTransparency = 1, Visible = isTouchOnly, Parent = screenGui })
hud.PrevButton = button(hud.TouchBar, { Name = "Prev", Size = UDim2.new(0, 60, 1, 0), Text = "<", BackgroundColor3 = THEME.Cream, TextColor3 = THEME.Brown })
hud.DropButton = button(hud.TouchBar, { Name = "Drop", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 140, 1, 0), Text = "Drop", BackgroundColor3 = THEME.Red })
hud.NextButton = button(hud.TouchBar, { Name = "Next", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 60, 1, 0), Text = ">", BackgroundColor3 = THEME.Cream, TextColor3 = THEME.Brown })

-- Aide des commandes (en bas à droite, ordinateur seulement).
hud.Controls = outlined(screenGui, {
	Name = "Controls",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -110),
	Size = UDim2.new(0, 300, 0, 150),
	Text = "Controls:\nDrop item: " .. keyName(Enum.KeyCode.Q) .. "\nCycle: Mouse wheel\nFree mouse: " .. keyName(Enum.KeyCode.Y),
	Visible = not isTouchOnly,
})

-- Viseur, texte de visée, message temporaire.
hud.Crosshair = make("Frame", { Name = "Crosshair", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 8, 0, 8), BackgroundColor3 = THEME.White, Visible = false, Parent = screenGui })
addCorner(hud.Crosshair, UDim.new(1, 0))
addStroke(hud.Crosshair, THEME.Dark, 1.5)
hud.Aim = outlined(screenGui, { Name = "Aim", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 18), Size = UDim2.new(0, 520, 0, 26), Text = "" })
hud.Toast = outlined(screenGui, { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.36, 0), Size = UDim2.new(0.6, 0, 0, 34), Text = "", TextTransparency = 1, TextStrokeTransparency = 1 })

-- Bandeau du hall et barre de la file d'attente.
hud.Banner = outlined(screenGui, { Name = "Banner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.new(0.7, 0, 0, 40), Text = "", Font = FONT_BIG, TextColor3 = THEME.Yellow })
hud.QueueBar = creamPanel(screenGui, { Name = "QueueBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.new(0, 520, 0, 70), Visible = false })
hud.QueueText = label(hud.QueueBar, { Name = "Text", Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -170, 1, -20), Text = "", TextXAlignment = Enum.TextXAlignment.Left })
hud.QueueLeave = button(hud.QueueBar, { Name = "Leave", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 130, 0, 46), Text = "Leave", BackgroundColor3 = THEME.Red })

---------------------------------------------------------------------------
-- Fenêtres (cartes crème avec titre et bouton fermer)
---------------------------------------------------------------------------
local panels = {}
local function makeWindow(name, title, size)
	local window = creamPanel(screenGui, { Name = name .. "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size, Visible = false, ZIndex = 5 })
	local header = make("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = THEME.Gold, BorderSizePixel = 0, ZIndex = 5, Parent = window })
	addCorner(header, UDim.new(0, 14))
	make("Frame", { Name = "HeaderFill", Position = UDim2.new(0, 0, 1, -14), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = THEME.Gold, BorderSizePixel = 0, ZIndex = 5, Parent = header })
	outlined(header, { Name = "Title", Position = UDim2.new(0, 20, 0, 6), Size = UDim2.new(1, -90, 1, -12), Text = title, Font = FONT_BIG, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeColor3 = THEME.GoldDark, ZIndex = 6 })
	local close = button(header, { Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 44, 0, 40), Text = "X", BackgroundColor3 = THEME.Red, ZIndex = 6 })
	close.Activated:Connect(function()
		window.Visible = false
	end)
	panels[name] = window
	return window
end

local function closeAllWindows(except)
	for name, window in panels do
		if name ~= except then
			window.Visible = false
		end
	end
end

local function toggleWindow(name)
	local window = panels[name]
	local show = not window.Visible
	closeAllWindows()
	window.Visible = show
	return show
end

---------------------------------------------------------------------------
-- Musique d'ambiance et réglages
---------------------------------------------------------------------------
local settings = { Music = TidyConfig.MusicVolume, Sfx = true, Tutorial = true, Controls = true, LowGraphics = false }
local musicMuted = false
local musicSound = nil
if TidyConfig.MusicSoundId ~= "" then
	musicSound = make("Sound", { Name = "ChillMusic", SoundId = TidyConfig.MusicSoundId, Looped = true, Volume = settings.Music, Parent = SoundService })
	musicSound:Play()
end

local function applySettings()
	if musicSound then
		musicSound.Volume = if musicMuted then 0 else settings.Music
	end
	hud.Controls.Visible = settings.Controls and not isTouchOnly and player:GetAttribute("InMap") == true
	Lighting.GlobalShadows = not settings.LowGraphics
	local bloom = Lighting:FindFirstChild("AgencyBloom")
	if bloom then
		bloom.Enabled = not settings.LowGraphics
	end
end

local function sendSettings()
	settingsEvent:FireServer(settings)
end

---------------------------------------------------------------------------
-- Messages, points qui montent, effets de rangement
---------------------------------------------------------------------------
local toastToken = 0
local function showToast(text, kind)
	if type(text) ~= "string" or text == "" then
		return
	end
	toastToken += 1
	local token = toastToken
	hud.Toast.Text = text
	hud.Toast.TextColor3 = if kind == "error" then Color3.fromRGB(255, 110, 100) elseif kind == "room" or kind == "quest" or kind == "purchase" then Color3.fromRGB(140, 255, 140) else THEME.White
	hud.Toast.TextTransparency = 0
	hud.Toast.TextStrokeTransparency = 0
	task.delay(if kind == "room" or kind == "quest" then 3 else 1.8, function()
		if token == toastToken then
			TweenService:Create(hud.Toast, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- "+12" doré qui monte près du viseur.
local function popPoints(text)
	local offset = math.random(-30, 30)
	local pop = outlined(screenGui, { Name = "PointsPop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, offset, 0.46, 0), Size = UDim2.new(0, 160, 0, 40), Text = text, Font = FONT_BIG, TextColor3 = THEME.Yellow, TextStrokeColor3 = Color3.fromRGB(110, 70, 10) })
	TweenService:Create(pop, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, offset, 0.38, 0), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(pop, 0.9)
end

local function celebrate(position, strength)
	if typeof(position) ~= "Vector3" then
		return
	end
	local holder = make("Part", { Name = "TidySparkle", Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Parent = Workspace })
	if not settings.LowGraphics then
		local emitter = make("ParticleEmitter", {
			Name = "Sparkles",
			Rate = 0,
			Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(80, 80),
			Color = ColorSequence.new(Color3.fromRGB(255, 230, 120)),
			Transparency = NumberSequence.new(0.2),
			Size = NumberSequence.new(0.3),
			LightEmission = 0.6,
			Parent = holder,
		})
		emitter:Emit(strength or 10)
	end
	if settings.Sfx then
		local sound = make("Sound", { Name = "PlaceSound", SoundId = TidyConfig.PlaceSoundId, Volume = 0.25, PlaybackSpeed = 0.95 + math.random() * 0.25, Parent = holder })
		sound:Play()
	end
	Debris:AddItem(holder, 1.5)
end

-- L'objet glisse de la main jusqu'à sa place (effet local, très court).
local function animatePlacement(item, fromCFrame)
	if typeof(item) ~= "Instance" or not item:IsA("Model") or typeof(fromCFrame) ~= "CFrame" or not item.PrimaryPart then
		return
	end
	local target = item:GetPivot()
	local driver = Instance.new("CFrameValue")
	driver.Value = fromCFrame
	item:PivotTo(fromCFrame)
	local connection = driver.Changed:Connect(function(value)
		if item.Parent then
			item:PivotTo(value)
		end
	end)
	local tween = TweenService:Create(driver, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target })
	tween.Completed:Connect(function()
		connection:Disconnect()
		if item.Parent then
			item:PivotTo(target)
		end
		driver:Destroy()
	end)
	tween:Play()
end

---------------------------------------------------------------------------
-- Tutoriel : 6 cartes à l'entrée d'un niveau (images 3D faites de pièces)
---------------------------------------------------------------------------
local tutorial = make("Frame", { Name = "Tutorial", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.55, 0), Size = UDim2.new(0, 780, 0, 600), BackgroundTransparency = 1, Visible = false, ZIndex = 8, Parent = screenGui })
outlined(tutorial, { Name = "Title", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.new(1, 0, 0, 40), Text = if isTouchOnly then "Tap to pick up an item" else "Click to pick up an item", TextColor3 = THEME.Yellow, TextStrokeColor3 = Color3.fromRGB(60, 40, 10), ZIndex = 8 })

local function viewportScene(parent, build, cameraCFrame)
	local viewport = make("ViewportFrame", { Name = "Picture", Position = UDim2.new(0, 10, 0, 50), Size = UDim2.new(1, -20, 0, 140), BackgroundColor3 = Color3.fromRGB(196, 226, 246), Ambient = Color3.fromRGB(200, 200, 200), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-1, -2, -1), ZIndex = 9, Parent = parent })
	addCorner(viewport, UDim.new(0, 8))
	local camera = make("Camera", { CFrame = cameraCFrame, FieldOfView = 50, Parent = viewport })
	viewport.CurrentCamera = camera
	local function part(size, position, color, shape, material)
		local p = make("Part", { Anchored = true, Size = size, CFrame = if typeof(position) == "CFrame" then position else CFrame.new(position), Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = viewport })
		if shape then
			p.Shape = shape
		end
		return p
	end
	build(part)
	return viewport
end

local FLOOR_COLOR = Color3.fromRGB(240, 228, 206)
local CARD_SCENES = {
	function(part)
		part(Vector3.new(14, 0.4, 10), Vector3.new(0, -0.2, 0), FLOOR_COLOR)
		local colors = { Color3.fromRGB(232, 70, 60), Color3.fromRGB(46, 120, 226), Color3.fromRGB(250, 196, 40), Color3.fromRGB(60, 180, 96), Color3.fromRGB(240, 130, 40), Color3.fromRGB(160, 90, 210) }
		for i = 1, 12 do
			local x, z = math.cos(i * 1.7) * 4.5, math.sin(i * 2.3) * 3
			if i % 3 == 0 then
				part(Vector3.new(0.9, 0.9, 0.9), Vector3.new(x, 0.45, z), colors[i % 6 + 1], Enum.PartType.Ball)
			else
				part(Vector3.new(1.1, 0.5, 0.8), CFrame.new(x, 0.25, z) * CFrame.Angles(0, i, 0), colors[i % 6 + 1])
			end
		end
	end,
	function(part)
		part(Vector3.new(14, 0.4, 10), Vector3.new(0, -0.2, 0), FLOOR_COLOR)
		part(Vector3.new(7, 1.8, 0.3), Vector3.new(0, 5.2, 0), Color3.fromRGB(38, 138, 168))
		part(Vector3.new(7.3, 2.1, 0.2), Vector3.new(0, 5.2, -0.1), Color3.fromRGB(255, 255, 255))
		for _, x in { -3, 3 } do
			part(Vector3.new(0.1, 2, 0.1), Vector3.new(x, 7, 0), Color3.fromRGB(60, 60, 60))
		end
		part(Vector3.new(8, 3, 1.4), Vector3.new(0, 1.5, -2), Color3.fromRGB(214, 180, 130))
		part(Vector3.new(0.8, 0.8, 0.8), Vector3.new(-1, 0.4, 2), Color3.fromRGB(240, 170, 190), Enum.PartType.Ball)
	end,
	function(part)
		part(Vector3.new(14, 0.4, 10), Vector3.new(0, -0.2, 0), FLOOR_COLOR)
		for _, y in { 0.3, 2.3, 4.3 } do
			part(Vector3.new(8, 0.2, 2), Vector3.new(0, y, 0), Color3.fromRGB(214, 180, 130))
		end
		for _, x in { -4, 4 } do
			part(Vector3.new(0.3, 5, 0.3), Vector3.new(x, 2.5, 0.9), Color3.fromRGB(40, 96, 176))
		end
		local colors = { Color3.fromRGB(240, 120, 40), Color3.fromRGB(40, 110, 220), Color3.fromRGB(220, 50, 50), Color3.fromRGB(60, 170, 100) }
		for row, y in { 0.9, 2.9 } do
			for i = 0, 4 do
				part(Vector3.new(1.3, 1, 1), Vector3.new(-3 + i * 1.5, y, 0), colors[(i + row) % 4 + 1])
			end
		end
	end,
	function(part)
		part(Vector3.new(14, 0.4, 10), Vector3.new(0, -0.2, 0), FLOOR_COLOR)
		for i = 0, 5 do
			part(Vector3.new(0.35, 2, 2), CFrame.new(-1.5, 0.2 + i * 0.36, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(250, 196, 50), Enum.PartType.Cylinder, Enum.Material.Metal)
		end
		part(Vector3.new(0.35, 2, 2), CFrame.new(1.4, 1, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(250, 196, 50), Enum.PartType.Cylinder, Enum.Material.Metal)
		part(Vector3.new(2.2, 1.2, 1.2), Vector3.new(3.5, 0.6, 1), Color3.fromRGB(206, 158, 100))
	end,
	function(part)
		part(Vector3.new(14, 0.4, 10), Vector3.new(0, -0.2, 0), FLOOR_COLOR)
		part(Vector3.new(3, 0.8, 0.8), Vector3.new(-1.5, 0.4, 0), Color3.fromRGB(220, 50, 50))
		for _, x in { -2.6, -0.4 } do
			part(Vector3.new(0.8, 2.4, 0.8), Vector3.new(x, 1.6, 0), Color3.fromRGB(220, 50, 50))
			part(Vector3.new(0.85, 0.6, 0.85), Vector3.new(x, 3.1, 0), Color3.fromRGB(210, 214, 222), nil, Enum.Material.Metal)
		end
		part(Vector3.new(2.6, 1.6, 2.6), CFrame.new(3, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(80, 170, 240), Enum.PartType.Cylinder)
	end,
	function(part)
		part(Vector3.new(14, 0.4, 10), Vector3.new(0, -0.2, 0), FLOOR_COLOR)
		local colors = { Color3.fromRGB(232, 70, 60), Color3.fromRGB(46, 120, 226), Color3.fromRGB(250, 196, 40), Color3.fromRGB(60, 180, 96) }
		for _, x in { -3.5, 3.5 } do
			for _, y in { 0.3, 2.3, 4.3 } do
				part(Vector3.new(5, 0.2, 2), Vector3.new(x, y, -1), Color3.fromRGB(214, 180, 130))
				if y < 4 then
					for i = 0, 3 do
						part(Vector3.new(1, 1.2, 1), Vector3.new(x - 1.7 + i * 1.15, y + 0.7, -1), colors[i + 1])
					end
				end
			end
		end
	end,
}
local CARD_TEXTS = {
	{ "Pick up an item", "Click an item on the floor to put it in your basket." },
	{ "Check the signs", "Hanging signs show where each kind of item goes." },
	{ "Fill the shelves", "Put each item on the matching shelf. Colored labels must match!" },
	{ "EARN POINTS", "Every item gives points. A spotless room = bonus!" },
	{ "BUY UPGRADES", "Bigger basket, faster shoes, magnet... Use your points!" },
	{ "Tidy everything", "Put everything away to win the level. New areas open as you earn points." },
}
local CARD_OVERLAYS = { "", "TOYS", "", "+10", "⬆", "★" }
for index, texts in CARD_TEXTS do
	local column = (index - 1) % 3
	local row = (index - 1) // 3
	local card = make("Frame", {
		Name = "Card" .. index,
		Position = UDim2.new(0, column * 262, 0, row * 300),
		Size = UDim2.new(0, 244, 0, 284),
		Rotation = ({ -2, 1, 2, -1, 1, -2 })[index],
		BackgroundColor3 = Color3.fromRGB(252, 250, 244),
		ZIndex = 8,
		Parent = tutorial,
	})
	addCorner(card, UDim.new(0, 6))
	addStroke(card, Color3.fromRGB(206, 160, 70), 5)
	local badge = make("Frame", { Name = "Number", Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(0, 34, 0, 32), BackgroundColor3 = THEME.Red, ZIndex = 9, Parent = card })
	addCorner(badge, UDim.new(0, 6))
	label(badge, { Size = UDim2.fromScale(1, 1), Text = tostring(index), TextColor3 = THEME.White, Font = FONT_BIG, ZIndex = 10 })
	label(card, { Name = "Title", Position = UDim2.new(0, 52, 0, 8), Size = UDim2.new(1, -60, 0, 36), Text = texts[1], Font = Enum.Font.GothamBlack, TextColor3 = THEME.Dark, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9 })
	local viewport = viewportScene(card, CARD_SCENES[index], CFrame.lookAt(Vector3.new(0, 7, 11), Vector3.new(0, 1.5, 0)))
	if CARD_OVERLAYS[index] ~= "" then
		outlined(viewport, { Name = "Overlay", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, if index == 2 then 18 else 30), Size = UDim2.new(0.6, 0, 0, 44), Text = CARD_OVERLAYS[index], Font = FONT_BIG, TextColor3 = if index == 2 then THEME.White else THEME.Yellow, ZIndex = 10 })
	end
	label(card, { Name = "Caption", Position = UDim2.new(0, 12, 0, 198), Size = UDim2.new(1, -24, 0, 76), Text = texts[2], Font = Enum.Font.GothamMedium, TextColor3 = THEME.Dark, TextWrapped = true, ZIndex = 9 })
end
local tutorialGo = button(tutorial, { Name = "Go", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.new(0, 240, 0, 54), Text = "Let's go!", Font = FONT_BIG, ZIndex = 9 })
addStroke(tutorialGo, THEME.GreenDark, 3)
local tutorialHide = make("TextButton", { Name = "DontShow", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 1, 18), Size = UDim2.new(0, 220, 0, 28), BackgroundTransparency = 1, Text = "Don't show again", Font = FONT, TextScaled = true, TextColor3 = THEME.White, TextStrokeTransparency = 0, ZIndex = 9, Parent = tutorial })

---------------------------------------------------------------------------
-- Fenêtre des améliorations
---------------------------------------------------------------------------
local upgradesWindow = makeWindow("Upgrades", "UPGRADES", UDim2.new(0, 560, 0, 520))
local upgradesPoints = label(upgradesWindow, { Name = "Points", Position = UDim2.new(0, 20, 0, 64), Size = UDim2.new(1, -40, 0, 30), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
local upgradeRows = {}
for i, upgrade in TidyConfig.Upgrades do
	local row = make("Frame", { Name = upgrade.Id, Position = UDim2.new(0, 16, 0, 100 + (i - 1) * 82), Size = UDim2.new(1, -32, 0, 74), BackgroundColor3 = THEME.White, ZIndex = 6, Parent = upgradesWindow })
	addCorner(row, UDim.new(0, 10))
	addStroke(row, THEME.CreamDark, 2)
	label(row, { Name = "Icon", Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(0, 58, 0, 58), Text = upgrade.Icon, ZIndex = 7 })
	label(row, { Name = "Name", Position = UDim2.new(0, 74, 0, 6), Size = UDim2.new(1, -250, 0, 28), Text = upgrade.Name, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 })
	local desc = label(row, { Name = "Desc", Position = UDim2.new(0, 74, 0, 36), Size = UDim2.new(1, -250, 0, 30), Text = upgrade.Description, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamMedium, ZIndex = 7 })
	local buy = button(row, { Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 160, 0, 52), Text = "", ZIndex = 7 })
	upgradeRows[upgrade.Id] = { Buy = buy, Desc = desc, Upgrade = upgrade }
end

---------------------------------------------------------------------------
-- Boutique Robux
---------------------------------------------------------------------------
local shopWindow = makeWindow("Shop", "SHOP", UDim2.new(0, 760, 0, 560))
local shopTabs = {}
local shopPages = {}
for i, tab in { { "Passes", "⭐ Game Passes" }, { "Products", "🪙 Points & Boosts" } } do
	local tabButton = button(shopWindow, { Name = tab[1] .. "Tab", Position = UDim2.new(0, 16 + (i - 1) * 230, 0, 68), Size = UDim2.new(0, 220, 0, 42), Text = tab[2], BackgroundColor3 = THEME.CreamDark, TextColor3 = THEME.Brown, ZIndex = 6 })
	shopTabs[tab[1]] = tabButton
	local page = make("ScrollingFrame", { Name = tab[1] .. "Page", Position = UDim2.new(0, 16, 0, 120), Size = UDim2.new(1, -32, 1, -136), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = i == 1, ZIndex = 6, Parent = shopWindow })
	make("UIGridLayout", { CellSize = UDim2.new(0, 232, 0, 196), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
	shopPages[tab[1]] = page
end
local shopTiles = {}
local function shopTile(page, kind, entry, order)
	local tile = make("Frame", { Name = entry.Id, LayoutOrder = order, BackgroundColor3 = THEME.White, ZIndex = 7, Parent = page })
	addCorner(tile, UDim.new(0, 12))
	addStroke(tile, if entry.Best then THEME.Orange else THEME.CreamDark, if entry.Best then 3 else 2)
	label(tile, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0, 64, 0, 56), Text = entry.Icon, ZIndex = 8 })
	label(tile, { Name = "Name", Position = UDim2.new(0, 8, 0, 62), Size = UDim2.new(1, -16, 0, 28), Text = entry.Name, ZIndex = 8 })
	label(tile, { Name = "Desc", Position = UDim2.new(0, 10, 0, 92), Size = UDim2.new(1, -20, 0, 44), Text = entry.Description, TextWrapped = true, Font = Enum.Font.GothamMedium, TextColor3 = THEME.Muted, ZIndex = 8 })
	if entry.Best then
		local ribbon = make("Frame", { Name = "Best", Position = UDim2.new(0, -6, 0, 8), Size = UDim2.new(0, 92, 0, 24), BackgroundColor3 = THEME.Orange, Rotation = -8, ZIndex = 9, Parent = tile })
		addCorner(ribbon, UDim.new(0, 6))
		label(ribbon, { Size = UDim2.fromScale(1, 1), Text = "BEST!", TextColor3 = THEME.White, ZIndex = 10 })
	end
	local buy = button(tile, { Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -24, 0, 44), Text = "R$ " .. entry.Price, Font = FONT_BIG, ZIndex = 8 })
	addStroke(buy, THEME.GreenDark, 2)
	buy.Activated:Connect(function()
		local ok, message = shopFunction:InvokeServer(kind, entry.Id)
		if message and message ~= "" then
			showToast(message, if ok then "purchase" else "error")
		end
	end)
	shopTiles[kind .. entry.Id] = { Buy = buy, Entry = entry, Kind = kind }
end
for i, pass in TidyConfig.GamePasses do
	shopTile(shopPages.Passes, "Pass", pass, i)
end
for i, product in TidyConfig.Products do
	shopTile(shopPages.Products, "Product", product, i)
end
local function showShopTab(name)
	for tabName, page in shopPages do
		page.Visible = tabName == name
		shopTabs[tabName].BackgroundColor3 = if tabName == name then THEME.Gold else THEME.CreamDark
		shopTabs[tabName].TextColor3 = if tabName == name then THEME.White else THEME.Brown
	end
end
for tabName, tabButton in shopTabs do
	tabButton.Activated:Connect(function()
		showShopTab(tabName)
	end)
end
showShopTab("Passes")

---------------------------------------------------------------------------
-- Quêtes du jour
---------------------------------------------------------------------------
local questsWindow = makeWindow("Quests", "DAILY QUESTS", UDim2.new(0, 560, 0, 400))
local questRows = {}
for i = 1, TidyConfig.QuestsPerDay do
	local row = make("Frame", { Name = "Quest" .. i, Position = UDim2.new(0, 16, 0, 70 + (i - 1) * 96), Size = UDim2.new(1, -32, 0, 86), BackgroundColor3 = THEME.White, ZIndex = 6, Parent = questsWindow })
	addCorner(row, UDim.new(0, 10))
	addStroke(row, THEME.CreamDark, 2)
	local text = label(row, { Name = "Text", Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -150, 0, 30), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 })
	local reward = label(row, { Name = "Reward", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.new(0, 130, 0, 30), Text = "", TextColor3 = THEME.GoldDark, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7 })
	local bar = make("Frame", { Name = "Bar", Position = UDim2.new(0, 14, 0, 50), Size = UDim2.new(1, -28, 0, 22), BackgroundColor3 = THEME.CreamDark, ZIndex = 7, Parent = row })
	addCorner(bar, UDim.new(1, 0))
	local fill = make("Frame", { Name = "Fill", Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = THEME.Green, ZIndex = 8, Parent = bar })
	addCorner(fill, UDim.new(1, 0))
	local progress = label(bar, { Name = "Progress", Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = THEME.Dark, ZIndex = 9 })
	questRows[i] = { Row = row, Text = text, Reward = reward, Fill = fill, Progress = progress }
end
label(questsWindow, { Name = "Footer", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -40, 0, 24), Text = "New quests every day. Rewards are given automatically!", TextColor3 = THEME.Muted, Font = Enum.Font.GothamMedium, ZIndex = 6 })

---------------------------------------------------------------------------
-- Paramètres
---------------------------------------------------------------------------
local settingsWindow = makeWindow("Settings", "SETTINGS", UDim2.new(0, 520, 0, 480))
local settingsRows = {}
local function settingsRow(index, text)
	local row = make("Frame", { Name = "Row" .. index, Position = UDim2.new(0, 16, 0, 70 + (index - 1) * 66), Size = UDim2.new(1, -32, 0, 56), BackgroundColor3 = THEME.White, ZIndex = 6, Parent = settingsWindow })
	addCorner(row, UDim.new(0, 10))
	label(row, { Name = "Label", Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(0.55, 0, 1, -20), Text = text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 })
	return row
end
local function musicText()
	return if musicSound then (math.floor(settings.Music * 100 + 0.5) .. "%") else "not set"
end
do
	local row = settingsRow(1, "🎵 Music volume")
	local minus = button(row, { Name = "Minus", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.new(0, 44, 0, 40), Text = "-", BackgroundColor3 = THEME.Gold, ZIndex = 7 })
	local value = label(row, { Name = "Value", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -62, 0.5, 0), Size = UDim2.new(0, 84, 0, 34), Text = "", ZIndex = 7 })
	local plus = button(row, { Name = "Plus", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 44, 0, 40), Text = "+", BackgroundColor3 = THEME.Gold, ZIndex = 7 })
	settingsRows.Music = value
	local function change(delta)
		settings.Music = math.clamp(math.floor(settings.Music * 10 + 0.5) / 10 + delta, 0, 1)
		applySettings()
		sendSettings()
		value.Text = musicText()
	end
	minus.Activated:Connect(function()
		change(-0.1)
	end)
	plus.Activated:Connect(function()
		change(0.1)
	end)
end
local function toggleRow(index, text, key)
	local row = settingsRow(index, text)
	local toggle = button(row, { Name = "Toggle", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 110, 0, 40), Text = "", ZIndex = 7 })
	settingsRows[key] = toggle
	toggle.Activated:Connect(function()
		settings[key] = not settings[key]
		applySettings()
		sendSettings()
		toggle.Text = if settings[key] then "ON" else "OFF"
		toggle.BackgroundColor3 = if settings[key] then THEME.Green else THEME.Locked
	end)
end
toggleRow(2, "🔊 Sound effects", "Sfx")
toggleRow(3, "⌨️ Show controls", "Controls")
toggleRow(4, "📖 Tutorial at level start", "Tutorial")
toggleRow(5, "⚡ Low graphics (faster)", "LowGraphics")
local settingsLobby = button(settingsWindow, { Name = "BackToLobby", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(0, 260, 0, 46), Text = "🏠 Back to lobby", BackgroundColor3 = THEME.Blue, ZIndex = 6 })

local function refreshSettingsUI()
	settingsRows.Music.Text = musicText()
	for _, key in { "Sfx", "Controls", "Tutorial", "LowGraphics" } do
		local toggle = settingsRows[key]
		toggle.Text = if settings[key] then "ON" else "OFF"
		toggle.BackgroundColor3 = if settings[key] then THEME.Green else THEME.Locked
	end
end

---------------------------------------------------------------------------
-- Fin de niveau
---------------------------------------------------------------------------
local completeWindow = makeWindow("Complete", "LEVEL COMPLETE!", UDim2.new(0, 520, 0, 340))
local completeText = label(completeWindow, { Name = "Text", Position = UDim2.new(0, 24, 0, 74), Size = UDim2.new(1, -48, 0, 150), Text = "", TextWrapped = true, ZIndex = 6 })
local replayButton = button(completeWindow, { Name = "Replay", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -20), Size = UDim2.new(0.5, -36, 0, 56), Text = "Play again", Font = FONT_BIG, ZIndex = 6 })
local completeLobby = button(completeWindow, { Name = "Lobby", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -20), Size = UDim2.new(0.5, -36, 0, 56), Text = "Back to lobby", BackgroundColor3 = THEME.Blue, Font = FONT_BIG, ZIndex = 6 })

---------------------------------------------------------------------------
-- Choix du niveau (file d'attente du hall)
---------------------------------------------------------------------------
local mapsWindow = makeWindow("Maps", "MAPS", UDim2.new(0, 800, 0, 520))
local selectedMap = "Agency"
local selectedSize = 1
local mapCards = {}
for i, map in TidyConfig.Maps do
	local card = make("TextButton", { Name = map.Id, Position = UDim2.new(0, 16 + (i - 1) * 258, 0, 70), Size = UDim2.new(0, 248, 0, 300), BackgroundColor3 = THEME.White, Text = "", AutoButtonColor = true, ZIndex = 6, Parent = mapsWindow })
	addCorner(card, UDim.new(0, 12))
	local stroke = addStroke(card, THEME.CreamDark, 3)
	local picture = make("Frame", { Name = "Picture", Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(1, -16, 0, 150), BackgroundColor3 = map.Color, ZIndex = 7, Parent = card })
	addCorner(picture, UDim.new(0, 10))
	make("UIGradient", { Color = ColorSequence.new(map.Color:Lerp(Color3.new(1, 1, 1), 0.35), map.Color), Rotation = 90, Parent = picture })
	label(picture, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 110, 0, 110), Text = map.Icon, ZIndex = 8 })
	label(card, { Name = "Name", Position = UDim2.new(0, 10, 0, 164), Size = UDim2.new(1, -20, 0, 32), Text = map.Name, ZIndex = 7 })
	label(card, { Name = "Desc", Position = UDim2.new(0, 12, 0, 198), Size = UDim2.new(1, -24, 0, 60), Text = map.Description, TextWrapped = true, Font = Enum.Font.GothamMedium, TextColor3 = THEME.Muted, ZIndex = 7 })
	local requirement = label(card, { Name = "Requirement", Position = UDim2.new(0, 10, 1, -36), Size = UDim2.new(1, -20, 0, 28), Text = "", TextColor3 = THEME.GreenDark, ZIndex = 7 })
	local lock = make("Frame", { Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(40, 34, 30), BackgroundTransparency = 0.45, Visible = false, ZIndex = 9, Parent = card })
	addCorner(lock, UDim.new(0, 12))
	outlined(lock, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0.8, 0, 0, 70), Text = "🔒", ZIndex = 10, TextStrokeTransparency = 1 })
	local lockText = outlined(lock, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.58, 0), Size = UDim2.new(0.9, 0, 0, 30), Text = "", ZIndex = 10 })
	mapCards[map.Id] = { Card = card, Stroke = stroke, Lock = lock, LockText = lockText, Requirement = requirement, Map = map }
	card.Activated:Connect(function()
		if (player:GetAttribute("Wins") or 0) < map.WinsRequired then
			showToast("🔒 Needs " .. map.WinsRequired .. " win(s). Finish a level first!", "error")
			return
		end
		selectedMap = map.Id
		queueEvent:FireServer("Configure", selectedMap, selectedSize)
	end)
end
label(mapsWindow, { Name = "PlayersLabel", Position = UDim2.new(0, 20, 1, -126), Size = UDim2.new(0, 120, 0, 36), Text = "Players:", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
local sizeButtons = {}
for size = 1, TidyConfig.MaxPartySize do
	local b = button(mapsWindow, { Name = "Size" .. size, Position = UDim2.new(0, 150 + (size - 1) * 66, 1, -132), Size = UDim2.new(0, 56, 0, 48), Text = tostring(size), BackgroundColor3 = THEME.CreamDark, TextColor3 = THEME.Brown, ZIndex = 6 })
	sizeButtons[size] = b
	b.Activated:Connect(function()
		selectedSize = size
		queueEvent:FireServer("Configure", selectedMap, selectedSize)
	end)
end
local mapsStart = button(mapsWindow, { Name = "Start", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.new(0, 220, 0, 60), Text = "START", Font = FONT_BIG, ZIndex = 6 })
addStroke(mapsStart, THEME.GreenDark, 3)
local mapsLeave = button(mapsWindow, { Name = "Leave", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -20), Size = UDim2.new(0, 160, 0, 48), Text = "Leave", BackgroundColor3 = THEME.Red, ZIndex = 6 })
local mapsStatus = label(mapsWindow, { Name = "Status", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -26), Size = UDim2.new(0, 280, 0, 30), Text = "", TextColor3 = THEME.Muted, ZIndex = 6 })

---------------------------------------------------------------------------
-- Rejoindre un ami avec un code
---------------------------------------------------------------------------
local joinWindow = makeWindow("Join", "JOIN A FRIEND", UDim2.new(0, 460, 0, 280))
label(joinWindow, { Name = "Help", Position = UDim2.new(0, 20, 0, 66), Size = UDim2.new(1, -40, 0, 50), Text = "Ask your friend for the 6-character code shown at the top left of their screen.", TextWrapped = true, Font = Enum.Font.GothamMedium, TextColor3 = THEME.Muted, ZIndex = 6 })
local codeBox = make("TextBox", { Name = "Code", Position = UDim2.new(0, 20, 0, 126), Size = UDim2.new(1, -40, 0, 54), BackgroundColor3 = THEME.White, Text = "", PlaceholderText = "ABC123", Font = FONT_BIG, TextScaled = true, TextColor3 = THEME.Dark, ClearTextOnFocus = false, ZIndex = 6, Parent = joinWindow })
addCorner(codeBox, UDim.new(0, 10))
addStroke(codeBox, THEME.Gold, 2)
local joinButton = button(joinWindow, { Name = "Join", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(0, 220, 0, 52), Text = "JOIN", Font = FONT_BIG, ZIndex = 6 })

---------------------------------------------------------------------------
-- Mise à jour de l'interface
---------------------------------------------------------------------------
local equippedTool = "Hand"
local timerStart, timerStopped = nil, nil
local finished = false
local dealEndsAt = os.clock() + TidyConfig.DealDuration

local function inMap()
	return player:GetAttribute("InMap") == true
end

local function splitList(text, separator)
	local list = {}
	if type(text) ~= "string" or text == "" then
		return list
	end
	for part in string.gmatch(text, "([^" .. separator .. "]+)") do
		table.insert(list, part)
	end
	return list
end

local function heldTypes()
	return splitList(player:GetAttribute("Held"), ",")
end

local function heldCategories()
	return splitList(player:GetAttribute("HeldCategories"), ",")
end

local function toolUnlocked(toolId)
	if toolId == "Hand" then
		return true
	elseif toolId == "Magnet" then
		return player:GetAttribute("MagnetUnlocked") == true
	elseif toolId == "Magnifier" then
		return (player:GetAttribute("Level_Magnifier") or 0) >= 1
	elseif toolId == "QuickStock" then
		return (player:GetAttribute("Level_QuickStock") or 0) >= 1
	end
	return false
end

local function updateTools()
	for _, tool in TOOLS do
		local slot = toolSlots[tool.Id]
		local unlocked = toolUnlocked(tool.Id)
		slot.Lock.Visible = not unlocked
		slot.Button.BackgroundColor3 = if unlocked then THEME.Cream else Color3.fromRGB(232, 222, 204)
		local selected = equippedTool == tool.Id
		slot.Stroke.Color = if selected then THEME.Orange else THEME.CreamDark
		slot.Stroke.Thickness = if selected then 5 else 3
	end
end

local function equipTool(toolId)
	if not toolUnlocked(toolId) then
		local names = { Magnet = "Magnet", Magnifier = "Magnifier", QuickStock = "Quick Stock" }
		showToast("🔒 Unlock the " .. (names[toolId] or toolId) .. " in Upgrades [" .. keyName(Enum.KeyCode.G) .. "].", "error")
		return
	end
	equippedTool = toolId
	updateTools()
end

local function updateCounters()
	local total = ReplicatedStorage:GetAttribute("TidyTotal") or 0
	local remaining = ReplicatedStorage:GetAttribute("TidyRemaining") or 0
	hud.Placed.Text = fmt(total - remaining) .. "/" .. fmt(total)
end

local function updateBag()
	local types = heldTypes()
	local capacity = player:GetAttribute("Capacity") or TidyConfig.BaseCapacity
	hud.Bag.Text = #types .. "/" .. capacity
	local carrying = player:GetAttribute("Carrying") or ""
	local info = TidyConfig.ItemTypes[carrying]
	hud.ItemCard.Visible = info ~= nil and inMap()
	hud.TouchBar.Visible = isTouchOnly and #types > 0 and inMap()
	if info then
		local categoryId = player:GetAttribute("CarryingCategory") or ""
		local category = categoryId ~= "" and TidyConfig.GetCategory(carrying, categoryId)
		hud.ItemSection.Text = info.Section .. (if category then "  •  " .. category.Name else "")
		local name = player:GetAttribute("CarryingName") or ""
		hud.ItemName.Text = if name ~= "" then name else info.DisplayName
		hud.ItemCount.Text = (player:GetAttribute("Selected") or 1) .. " / " .. #types
	end
end

local function updateHint()
	if not inMap() then
		hud.Hint.Text = ""
		return
	end
	if finished then
		hud.Hint.Text = "Everything is spotless!"
		return
	end
	local carrying = player:GetAttribute("Carrying") or ""
	local info = TidyConfig.ItemTypes[carrying]
	local types = heldTypes()
	if info then
		hud.Hint.Text = info.Hint .. " (" .. #types .. "/" .. (player:GetAttribute("Capacity") or 0) .. ")"
	else
		hud.Hint.Text = if isTouchOnly then "Tap to pick up an item" else "Click to pick up an item"
	end
end

local function updatePoints()
	local points = player:GetAttribute("Points") or 0
	hud.Points.Text = "🪙 " .. fmt(points)
	hud.Rank.Text = (player:GetAttribute("Rank") or "Intern") .. "  •  🏆 " .. (player:GetAttribute("Wins") or 0) .. " wins"
	upgradesPoints.Text = "Your points: 🪙 " .. fmt(points)
	for id, row in upgradeRows do
		local levelValue = player:GetAttribute("Level_" .. id) or 0
		local upgrade = row.Upgrade
		if levelValue >= upgrade.MaxLevel then
			row.Buy.Text = "MAX"
			row.Buy.BackgroundColor3 = THEME.Locked
		else
			local cost = TidyConfig.GetUpgradeCost(upgrade, levelValue)
			row.Buy.Text = "🪙 " .. fmt(cost)
			row.Buy.BackgroundColor3 = if points >= cost then THEME.Green else THEME.Orange
		end
		row.Desc.Text = upgrade.Description .. "  (level " .. levelValue .. "/" .. upgrade.MaxLevel .. ")"
	end
	for _, tile in shopTiles do
		local owned = false
		if tile.Kind == "Pass" then
			owned = player:GetAttribute("Pass_" .. tile.Entry.Id) == true
		elseif tile.Entry.OneTime then
			owned = player:GetAttribute("DealBought") == true
		end
		tile.Buy.Text = if owned then "OWNED" else ("R$ " .. tile.Entry.Price)
		tile.Buy.BackgroundColor3 = if owned then THEME.Locked else THEME.Green
		tile.Buy.Active = not owned
	end
end

local function updateQuests()
	local ok, quests = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Quests") or "[]")
	end)
	if not ok or type(quests) ~= "table" then
		return
	end
	for i, row in questRows do
		local quest = quests[i]
		row.Row.Visible = quest ~= nil
		if quest then
			row.Text.Text = (if quest.Done then "✅ " else "📋 ") .. tostring(quest.Text)
			row.Reward.Text = "🪙 " .. fmt(quest.Reward or 0)
			local target = math.max(1, tonumber(quest.Target) or 1)
			local progress = tonumber(quest.Progress) or 0
			row.Fill.Size = UDim2.new(math.clamp(progress / target, 0, 1), 0, 1, 0)
			row.Fill.BackgroundColor3 = if quest.Done then THEME.Gold else THEME.Green
			row.Progress.Text = fmt(progress) .. " / " .. fmt(target)
		end
	end
end

local function updateSettingsFromServer()
	local ok, saved = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Settings") or "{}")
	end)
	if ok and type(saved) == "table" then
		if type(saved.Music) == "number" then
			settings.Music = saved.Music
		end
		for _, key in { "Sfx", "Tutorial", "Controls", "LowGraphics" } do
			if type(saved[key]) == "boolean" then
				settings[key] = saved[key]
			end
		end
	end
	applySettings()
	refreshSettingsUI()
end

---------------------------------------------------------------------------
-- Chronomètre et fin de niveau
---------------------------------------------------------------------------
local function elapsed()
	if not timerStart then
		return 0
	end
	return (timerStopped or os.clock()) - timerStart
end

local function startTimer()
	if not timerStart and inMap() then
		timerStart = os.clock()
	end
end

local function showCompletion(message)
	finished = true
	timerStopped = os.clock()
	closeAllWindows()
	completeText.Text = (message or "Everything is spotless!") .. "\nTime: " .. formatTime(elapsed()) .. "\nTotal wins: 🏆 " .. (player:GetAttribute("Wins") or 0)
	completeWindow.Visible = true
	updateHint()
end

---------------------------------------------------------------------------
-- Effets dans le décor : places lumineuses, meubles en surbrillance, survol, loupe
---------------------------------------------------------------------------
local GHOST_TRANSPARENCY = 0.6
local zoneHighlights = {}

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function refreshWorld()
	local carrying = player:GetAttribute("Carrying") or ""
	local carryingCategory = player:GetAttribute("CarryingCategory") or ""
	for _, slot in CollectionService:GetTagged(TidyConfig.SlotTag) do
		if slot:IsA("BasePart") then
			local slotCategory = slot:GetAttribute("Category")
			local matches = carrying ~= "" and slot:GetAttribute("ItemType") == carrying and slot:GetAttribute("Occupied") ~= true and (slotCategory == nil or slotCategory == carryingCategory)
			slot.Transparency = if matches then GHOST_TRANSPARENCY else 1
		end
	end
	local root = getRoot()
	for _, zone in CollectionService:GetTagged(TidyConfig.ZoneTag) do
		local zoneCategory = zone:GetAttribute("Category")
		local matches = carrying ~= "" and zone:GetAttribute("ItemType") == carrying and (zoneCategory == nil or zoneCategory == carryingCategory)
		local highlight = zoneHighlights[zone]
		if matches and (not highlight or highlight.Parent ~= zone) then
			zoneHighlights[zone] = make("Highlight", { Name = "ZoneHighlight", FillColor = THEME.Green, FillTransparency = 0.85, OutlineColor = Color3.fromRGB(120, 255, 140), OutlineTransparency = 0.1, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = zone })
		elseif not matches and highlight then
			highlight:Destroy()
			zoneHighlights[zone] = nil
		end
		local billboard = zone:FindFirstChild("CategoryBillboard")
		if billboard and billboard:IsA("BillboardGui") then
			local anchor = billboard.Adornee
			local near = root ~= nil and anchor ~= nil and anchor:IsA("BasePart") and (anchor.Position - root.Position).Magnitude < 45
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
	task.delay(0.05, function()
		refreshQueued = false
		refreshWorld()
	end)
end

local hoverHighlight = make("Highlight", { Name = "HoverHighlight", FillTransparency = 1, OutlineColor = THEME.White, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.Occluded, Enabled = false, Parent = Workspace })

-- Repère de la loupe : un rayon lumineux entre le joueur et sa destination.
local guidePart = make("Part", { Name = "TidyGuideTarget", Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Parent = Workspace })
local guideAttachment = make("Attachment", { Name = "GuideEnd", Parent = guidePart })
local guideBeam = make("Beam", { Name = "GuideBeam", Attachment1 = guideAttachment, Color = ColorSequence.new(THEME.Yellow), Transparency = NumberSequence.new(0.2), Width0 = 0.4, Width1 = 0.4, FaceCamera = true, LightEmission = 1, Enabled = false, Parent = guidePart })
local playerAttachment = nil

local function updateGuide()
	local root = getRoot()
	local active = equippedTool == "Magnifier" and toolUnlocked("Magnifier") and root ~= nil and not finished and inMap()
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
			local slotCategory = slot:GetAttribute("Category")
			if slot:GetAttribute("ItemType") == carrying and slot:GetAttribute("Occupied") ~= true and (slotCategory == nil or slotCategory == player:GetAttribute("CarryingCategory")) then
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
-- Visée à la première personne, clic / appui dans le décor
---------------------------------------------------------------------------
local freeMouse = false
local FREE_MOUSE_PRIORITY = Enum.RenderPriority.Camera.Value + 1

local function anyWindowOpen()
	for _, window in panels do
		if window.Visible then
			return true
		end
	end
	return tutorial.Visible
end

local function mouseShouldBeFree()
	return freeMouse or anyWindowOpen() or not inMap()
end

RunService:BindToRenderStep("TidyFreeMouse", FREE_MOUSE_PRIORITY, function()
	if mouseShouldBeFree() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		hud.Crosshair.Visible = false
	else
		hud.Crosshair.Visible = not isTouchOnly
	end
end)

local function aimRay()
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	if mouseShouldBeFree() then
		local mouse = UserInputService:GetMouseLocation()
		return camera:ViewportPointToRay(mouse.X, mouse.Y)
	end
	local size = camera.ViewportSize
	return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
end

-- Trouve ce qui est visé : un objet qui traîne ("item"), une zone de rangement ("zone")
-- ou une porte / clôture verrouillée ("door").
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

local function aimText(kind, target)
	local verb = if isTouchOnly then "Tap" else "Click"
	if kind == "item" then
		return verb .. " to pick up: " .. (target:GetAttribute("ItemName") or "item")
	elseif kind == "door" then
		local room = TidyConfig.GetRoom(target:GetAttribute("Room"))
		return "🔒 " .. (room and room.Name or "Locked") .. " - opens at " .. fmt(room and room.Unlock or 0) .. " points earned"
	elseif kind == "zone" then
		local zoneType = target:GetAttribute("ItemType")
		local info = TidyConfig.ItemTypes[zoneType]
		local zoneCategory = target:GetAttribute("Category")
		local cats = heldCategories()
		for index, itemType in heldTypes() do
			if itemType == zoneType and (zoneCategory == nil or cats[index] == zoneCategory) then
				return verb .. (if equippedTool == "QuickStock" then " to stock ALL: " else " to put away: ") .. (info and info.Plural or "items")
			end
		end
		return (info and info.Icon or "") .. " " .. (target:GetAttribute("ZoneLabel") or "Shelf")
	end
	return ""
end

local function handleClick(ray)
	if finished or not inMap() then
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
		actionEvent:FireServer("door", target)
	else
		actionEvent:FireServer("place", target, equippedTool == "QuickStock")
	end
end

---------------------------------------------------------------------------
-- Modes : hall d'accueil ou niveau
---------------------------------------------------------------------------
local function updateMode()
	local playing = inMap()
	for _, element in { hud.Timer, hud.PlacedHolder, hud.BagHolder, hud.Hotbar, hud.Area, hud.Hint, hud.Aim, hud.LobbyButton } do
		element.Visible = playing
	end
	hud.Controls.Visible = playing and settings.Controls and not isTouchOnly
	if not playing then
		hud.ItemCard.Visible = false
		hud.TouchBar.Visible = false
		tutorial.Visible = false
		completeWindow.Visible = false
		player.CameraMaxZoomDistance = 18
		player.CameraMinZoomDistance = 6
		hoverHighlight.Enabled = false
		guideBeam.Enabled = false
	else
		player.CameraMaxZoomDistance = 0.5
		player.CameraMinZoomDistance = 0.5
	end
	settingsLobby.Visible = playing
	updateBag()
	updateHint()
end

local function showTutorial()
	if settings.Tutorial then
		closeAllWindows()
		tutorial.Visible = true
	end
end

local function hideTutorial()
	tutorial.Visible = false
	startTimer()
end

---------------------------------------------------------------------------
-- File d'attente : fenêtre du chef de groupe, barre des autres joueurs
---------------------------------------------------------------------------
local function findPad(index)
	local hubModel = Workspace:FindFirstChild("TidyHub")
	if not hubModel then
		return nil
	end
	for _, part in hubModel:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("QueueIndex") == index then
			return part
		end
	end
	return nil
end

local function plural(n, word)
	return n .. " " .. word .. (if n > 1 then "s" else "")
end

local mapsShownForPad = 0
local function updateQueueUI()
	local padIndex = player:GetAttribute("QueuePad") or 0
	local isHost = player:GetAttribute("QueueHost") == true
	if padIndex == 0 or inMap() then
		mapsShownForPad = 0
		mapsWindow.Visible = false
		hud.QueueBar.Visible = false
		hud.Banner.Text = if inMap() then "" else "Step on a glowing pad to start a game!"
		return
	end
	local pad = findPad(padIndex)
	local mapId = pad and pad:GetAttribute("QueueMap") or ""
	local count = pad and pad:GetAttribute("QueueCount") or 1
	local size = pad and pad:GetAttribute("QueueSize") or 1
	local countdown = pad and pad:GetAttribute("QueueCountdown") or -1
	local map = TidyConfig.GetMap(mapId)
	local countdownText = if countdown >= 0 then ("  •  Starting in " .. countdown .. "...") else ""
	hud.Banner.Text = ""
	if isHost then
		-- La fenêtre s'ouvre une fois quand on devient chef de groupe (on peut la fermer ensuite).
		if mapsShownForPad ~= padIndex then
			mapsShownForPad = padIndex
			closeAllWindows("Maps")
			mapsWindow.Visible = true
		end
		local wins = player:GetAttribute("Wins") or 0
		for id, card in mapCards do
			card.Lock.Visible = wins < card.Map.WinsRequired
			card.LockText.Text = "Needs " .. plural(card.Map.WinsRequired, "win")
			card.Requirement.Text = if card.Map.WinsRequired == 0 then "Free" else ("🏆 " .. plural(card.Map.WinsRequired, "win"))
			card.Stroke.Color = if id == mapId then THEME.Green else THEME.CreamDark
			card.Stroke.Thickness = if id == mapId then 6 else 3
		end
		for s, b in sizeButtons do
			local active = s == size and map ~= nil
			b.BackgroundColor3 = if active then THEME.Gold else THEME.CreamDark
			b.TextColor3 = if active then THEME.White else THEME.Brown
		end
		mapsStart.BackgroundColor3 = if map then THEME.Green else THEME.Locked
		mapsStatus.Text = if countdown >= 0 then ("Starting in " .. countdown .. "...") elseif map then ("Players " .. count .. "/" .. size) else "Choose a level"
		hud.QueueBar.Visible = not mapsWindow.Visible
		hud.QueueText.Text = (if map then map.Icon .. " " .. map.Name else "Choose a level") .. "  •  " .. count .. "/" .. size .. countdownText
	else
		mapsShownForPad = 0
		mapsWindow.Visible = false
		hud.QueueBar.Visible = true
		hud.QueueText.Text = (if map then map.Icon .. " " .. map.Name else "Waiting for the host...") .. "  •  " .. count .. "/" .. size .. countdownText
	end
end

---------------------------------------------------------------------------
-- Entrées clavier, souris et tactile
---------------------------------------------------------------------------
local function openWindow(name)
	if name == "Shop" then
		showShopTab("Passes")
	end
	toggleWindow(name)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if tutorial.Visible then
			return
		end
		local ray = aimRay()
		if ray then
			handleClick(ray)
		end
	elseif input.KeyCode == Enum.KeyCode.Q then
		actionEvent:FireServer("drop")
	elseif input.KeyCode == Enum.KeyCode.E then
		actionEvent:FireServer("cycle", 1)
	elseif input.KeyCode == Enum.KeyCode.G then
		openWindow("Upgrades")
	elseif input.KeyCode == Enum.KeyCode.F then
		openWindow("Shop")
	elseif input.KeyCode == Enum.KeyCode.J then
		openWindow("Quests")
	elseif input.KeyCode == Enum.KeyCode.R then
		openWindow("Settings")
	elseif input.KeyCode == Enum.KeyCode.Y then
		freeMouse = not freeMouse
	elseif input.KeyCode == Enum.KeyCode.M then
		musicMuted = not musicMuted
		applySettings()
		showToast(if musicMuted then "Music muted" else "Music on", "info")
	elseif input.KeyCode == Enum.KeyCode.Return and tutorial.Visible then
		hideTutorial()
	else
		for _, tool in TOOLS do
			if input.KeyCode == tool.Key and inMap() then
				equipTool(tool.Id)
			end
		end
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseWheel or not inMap() then
		return
	end
	actionEvent:FireServer("cycle", if input.Position.Z > 0 then -1 else 1)
end)

UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
	if gameProcessed or #touchPositions == 0 or tutorial.Visible then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera then
		local position = touchPositions[1]
		handleClick(camera:ScreenPointToRay(position.X, position.Y))
	end
end)

-- Bornes du hall : boutique, vitrines des pass, rejoindre un ami.
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		closeAllWindows("Shop")
		shopWindow.Visible = true
		showShopTab("Passes")
	elseif prompt.Name == "JoinPrompt" then
		closeAllWindows("Join")
		joinWindow.Visible = true
	end
end)

-- Survol : contour blanc sur ce qui peut être cliqué, texte sous le viseur.
local lastHoverCheck = 0
local lastArea = ""
RunService.RenderStepped:Connect(function()
	if inMap() and timerStart then
		hud.Timer.Text = formatTime(elapsed())
	end
	-- Compte à rebours de l'offre limitée.
	local dealLeft = dealEndsAt - os.clock()
	hud.Deal.Visible = dealLeft > 0 and player:GetAttribute("DealBought") ~= true and not anyWindowOpen()
	if hud.Deal.Visible then
		hud.Deal.TimerPill.Time.Text = string.format("%d:%02d", dealLeft // 60, math.floor(dealLeft % 60))
	end
	shopGradient.Rotation = (os.clock() * 90) % 360
	local now = os.clock()
	if now - lastHoverCheck < 0.05 or not inMap() then
		return
	end
	lastHoverCheck = now
	local ray = aimRay()
	local result = ray and raycastRay(ray)
	local kind, target = nil, nil
	if result then
		kind, target = resolveTarget(result.Instance)
	end
	local root = getRoot()
	if kind and root and (result.Position - root.Position).Magnitude <= TidyConfig.ReachDistance + 2 then
		hoverHighlight.Adornee = target
		hoverHighlight.Enabled = true
		hud.Aim.Text = aimText(kind, target)
	else
		hoverHighlight.Enabled = false
		hud.Aim.Text = ""
	end
	if root then
		local room = TidyConfig.GetRoomAt(root.Position)
		local text = if room then ("You are in: " .. room.Name) else ""
		if text ~= lastArea then
			lastArea = text
			hud.Area.Text = text
		end
	end
end)

---------------------------------------------------------------------------
-- Boutons
---------------------------------------------------------------------------
sideButtons.Upgrades.Button.Activated:Connect(function()
	openWindow("Upgrades")
end)
sideButtons.Shop.Button.Activated:Connect(function()
	openWindow("Shop")
end)
sideButtons.Quests.Button.Activated:Connect(function()
	openWindow("Quests")
end)
sideButtons.Settings.Button.Activated:Connect(function()
	openWindow("Settings")
end)
hud.Deal.Activated:Connect(function()
	closeAllWindows("Shop")
	shopWindow.Visible = true
	showShopTab("Products")
end)
for _, tool in TOOLS do
	toolSlots[tool.Id].Button.Activated:Connect(function()
		equipTool(tool.Id)
	end)
end
for id, row in upgradeRows do
	row.Buy.Activated:Connect(function()
		local ok, message = upgradeFunction:InvokeServer(id)
		showToast(message, if ok then "room" else "error")
		updateTools()
	end)
end
hud.PrevButton.Activated:Connect(function()
	actionEvent:FireServer("cycle", -1)
end)
hud.NextButton.Activated:Connect(function()
	actionEvent:FireServer("cycle", 1)
end)
hud.DropButton.Activated:Connect(function()
	actionEvent:FireServer("drop")
end)
tutorialGo.Activated:Connect(hideTutorial)
tutorialHide.Activated:Connect(function()
	settings.Tutorial = false
	sendSettings()
	refreshSettingsUI()
	hideTutorial()
end)
replayButton.Activated:Connect(function()
	completeWindow.Visible = false
	actionEvent:FireServer("restart")
end)
local function backToLobby()
	closeAllWindows()
	lobbyFunction:InvokeServer("BackToLobby")
end
completeLobby.Activated:Connect(backToLobby)
settingsLobby.Activated:Connect(backToLobby)
hud.LobbyButton.Activated:Connect(backToLobby)
mapsStart.Activated:Connect(function()
	queueEvent:FireServer("Start")
end)
mapsLeave.Activated:Connect(function()
	mapsWindow.Visible = false
	queueEvent:FireServer("Leave")
	showToast("Step off the pad to leave the queue.", "info")
end)
hud.QueueLeave.Activated:Connect(function()
	queueEvent:FireServer("Leave")
	showToast("Step off the pad to leave the queue.", "info")
end)
joinButton.Activated:Connect(function()
	local ok, message = lobbyFunction:InvokeServer("Join", codeBox.Text)
	showToast(message, if ok then "room" else "error")
end)

---------------------------------------------------------------------------
-- Messages du serveur
---------------------------------------------------------------------------
notifyEvent.OnClientEvent:Connect(function(kind, text, position, item, fromCFrame)
	if kind == "placed" then
		popPoints(text)
		animatePlacement(item, fromCFrame)
		celebrate(position, 12)
		return
	elseif kind == "enter" then
		finished = false
		timerStart, timerStopped = nil, nil
		hud.Timer.Text = "00:00"
		closeAllWindows()
		updateMode()
		showTutorial()
		return
	elseif kind == "complete" then
		showCompletion(text)
		return
	end
	showToast(text, kind)
end)

---------------------------------------------------------------------------
-- Écoute des changements
---------------------------------------------------------------------------
for _, name in { "Held", "HeldCategories", "HeldNames", "Selected", "Carrying", "CarryingCategory", "CarryingName", "Capacity" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		updateBag()
		updateHint()
		requestRefresh()
	end)
end
for _, name in { "Points", "Rank", "Wins", "DealBought", "MagnetUnlocked", "Level_Capacity", "Level_Speed", "Level_Magnet", "Level_Magnifier", "Level_QuickStock" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		updatePoints()
		updateTools()
		updateQueueUI()
	end)
end
for _, pass in TidyConfig.GamePasses do
	player:GetAttributeChangedSignal("Pass_" .. pass.Id):Connect(updatePoints)
end
player:GetAttributeChangedSignal("Quests"):Connect(updateQuests)
player:GetAttributeChangedSignal("Settings"):Connect(updateSettingsFromServer)
player:GetAttributeChangedSignal("InMap"):Connect(function()
	updateMode()
	updateQueueUI()
end)
for _, name in { "QueuePad", "QueueHost" } do
	player:GetAttributeChangedSignal(name):Connect(updateQueueUI)
end
for _, name in { "TidyTotal", "TidyRemaining" } do
	ReplicatedStorage:GetAttributeChangedSignal(name):Connect(updateCounters)
end
ReplicatedStorage:GetAttributeChangedSignal("RoundNumber"):Connect(function()
	finished = false
	timerStart, timerStopped = nil, nil
	hud.Timer.Text = "00:00"
	completeWindow.Visible = false
	updateCounters()
	updateHint()
	requestRefresh()
end)
local function updateRoomCode()
	local code = ReplicatedStorage:GetAttribute("RoomCode")
	hud.RoomCode.Text = if type(code) == "string" and code ~= "" then ("Friends code: " .. code) else ""
end
ReplicatedStorage:GetAttributeChangedSignal("RoomCode"):Connect(updateRoomCode)

for _, tag in { TidyConfig.SlotTag, TidyConfig.ZoneTag } do
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		instance:GetAttributeChangedSignal("Occupied"):Connect(requestRefresh)
		requestRefresh()
	end)
	for _, instance in CollectionService:GetTagged(tag) do
		instance:GetAttributeChangedSignal("Occupied"):Connect(requestRefresh)
	end
end

-- Boucle lente : loupe, panneaux proches, état des files d'attente.
task.spawn(function()
	while true do
		task.wait(0.4)
		updateGuide()
		if inMap() then
			refreshWorld()
		end
		if (player:GetAttribute("QueuePad") or 0) ~= 0 then
			updateQueueUI()
		end
	end
end)

updateSettingsFromServer()
updateCounters()
updatePoints()
updateQuests()
updateTools()
updateRoomCode()
updateMode()
updateQueueUI()
