-- TidyUI (LocalScript)
-- Emplacement : StarterPlayer > StarterPlayerScripts
-- Écran du joueur et commandes, style "verre sombre" (panneaux bleu nuit, boutons colorés en relief) :
--  * une seule famille de polices : Fredoka One (titres, chiffres, boutons) et Builder Sans (textes) ;
--  * menu en bas à gauche (à gauche au milieu sur mobile) : points, rang, Upgrades, Shop, Settings ;
--  * chronomètre, consigne, compteurs (objets rangés, panier), offre limitée "DEAL" ;
--  * carte de l'objet en main, barre d'outils à 2 cases (main, aimant) ;
--  * 6 cartes de tutoriel affichées sur un panneau à l'entrée de chaque niveau ;
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
	Panel = Color3.fromRGB(56, 52, 116), -- haut des panneaux (dégradé vers le bleu nuit)
	Edge = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(184, 188, 228),
	Ink = Color3.fromRGB(18, 18, 44), -- contour des textes
	Gold = Color3.fromRGB(255, 200, 64),
	GoldDark = Color3.fromRGB(190, 120, 16),
	Green = Color3.fromRGB(62, 214, 112),
	GreenDark = Color3.fromRGB(24, 132, 66),
	Blue = Color3.fromRGB(72, 154, 255),
	BlueDark = Color3.fromRGB(30, 86, 196),
	Pink = Color3.fromRGB(255, 94, 170),
	Purple = Color3.fromRGB(150, 106, 255),
	PurpleDark = Color3.fromRGB(88, 54, 190),
	Red = Color3.fromRGB(255, 80, 96),
	RedDark = Color3.fromRGB(170, 30, 52),
	Orange = Color3.fromRGB(255, 152, 54),
	Yellow = Color3.fromRGB(255, 224, 92),
	White = Color3.fromRGB(255, 255, 255),
	Dark = Color3.fromRGB(18, 18, 44),
	Locked = Color3.fromRGB(104, 108, 146),
	LockedDark = Color3.fromRGB(60, 62, 96),
}
local FONT_TITLE = Enum.Font.FredokaOne
local FONT = Enum.Font.BuilderSansBold
local FONT_LIGHT = Enum.Font.BuilderSansMedium
local FONT_HEAVY = Enum.Font.BuilderSansExtraBold

-- Couleurs des boutons : { fond, bord et contour du texte }.
local BUTTON_STYLES = {
	Green = { THEME.Green, THEME.GreenDark },
	Gold = { THEME.Gold, THEME.GoldDark },
	Blue = { THEME.Blue, THEME.BlueDark },
	Red = { THEME.Red, THEME.RedDark },
	Purple = { THEME.Purple, THEME.PurpleDark },
	Gray = { THEME.Locked, THEME.LockedDark },
}

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

local function addStroke(parent, color, thickness, transparency)
	return make("UIStroke", { Name = "Edge", Color = color or THEME.Edge, Thickness = thickness or 2, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

local function addGradient(parent, top, bottom, rotation)
	return make("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90, Parent = parent })
end

-- Taille du texte : fixe (calculée sur la hauteur du cadre) pour que tous les textes d'une même
-- ligne aient la même taille. TextScaled seulement pour les cadres en proportions, avec un plafond.
local function sizeText(properties)
	local maxText = properties.MaxText
	properties.MaxText = nil
	if properties.TextSize then
		properties.TextScaled = false
	elseif properties.TextScaled == nil then
		local size = properties.Size
		if typeof(size) == "UDim2" and size.Y.Scale == 0 and size.Y.Offset > 0 then
			properties.TextScaled = false
			properties.TextSize = math.floor(size.Y.Offset * 0.78)
		else
			properties.TextScaled = true
		end
	end
	return maxText
end

local function label(parent, properties)
	local outline = properties.Outline
	properties.Outline = nil
	properties.Parent = parent
	properties.BackgroundTransparency = 1
	properties.Font = properties.Font or FONT
	properties.TextColor3 = properties.TextColor3 or THEME.Text
	local maxText = sizeText(properties)
	local l = make("TextLabel", properties)
	if l.TextScaled then
		make("UITextSizeConstraint", { MaxTextSize = maxText or 34, Parent = l })
	end
	if outline then
		make("UIStroke", { Name = "Outline", Color = THEME.Ink, Thickness = outline, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = l })
	end
	return l
end

-- Texte posé sur le décor : contour sombre pour rester lisible partout.
local function outlined(parent, properties)
	properties.Outline = properties.Outline or 2
	return label(parent, properties)
end

-- Panneau en verre sombre : dégradé indigo -> bleu nuit, bord blanc très léger.
local function glass(parent, properties, radius)
	properties.Parent = parent
	properties.BackgroundColor3 = properties.BackgroundColor3 or THEME.Panel
	properties.BackgroundTransparency = properties.BackgroundTransparency or 0.06
	properties.BorderSizePixel = 0
	local frame = make("Frame", properties)
	addCorner(frame, UDim.new(0, radius or 16))
	addGradient(frame, Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 120, 150))
	addStroke(frame, THEME.Edge, 2, 0.8)
	return frame
end

-- Ligne claire à l'intérieur d'une fenêtre.
local function row(parent, properties)
	properties.Parent = parent
	properties.BackgroundColor3 = THEME.White
	properties.BackgroundTransparency = 0.9
	properties.BorderSizePixel = 0
	local frame = make("Frame", properties)
	addCorner(frame, UDim.new(0, 12))
	addStroke(frame, THEME.Edge, 1.5, 0.88)
	return frame
end

-- Bouton en relief : fond coloré dégradé, bord foncé, texte blanc contouré (enfant "Label").
local function button(parent, properties, style)
	local colors = BUTTON_STYLES[style or "Green"]
	local text = properties.Text or ""
	local font = properties.Font or FONT_TITLE
	local textSize = properties.TextSize
	properties.Text = ""
	properties.Font = nil
	properties.TextSize = nil
	properties.TextScaled = nil
	properties.Parent = parent
	properties.BackgroundColor3 = colors[1]
	properties.AutoButtonColor = true
	properties.BorderSizePixel = 0
	local b = make("TextButton", properties)
	addCorner(b, UDim.new(0, 12))
	addGradient(b, Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 215))
	addStroke(b, colors[2], 2.5)
	local textLabel = label(b, { Name = "Label", Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(1, -12, 1, 0), Text = text, Font = font, TextSize = textSize, TextScaled = if textSize then nil else true, MaxText = 28, ZIndex = b.ZIndex, Outline = 2 })
	textLabel.Outline.Color = colors[2]
	return b
end

-- Change le texte et / ou la couleur d'un bouton fait avec button().
local function setButton(b, text, style)
	if text then
		b.Label.Text = text
	end
	if style then
		local colors = BUTTON_STYLES[style]
		b.BackgroundColor3 = colors[1]
		b.Edge.Color = colors[2]
		b.Label.Outline.Color = colors[2]
	end
end

-- Pastille ronde colorée avec une icône (emoji).
local function iconBadge(parent, properties, color, icon)
	properties.Parent = parent
	properties.BackgroundColor3 = color
	properties.BorderSizePixel = 0
	local frame = make("Frame", properties)
	addCorner(frame, UDim.new(1, 0))
	addGradient(frame, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 185))
	addStroke(frame, THEME.Edge, 2, 0.6)
	-- Reflet brillant en haut à gauche.
	local shine = make("Frame", { Name = "Shine", Position = UDim2.fromScale(0.18, 0.1), Size = UDim2.fromScale(0.38, 0.22), Rotation = -25, BackgroundColor3 = THEME.White, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = frame.ZIndex, Parent = frame })
	addCorner(shine, UDim.new(1, 0))
	label(frame, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.66, 0.66), Text = icon, MaxText = 60, ZIndex = frame.ZIndex + 1 })
	return frame
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
local ROBUX = utf8.char(0xE002)

-- Mode test de Studio : tout est ouvert.
local function testUnlockAll()
	return ReplicatedStorage:GetAttribute("TestUnlockAll") == true
end

---------------------------------------------------------------------------
-- Écran principal
---------------------------------------------------------------------------
local screenGui = make("ScreenGui", {
	Name = "TidyUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})
-- L'interface s'adapte à la taille de l'écran : chaque bloc est agrandi / réduit autour de son
-- point d'ancrage, donc rien ne sort de l'écran (avant, les compteurs de droite étaient coupés).
local function updateUiScale()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local scale = math.clamp(math.min(viewport.X / 1500, viewport.Y / 860), 0.5, 1.05)
	for _, child in screenGui:GetChildren() do
		if child:IsA("GuiObject") then
			local uiScale = child:FindFirstChild("AutoScale")
			if not uiScale then
				uiScale = make("UIScale", { Name = "AutoScale", Parent = child })
			end
			uiScale.Scale = scale
		end
	end
end

local hud = {}

-- Chronomètre (pastille en haut au centre) et consigne juste en dessous.
hud.Timer = glass(screenGui, { Name = "Timer", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0, 176, 0, 54) }, 27)
label(hud.Timer, { Name = "Icon", Position = UDim2.new(0, 14, 0, 9), Size = UDim2.new(0, 36, 0, 36), Text = "⏱️", TextSize = 26 })
hud.TimerText = label(hud.Timer, { Name = "Time", Position = UDim2.new(0, 50, 0, 6), Size = UDim2.new(1, -62, 0, 42), Text = "00:00", Font = FONT_TITLE, TextSize = 32, Outline = 2 })

-- Consigne dans une pastille sombre (lisible sur tous les décors), la pièce en petit dessous.
hud.Hint = label(screenGui, {
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 72),
	Size = UDim2.new(0, 0, 0, 34),
	AutomaticSize = Enum.AutomaticSize.X,
	Text = "",
	Font = FONT_HEAVY,
	TextSize = 18,
	TextColor3 = THEME.White,
})
hud.Hint.BackgroundTransparency = 0.25
hud.Hint.BackgroundColor3 = THEME.Dark
addCorner(hud.Hint, UDim.new(1, 0))
make("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = hud.Hint })
hud.Area = outlined(screenGui, { Name = "Area", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 110), Size = UDim2.new(0, 520, 0, 20), Text = "", Font = FONT, TextSize = 15, TextColor3 = THEME.Muted, Outline = 1.5 })

-- Compteurs en haut à droite : objets rangés et panier.
local function counter(name, y, icon, color, caption)
	local holder = glass(screenGui, { Name = name, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, y), Size = UDim2.new(0, 190, 0, 52) }, 26)
	iconBadge(holder, { Name = "Badge", Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(0, 40, 0, 40) }, color, icon)
	label(holder, { Name = "Caption", Position = UDim2.new(0, 54, 0, 6), Size = UDim2.new(1, -66, 0, 14), Text = caption, Font = FONT_HEAVY, TextSize = 12, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left })
	local value = label(holder, { Name = "Value", Position = UDim2.new(0, 54, 0, 19), Size = UDim2.new(1, -66, 0, 28), Text = "0/0", Font = FONT_TITLE, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Outline = 1.5 })
	return holder, value
end
hud.PlacedHolder, hud.Placed = counter("PlacedCounter", 12, "🗄️", THEME.Green, "TIDIED UP")
hud.BagHolder, hud.Bag = counter("BagCounter", 72, "🧺", THEME.Blue, "BASKET")

-- Offre limitée "DEAL" (carte à droite, compte à rebours).
do
	local deal = TidyConfig.GetProduct("Deal")
	hud.Deal = make("TextButton", {
		Name = "DealBadge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 134),
		Size = UDim2.new(0, 210, 0, 128),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = true,
		Parent = screenGui,
	})
	addCorner(hud.Deal, UDim.new(0, 18))
	addGradient(hud.Deal, Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 120, 150))
	local edge = addStroke(hud.Deal, THEME.White, 3)
	make("UIGradient", { Name = "Shine", Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, THEME.Pink), ColorSequenceKeypoint.new(0.5, THEME.Gold), ColorSequenceKeypoint.new(1, THEME.Pink) }), Parent = edge })
	iconBadge(hud.Deal, { Name = "Gift", Position = UDim2.new(0, 10, 0, 12), Size = UDim2.new(0, 58, 0, 58), ZIndex = 2 }, THEME.Pink, deal and deal.Icon or "🎁")
	label(hud.Deal, { Name = "Tag", Position = UDim2.new(0, 76, 0, 12), Size = UDim2.new(1, -86, 0, 16), Text = "LIMITED OFFER", Font = FONT_HEAVY, TextSize = 13, TextColor3 = THEME.Pink, TextXAlignment = Enum.TextXAlignment.Left })
	label(hud.Deal, { Name = "DealText", Position = UDim2.new(0, 76, 0, 28), Size = UDim2.new(1, -86, 0, 26), Text = "STARTER DEAL", Font = FONT_TITLE, TextSize = 21, TextColor3 = THEME.Gold, TextXAlignment = Enum.TextXAlignment.Left, Outline = 1.5 })
	label(hud.Deal, { Name = "Desc", Position = UDim2.new(0, 76, 0, 54), Size = UDim2.new(1, -86, 0, 16), Text = "3,000 pts + 3 carry", Font = FONT, TextSize = 14, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left })
	local timerPill = make("Frame", { Name = "TimerPill", Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(0, 84, 0, 34), BackgroundColor3 = THEME.RedDark, BorderSizePixel = 0, Parent = hud.Deal })
	addCorner(timerPill, UDim.new(1, 0))
	label(timerPill, { Name = "Time", Size = UDim2.fromScale(1, 1), Text = "5:00", Font = FONT_TITLE, TextSize = 19 })
	local price = make("Frame", { Name = "PricePill", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 1, -44), Size = UDim2.new(0, 96, 0, 34), BackgroundColor3 = THEME.Green, BorderSizePixel = 0, Parent = hud.Deal })
	addCorner(price, UDim.new(1, 0))
	addStroke(price, THEME.GreenDark, 2)
	label(price, { Name = "Price", Size = UDim2.fromScale(1, 1), Text = ROBUX .. " " .. (deal and deal.Price or 0), Font = FONT_TITLE, TextSize = 19, Outline = 1.5 }).Outline.Color = THEME.GreenDark
end

-- Menu : points et rang, puis 4 grosses touches (en bas à gauche sur ordinateur,
-- à gauche au milieu sur mobile pour laisser la place au joystick).
hud.Menu = make("Frame", {
	Name = "Menu",
	AnchorPoint = if isTouchOnly then Vector2.new(0, 0.5) else Vector2.new(0, 1),
	Position = if isTouchOnly then UDim2.new(0, 20, 0.42, 0) else UDim2.new(0, 20, 1, -20),
	Size = UDim2.new(0, 252, 0, 260),
	BackgroundTransparency = 1,
	Parent = screenGui,
})
make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = hud.Menu })

hud.LobbyButton = button(hud.Menu, { Name = "LobbyButton", LayoutOrder = 1, Size = UDim2.new(0, 160, 0, 40), Text = "🏠 Lobby", TextSize = 20 }, "Blue")
hud.RoomCode = outlined(hud.Menu, { Name = "RoomCode", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 20), Text = "", Font = FONT, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Visible = false })

hud.PointsPanel = glass(hud.Menu, { Name = "PointsPanel", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 60) }, 16)
iconBadge(hud.PointsPanel, { Name = "Coin", Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(0, 44, 0, 44) }, THEME.Gold, "🪙")
hud.Points = label(hud.PointsPanel, { Name = "Points", Position = UDim2.new(0, 60, 0, 6), Size = UDim2.new(1, -70, 0, 30), Text = "0", Font = FONT_TITLE, TextSize = 27, TextXAlignment = Enum.TextXAlignment.Left, Outline = 2 })
hud.Rank = label(hud.PointsPanel, { Name = "Rank", Position = UDim2.new(0, 60, 0, 36), Size = UDim2.new(1, -70, 0, 16), Text = "Intern", Font = FONT, TextSize = 14, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left })

local menuGrid = make("Frame", { Name = "Buttons", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 76), BackgroundTransparency = 1, Parent = hud.Menu })
make("UIGridLayout", { CellSize = UDim2.new(0, 76, 0, 76), CellPadding = UDim2.new(0, 12, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menuGrid })

local sideButtons = {}
local function sideButton(name, text, key, order, icon, style)
	local colors = BUTTON_STYLES[style]
	local b = make("TextButton", { Name = name .. "Button", LayoutOrder = order, BackgroundColor3 = colors[1], BorderSizePixel = 0, Text = "", AutoButtonColor = true, Parent = menuGrid })
	addCorner(b, UDim.new(0, 16))
	addGradient(b, Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 205))
	local stroke = addStroke(b, colors[2], 2.5)
	label(b, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0, 36, 0, 36), Text = icon, TextSize = 29 })
	label(b, { Name = "Label", Position = UDim2.new(0, 2, 1, -25), Size = UDim2.new(1, -4, 0, 20), Text = text, Font = FONT_TITLE, TextSize = 15, Outline = 1.5 }).Outline.Color = colors[2]
	local badge = make("Frame", { Name = "KeyBadge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.new(0, 20, 0, 20), BackgroundColor3 = THEME.Dark, BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = not isTouchOnly, Parent = b })
	addCorner(badge, UDim.new(0, 7))
	label(badge, { Size = UDim2.fromScale(1, 1), Text = keyName(key), Font = FONT_TITLE, TextSize = 13 })
	sideButtons[name] = { Button = b, Stroke = stroke }
	return b
end
sideButton("Upgrades", "Upgrades", Enum.KeyCode.G, 1, "⚡", "Green")
sideButton("Shop", "Shop", Enum.KeyCode.F, 2, "🛒", "Gold")
sideButton("Settings", "Settings", Enum.KeyCode.R, 3, "⚙️", "Purple")
-- Bord arc-en-ciel animé sur le bouton de la boutique.
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
sideButtons.Shop.Stroke.Thickness = 3.5

-- Carte de l'objet en main et barre d'outils (en bas au centre).
hud.ItemCard = glass(screenGui, { Name = "ItemCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -106), Size = UDim2.new(0, 340, 0, 66) }, 16)
make("Frame", { Name = "Accent", Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 4, 1, -24), BackgroundColor3 = THEME.Gold, BorderSizePixel = 0, Parent = hud.ItemCard })
hud.ItemSection = label(hud.ItemCard, { Name = "Section", Position = UDim2.new(0, 26, 0, 9), Size = UDim2.new(1, -110, 0, 16), Text = "", Font = FONT_HEAVY, TextSize = 13, TextColor3 = THEME.Gold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
hud.ItemName = label(hud.ItemCard, { Name = "ItemName", Position = UDim2.new(0, 26, 0, 26), Size = UDim2.new(1, -40, 0, 30), Text = "", Font = FONT_TITLE, TextSize = 23, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Outline = 1.5 })
hud.ItemCount = label(hud.ItemCard, { Name = "Count", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 9), Size = UDim2.new(0, 80, 0, 16), Text = "", Font = FONT_TITLE, TextSize = 14, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Right })

hud.Hotbar = make("Frame", { Name = "Hotbar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(0, 2 * 86, 0, 80), BackgroundTransparency = 1, Parent = screenGui })
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), Parent = hud.Hotbar })
local TOOLS = {
	{ Id = "Hand", Key = Enum.KeyCode.One, Number = 1, Icon = "🖐️", Name = "Hand" },
	{ Id = "Magnet", Key = Enum.KeyCode.Two, Number = 2, Icon = "🧲", Name = "Magnet" },
}
local toolSlots = {}
for _, tool in TOOLS do
	local slot = make("TextButton", { Name = tool.Id, Size = UDim2.new(0, 76, 0, 80), BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.06, BorderSizePixel = 0, Text = "", AutoButtonColor = true, Parent = hud.Hotbar })
	addCorner(slot, UDim.new(0, 18))
	addGradient(slot, Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 120, 150))
	local stroke = addStroke(slot, THEME.Edge, 2, 0.8)
	local badge = make("Frame", { Name = "Number", Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(0, 22, 0, 22), BackgroundColor3 = THEME.Dark, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = slot })
	addCorner(badge, UDim.new(1, 0))
	label(badge, { Size = UDim2.fromScale(1, 1), Text = tostring(tool.Number), Font = FONT_TITLE, TextSize = 14 })
	label(slot, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0, 42, 0, 42), Text = tool.Icon, TextSize = 33 })
	label(slot, { Name = "ToolName", Position = UDim2.new(0, 2, 1, -22), Size = UDim2.new(1, -4, 0, 16), Text = tool.Name, Font = FONT_HEAVY, TextSize = 12, TextColor3 = THEME.Muted })
	local lock = make("Frame", { Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Dark, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 3, Parent = slot })
	addCorner(lock, UDim.new(0, 18))
	label(lock, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(0, 34, 0, 34), Text = "🔒", TextSize = 28, ZIndex = 4 })
	toolSlots[tool.Id] = { Button = slot, Stroke = stroke, Lock = lock }
end

-- Boutons tactiles (mobile) : objet précédent / suivant et lâcher.
hud.TouchBar = make("Frame", { Name = "TouchBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -210), Size = UDim2.new(0, 300, 0, 50), BackgroundTransparency = 1, Visible = isTouchOnly, Parent = screenGui })
hud.PrevButton = button(hud.TouchBar, { Name = "Prev", Size = UDim2.new(0, 60, 1, 0), Text = "<" }, "Purple")
hud.DropButton = button(hud.TouchBar, { Name = "Drop", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 140, 1, 0), Text = "Drop" }, "Red")
hud.NextButton = button(hud.TouchBar, { Name = "Next", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 60, 1, 0), Text = ">" }, "Purple")

-- Aide des commandes (en bas à droite, ordinateur seulement).
hud.Controls = glass(screenGui, { Name = "Controls", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.new(0, 200, 0, 104), BackgroundTransparency = 0.45, Visible = not isTouchOnly }, 14)
do
	local lines = {
		{ keyName(Enum.KeyCode.Q), "Drop item" },
		{ "Wheel", "Switch item" },
		{ keyName(Enum.KeyCode.Y), "Free mouse" },
		{ "M", "Music on / off" },
	}
	for i, line in lines do
		local y = 10 + (i - 1) * 22
		local key = make("Frame", { Name = "Key" .. i, Position = UDim2.new(0, 12, 0, y), Size = UDim2.new(0, 56, 0, 19), BackgroundColor3 = THEME.White, BackgroundTransparency = 0.82, BorderSizePixel = 0, Parent = hud.Controls })
		addCorner(key, UDim.new(0, 6))
		label(key, { Size = UDim2.fromScale(1, 1), Text = line[1], Font = FONT_HEAVY, TextSize = 13 })
		label(hud.Controls, { Name = "Line" .. i, Position = UDim2.new(0, 78, 0, y), Size = UDim2.new(1, -88, 0, 19), Text = line[2], Font = FONT, TextSize = 15, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left })
	end
end

-- Viseur, texte de visée, message temporaire.
hud.Crosshair = make("Frame", { Name = "Crosshair", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 8, 0, 8), BackgroundColor3 = THEME.White, Visible = false, Parent = screenGui })
addCorner(hud.Crosshair, UDim.new(1, 0))
addStroke(hud.Crosshair, THEME.Dark, 1.5)
hud.Aim = outlined(screenGui, { Name = "Aim", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 18), Size = UDim2.new(0, 560, 0, 24), Text = "", Font = FONT_HEAVY, TextSize = 19 })

hud.Toast = glass(screenGui, { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 0), Size = UDim2.new(0, 560, 0, 52), Visible = false, ZIndex = 20 }, 26)
hud.ToastAccent = make("Frame", { Name = "Accent", Position = UDim2.new(0, 14, 0, 12), Size = UDim2.new(0, 6, 1, -24), BackgroundColor3 = THEME.Green, BorderSizePixel = 0, ZIndex = 21, Parent = hud.Toast })
addCorner(hud.ToastAccent, UDim.new(1, 0))
hud.ToastText = label(hud.Toast, { Name = "Text", Position = UDim2.new(0, 30, 0, 0), Size = UDim2.new(1, -44, 1, 0), Text = "", Font = FONT_HEAVY, TextSize = 20, TextWrapped = true, ZIndex = 21 })

-- Bandeau du hall et barre de la file d'attente.
hud.Banner = glass(screenGui, { Name = "Banner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0, 520, 0, 50), Visible = false }, 25)
hud.BannerText = label(hud.Banner, { Name = "Text", Size = UDim2.fromScale(1, 1), Text = "", Font = FONT_TITLE, TextSize = 22, Outline = 1.5 })
hud.QueueBar = glass(screenGui, { Name = "QueueBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0, 560, 0, 72), Visible = false }, 20)
hud.QueueText = label(hud.QueueBar, { Name = "Text", Position = UDim2.new(0, 20, 0, 0), Size = UDim2.new(1, -170, 1, 0), Text = "", Font = FONT_TITLE, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true })
hud.QueueLeave = button(hud.QueueBar, { Name = "Leave", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 128, 0, 48), Text = "Leave", TextSize = 22 }, "Red")

local function setBanner(text)
	hud.BannerText.Text = text
	hud.Banner.Visible = text ~= ""
end

---------------------------------------------------------------------------
-- Fenêtres (verre sombre, titre avec icône, bouton fermer rond)
---------------------------------------------------------------------------
local panels = {}
local function makeWindow(name, title, size, icon)
	local window = glass(screenGui, { Name = name .. "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size, Visible = false, ZIndex = 5, BackgroundTransparency = 0 }, 22)
	local header = make("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 68), BackgroundTransparency = 1, ZIndex = 5, Parent = window })
	if icon then
		iconBadge(header, { Name = "Badge", Position = UDim2.new(0, 16, 0, 12), Size = UDim2.new(0, 46, 0, 46), ZIndex = 6 }, THEME.Gold, icon)
	end
	label(header, { Name = "Title", Position = UDim2.new(0, if icon then 74 else 22, 0, 14), Size = UDim2.new(1, -150, 0, 42), Text = title, Font = FONT_TITLE, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Outline = 2 })
	make("Frame", { Name = "Line", Position = UDim2.new(0, 16, 1, -2), Size = UDim2.new(1, -32, 0, 2), BackgroundColor3 = THEME.White, BackgroundTransparency = 0.86, BorderSizePixel = 0, ZIndex = 6, Parent = header })
	local close = button(header, { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.new(0, 42, 0, 42), Text = "X", TextSize = 24, ZIndex = 6 }, "Red")
	close.UICorner.CornerRadius = UDim.new(1, 0)
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
-- Une musique pour le hall et une par niveau (TidyConfig.Music), qui change toute seule.
local musicSound = make("Sound", { Name = "ChillMusic", Looped = true, Volume = settings.Music, Parent = SoundService })
local function musicFor(mapId)
	if TidyConfig.MusicSoundId ~= "" then
		return TidyConfig.MusicSoundId
	end
	local list = TidyConfig.Music or {}
	return list[mapId or "Lobby"] or list.Lobby or ""
end
local function updateMusic()
	local playing = player:GetAttribute("InMap") == true
	local id = musicFor(if playing then ReplicatedStorage:GetAttribute("ActiveMap") else "Lobby")
	if id ~= "" and musicSound.SoundId ~= id then
		musicSound.SoundId = id
		musicSound:Play()
	end
end

local function applySettings()
	if musicSound then
		musicSound.Volume = if musicMuted then 0 else settings.Music
	end
	hud.Controls.Visible = settings.Controls and not isTouchOnly and player:GetAttribute("InMap") == true
	-- Graphismes légers : pas d'ombres ni d'effets de lumière (pour les petits ordinateurs et téléphones).
	Lighting.GlobalShadows = not settings.LowGraphics
	for _, name in { "AgencyBloom", "AgencyAtmosphere" } do
		local effect = Lighting:FindFirstChild(name)
		if effect and effect:IsA("PostEffect") then
			effect.Enabled = not settings.LowGraphics
		elseif effect and effect:IsA("Atmosphere") then
			effect.Density = if settings.LowGraphics then 0 else 0.25
		end
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
	hud.ToastText.Text = text
	hud.ToastAccent.BackgroundColor3 = if kind == "error" then THEME.Red elseif kind == "room" or kind == "quest" or kind == "purchase" then THEME.Green else THEME.Blue
	hud.Toast.Visible = true
	hud.Toast.BackgroundTransparency = 0.06
	hud.ToastText.TextTransparency = 0
	hud.ToastAccent.BackgroundTransparency = 0
	task.delay(if kind == "room" or kind == "quest" then 3 else 2, function()
		if token ~= toastToken then
			return
		end
		local info = TweenInfo.new(0.35)
		TweenService:Create(hud.Toast, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(hud.ToastText, info, { TextTransparency = 1 }):Play()
		TweenService:Create(hud.ToastAccent, info, { BackgroundTransparency = 1 }):Play()
		task.delay(0.4, function()
			if token == toastToken then
				hud.Toast.Visible = false
			end
		end)
	end)
end

-- "+12" doré qui monte près du viseur.
local function popPoints(text)
	local offset = math.random(-30, 30)
	local pop = label(screenGui, { Name = "PointsPop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, offset, 0.46, 0), Size = UDim2.new(0, 180, 0, 40), Text = text, Font = FONT_TITLE, TextSize = 32, TextColor3 = THEME.Gold, Outline = 2.5 })
	pop.Outline.Color = Color3.fromRGB(110, 60, 10)
	TweenService:Create(pop, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, offset, 0.38, 0), TextTransparency = 1 }):Play()
	TweenService:Create(pop.Outline, TweenInfo.new(0.8), { Transparency = 1 }):Play()
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
-- Le tutoriel est affiché sur un grand panneau ("TutorialBoard") posé dans chaque niveau, face au point d'arrivée.
-- Toile de 840 x 600 pixels (panneau de 14 x 10 studs, 60 pixels par stud).
local tutorialSurface = make("SurfaceGui", { Name = "TutorialBoardGui", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 60, LightInfluence = 0.2, Enabled = false, ResetOnSpawn = false, Parent = playerGui })
make("Frame", { Name = "Background", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 30, 66), BorderSizePixel = 0, Parent = tutorialSurface })
local tutorial = make("Frame", { Name = "Tutorial", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0, 780, 0, 492), BackgroundTransparency = 1, Visible = true, ZIndex = 8, Parent = tutorialSurface })
outlined(tutorial, { Name = "Title", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.new(1, 0, 0, 40), Text = "HOW TO PLAY", Font = FONT_TITLE, TextSize = 38, TextColor3 = THEME.Yellow, Outline = 3, ZIndex = 8 })

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
local CARD_COLORS = { THEME.Red, THEME.Blue, THEME.Green, THEME.Gold, THEME.Purple, THEME.Pink }
for index, texts in CARD_TEXTS do
	local column = (index - 1) % 3
	local rowIndex = (index - 1) // 3
	local card = glass(tutorial, {
		Name = "Card" .. index,
		Position = UDim2.new(0, column * 266, 0, rowIndex * 252),
		Size = UDim2.new(0, 248, 0, 240),
		ZIndex = 8,
	}, 18)
	local badge = make("Frame", { Name = "Number", Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 32, 0, 32), BackgroundColor3 = CARD_COLORS[index], BorderSizePixel = 0, ZIndex = 9, Parent = card })
	addCorner(badge, UDim.new(1, 0))
	label(badge, { Size = UDim2.fromScale(1, 1), Text = tostring(index), Font = FONT_TITLE, TextSize = 19, ZIndex = 10, Outline = 1.5 })
	label(card, { Name = "Title", Position = UDim2.new(0, 52, 0, 12), Size = UDim2.new(1, -62, 0, 32), Text = texts[1], Font = FONT_TITLE, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9, Outline = 1.5 })
	local viewport = viewportScene(card, CARD_SCENES[index], CFrame.lookAt(Vector3.new(0, 7, 11), Vector3.new(0, 1.5, 0)))
	viewport.Position = UDim2.new(0, 12, 0, 52)
	viewport.Size = UDim2.new(1, -24, 0, 118)
	if CARD_OVERLAYS[index] ~= "" then
		outlined(viewport, { Name = "Overlay", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, if index == 2 then 12 else 22), Size = UDim2.new(0.6, 0, 0, 44), Text = CARD_OVERLAYS[index], Font = FONT_TITLE, TextSize = 36, TextColor3 = if index == 2 then THEME.White else THEME.Yellow, Outline = 2.5, ZIndex = 10 })
	end
	label(card, { Name = "Caption", Position = UDim2.new(0, 14, 0, 178), Size = UDim2.new(1, -28, 0, 56), Text = texts[2], Font = FONT, TextSize = 16, TextColor3 = THEME.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 9 })
end

---------------------------------------------------------------------------
-- Fenêtre des améliorations : icône, nom, description, barre de niveaux, prix
---------------------------------------------------------------------------
local upgradesWindow = makeWindow("Upgrades", "UPGRADES", UDim2.new(0, 600, 0, 540), "⚡")
local upgradesPointsPill = make("Frame", { Name = "PointsPill", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -68, 0, 17), Size = UDim2.new(0, 150, 0, 36), BackgroundColor3 = THEME.Dark, BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 6, Parent = upgradesWindow })
addCorner(upgradesPointsPill, UDim.new(1, 0))
addStroke(upgradesPointsPill, THEME.Gold, 2)
local upgradesPoints = label(upgradesPointsPill, { Name = "Points", Size = UDim2.fromScale(1, 1), Text = "🪙 0", Font = FONT_TITLE, TextSize = 20, TextColor3 = THEME.Gold, ZIndex = 7 })
local UPGRADE_COLORS = { THEME.Blue, THEME.Pink, THEME.Red, THEME.Purple, THEME.Green }
local upgradeRows = {}
for i, upgrade in TidyConfig.Upgrades do
	local r = row(upgradesWindow, { Name = upgrade.Id, Position = UDim2.new(0, 16, 0, 82 + (i - 1) * 88), Size = UDim2.new(1, -32, 0, 80), ZIndex = 6 })
	local tile = make("Frame", { Name = "IconTile", Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(0, 60, 0, 60), BackgroundColor3 = UPGRADE_COLORS[(i - 1) % #UPGRADE_COLORS + 1], BorderSizePixel = 0, ZIndex = 7, Parent = r })
	addCorner(tile, UDim.new(0, 14))
	addGradient(tile, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 185))
	label(tile, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 42, 0, 42), Text = upgrade.Icon, TextSize = 34, ZIndex = 8 })
	label(r, { Name = "Name", Position = UDim2.new(0, 82, 0, 8), Size = UDim2.new(1, -240, 0, 26), Text = upgrade.Name, Font = FONT_TITLE, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Outline = 1.5 })
	local desc = label(r, { Name = "Desc", Position = UDim2.new(0, 82, 0, 34), Size = UDim2.new(1, -240, 0, 18), Text = upgrade.Description, Font = FONT_LIGHT, TextSize = 14, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7 })
	-- Barre de niveaux : une case par niveau (une seule barre pour les améliorations à 1 niveau).
	local pipsFrame = make("Frame", { Name = "Levels", Position = UDim2.new(0, 82, 0, 58), Size = UDim2.new(1, -300, 0, 10), BackgroundTransparency = 1, ZIndex = 7, Parent = r })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = pipsFrame })
	local pips = {}
	for level = 1, upgrade.MaxLevel do
		local pip = make("Frame", { Name = "Level" .. level, Size = UDim2.new(1 / upgrade.MaxLevel, -4, 1, 0), BackgroundColor3 = THEME.White, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 8, Parent = pipsFrame })
		addCorner(pip, UDim.new(1, 0))
		pips[level] = pip
	end
	local levelText = label(r, { Name = "LevelText", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -154, 0, 54), Size = UDim2.new(0, 56, 0, 18), Text = "", Font = FONT_TITLE, TextSize = 15, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7 })
	local buy = button(r, { Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 132, 0, 50), Text = "", TextSize = 23, ZIndex = 7 }, "Green")
	upgradeRows[upgrade.Id] = { Buy = buy, Desc = desc, Upgrade = upgrade, Pips = pips, LevelText = levelText }
end

---------------------------------------------------------------------------
-- Boutique Robux : sections, cartes avec badge rond, ruban, bouton vert avec le prix
---------------------------------------------------------------------------
local shopWindow = makeWindow("Shop", "SHOP", UDim2.new(0, 840, 0, 620), "🛒")
label(shopWindow.Header, { Name = "Subtitle", Position = UDim2.new(0, 190, 0, 26), Size = UDim2.new(0, 360, 0, 22), Text = "Tidy faster, earn more!", Font = FONT, TextSize = 18, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
local shopScroll = make("ScrollingFrame", { Name = "ShopScroll", Position = UDim2.new(0, 20, 0, 80), Size = UDim2.new(1, -40, 1, -96), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = THEME.White, ScrollBarImageTransparency = 0.5, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 6, Parent = shopWindow })
make("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = shopScroll })
make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12), Parent = shopScroll })
local shopSections = {}
local function shopSection(order, text, color)
	local header = make("Frame", { Name = "Section" .. order, LayoutOrder = order, Size = UDim2.new(1, -20, 0, 34), BackgroundTransparency = 1, ZIndex = 6, Parent = shopScroll })
	local bar = make("Frame", { Name = "Bar", Position = UDim2.new(0, 0, 0, 4), Size = UDim2.new(0, 6, 0, 26), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 7, Parent = header })
	addCorner(bar, UDim.new(1, 0))
	label(header, { Name = "Title", Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(1, -16, 0, 34), Text = text, Font = FONT_TITLE, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Outline = 1.5 })
	local grid = make("Frame", { Name = "Grid" .. order, LayoutOrder = order + 1, Size = UDim2.new(1, -20, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 6, Parent = shopScroll })
	make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -12, 0, 246), CellPadding = UDim2.new(0, 16, 0, 16), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	shopSections[order] = header
	return grid
end
local passesGrid = shopSection(1, "GAME PASSES", THEME.Gold)
local productsGrid = shopSection(3, "POINTS & BOOSTS", THEME.Green)
local SHOP_COLORS = { THEME.Blue, THEME.Green, THEME.Gold, THEME.Purple, THEME.Pink, THEME.Red }
local shopTiles = {}
local function shopTile(grid, kind, entry, order, ribbonText)
	local tile = row(grid, { Name = entry.Id, LayoutOrder = order, ZIndex = 7 })
	iconBadge(tile, { Name = "Badge", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(0, 86, 0, 86), ZIndex = 8 }, SHOP_COLORS[(order - 1) % #SHOP_COLORS + 1], entry.Icon)
	label(tile, { Name = "Name", Position = UDim2.new(0, 10, 0, 106), Size = UDim2.new(1, -20, 0, 28), Text = entry.Name, Font = FONT_TITLE, TextSize = 22, ZIndex = 8, Outline = 1.5 })
	label(tile, { Name = "Desc", Position = UDim2.new(0, 14, 0, 136), Size = UDim2.new(1, -28, 0, 48), Text = entry.Description, Font = FONT_LIGHT, TextSize = 14, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = THEME.Muted, ZIndex = 8 })
	local buy = button(tile, { Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -28, 0, 44), Text = ROBUX .. " " .. entry.Price, TextSize = 22, ZIndex = 8 }, "Green")
	if ribbonText then
		local ribbon = make("Frame", { Name = "Ribbon", Position = UDim2.new(0, 10, 0, 12), Size = UDim2.new(0, 70, 0, 26), Rotation = -8, BackgroundColor3 = if ribbonText == "BEST!" then THEME.Gold else THEME.Pink, BorderSizePixel = 0, ZIndex = 10, Parent = tile })
		addCorner(ribbon, UDim.new(0, 8))
		label(ribbon, { Size = UDim2.fromScale(1, 1), Text = ribbonText, Font = FONT_TITLE, TextSize = 16, ZIndex = 11, Outline = 1.5 })
	end
	buy.Activated:Connect(function()
		local ok, message = shopFunction:InvokeServer(kind, entry.Id)
		if message and message ~= "" then
			showToast(message, if ok then "purchase" else "error")
		end
	end)
	-- Survol : la carte grossit un peu et son bord s'illumine.
	local hoverScale = make("UIScale", { Name = "Hover", Scale = 1, Parent = tile })
	local edge = tile:FindFirstChild("Edge")
	tile.MouseEnter:Connect(function()
		TweenService:Create(hoverScale, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
		if edge then
			edge.Color, edge.Transparency, edge.Thickness = THEME.Gold, 0, 3
		end
	end)
	tile.MouseLeave:Connect(function()
		TweenService:Create(hoverScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
		if edge then
			edge.Color, edge.Transparency, edge.Thickness = THEME.Edge, 0.88, 1.5
		end
	end)
	shopTiles[kind .. entry.Id] = { Buy = buy, Entry = entry, Kind = kind }
end
for i, pass in TidyConfig.GamePasses do
	shopTile(passesGrid, "Pass", pass, i, if pass.Best then "BEST!" elseif pass.Id == "VIP" then "VIP" else nil)
end
local productOrder = 0
for _, product in TidyConfig.Products do
	if not product.OneTime then
		productOrder += 1
		shopTile(productsGrid, "Product", product, productOrder, nil)
	end
end
-- Meilleure offre mise en avant tout en haut : l'offre de départ (cachée une fois achetée).
local featuredDeal = nil
do
	local deal = TidyConfig.GetProduct("Deal")
	if deal then
		featuredDeal = make("Frame", { Name = "FeaturedDeal", LayoutOrder = 0, Size = UDim2.new(1, -20, 0, 126), BackgroundColor3 = THEME.Pink, BorderSizePixel = 0, ZIndex = 7, Parent = shopScroll })
		addCorner(featuredDeal, UDim.new(0, 18))
		make("UIGradient", { Color = ColorSequence.new(THEME.Pink, THEME.Purple), Rotation = 0, Parent = featuredDeal })
		addStroke(featuredDeal, THEME.Gold, 3)
		iconBadge(featuredDeal, { Name = "Badge", Position = UDim2.new(0, 20, 0.5, -46), Size = UDim2.new(0, 92, 0, 92), ZIndex = 8 }, THEME.Gold, deal.Icon)
		label(featuredDeal, { Name = "Tag", Position = UDim2.new(0, 130, 0, 16), Size = UDim2.new(0, 300, 0, 18), Text = "★ BEST VALUE • ONE TIME ONLY", Font = FONT_HEAVY, TextSize = 15, TextColor3 = THEME.Yellow, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8 })
		label(featuredDeal, { Name = "Name", Position = UDim2.new(0, 130, 0, 36), Size = UDim2.new(0, 360, 0, 40), Text = string.upper(deal.Name), Font = FONT_TITLE, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Outline = 2 })
		label(featuredDeal, { Name = "Desc", Position = UDim2.new(0, 130, 0, 80), Size = UDim2.new(0, 380, 0, 20), Text = deal.Description, Font = FONT, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8 })
		local buyDeal = button(featuredDeal, { Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -22, 0.5, 0), Size = UDim2.new(0, 170, 0, 58), Text = ROBUX .. " " .. deal.Price, TextSize = 28, ZIndex = 8 }, "Green")
		buyDeal.Activated:Connect(function()
			local ok, message = shopFunction:InvokeServer("Product", deal.Id)
			if message and message ~= "" then
				showToast(message, if ok then "purchase" else "error")
			end
		end)
	end
end
-- Fait défiler la boutique jusqu'à une section ("Passes" ou "Products").
local function showShopTab(name)
	local header = if name == "Products" then shopSections[3] else shopSections[1]
	task.defer(function()
		pcall(function()
			shopScroll.CanvasPosition = Vector2.new(0, math.max(0, header.AbsolutePosition.Y - shopScroll.AbsolutePosition.Y + shopScroll.CanvasPosition.Y - 8))
		end)
	end)
end
showShopTab("Passes")

---------------------------------------------------------------------------
-- Paramètres
---------------------------------------------------------------------------
local settingsWindow = makeWindow("Settings", "SETTINGS", UDim2.new(0, 540, 0, 500), "⚙️")
local settingsRows = {}
local function settingsRow(index, text)
	local r = row(settingsWindow, { Name = "Row" .. index, Position = UDim2.new(0, 16, 0, 84 + (index - 1) * 64), Size = UDim2.new(1, -32, 0, 56), ZIndex = 6 })
	label(r, { Name = "Label", Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), Text = text, Font = FONT_HEAVY, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 })
	return r
end
local function musicText()
	return math.floor(settings.Music * 100 + 0.5) .. "%"
end
do
	local r = settingsRow(1, "🎵  Music volume")
	local minus = button(r, { Name = "Minus", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.new(0, 42, 0, 40), Text = "-", TextSize = 26, ZIndex = 7 }, "Purple")
	local value = label(r, { Name = "Value", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -60, 0.5, 0), Size = UDim2.new(0, 86, 0, 30), Text = "", Font = FONT_TITLE, TextSize = 20, ZIndex = 7 })
	local plus = button(r, { Name = "Plus", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 42, 0, 40), Text = "+", TextSize = 26, ZIndex = 7 }, "Purple")
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
local function showToggle(toggle, on)
	setButton(toggle, if on then "ON" else "OFF", if on then "Green" else "Gray")
end
local function toggleRow(index, text, key)
	local r = settingsRow(index, text)
	local toggle = button(r, { Name = "Toggle", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 100, 0, 40), Text = "", TextSize = 20, ZIndex = 7 }, "Green")
	settingsRows[key] = toggle
	toggle.Activated:Connect(function()
		settings[key] = not settings[key]
		applySettings()
		sendSettings()
		showToggle(toggle, settings[key])
	end)
end
toggleRow(2, "🔊  Sound effects", "Sfx")
toggleRow(3, "⌨️  Show controls", "Controls")
toggleRow(4, "⚡  Low graphics (faster)", "LowGraphics")
local settingsLobby = button(settingsWindow, { Name = "BackToLobby", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0, 260, 0, 48), Text = "🏠 Back to lobby", TextSize = 22, ZIndex = 6 }, "Blue")

local function refreshSettingsUI()
	settingsRows.Music.Text = musicText()
	for _, key in { "Sfx", "Controls", "LowGraphics" } do
		showToggle(settingsRows[key], settings[key])
	end
end

---------------------------------------------------------------------------
-- Fin de niveau
---------------------------------------------------------------------------
local completeWindow = makeWindow("Complete", "LEVEL COMPLETE!", UDim2.new(0, 540, 0, 350), "🏆")
local completeText = label(completeWindow, { Name = "Text", Position = UDim2.new(0, 24, 0, 84), Size = UDim2.new(1, -48, 0, 150), Text = "", Font = FONT_HEAVY, TextSize = 22, TextWrapped = true, ZIndex = 6 })
local replayButton = button(completeWindow, { Name = "Replay", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -22), Size = UDim2.new(0.5, -36, 0, 58), Text = "Play again", TextSize = 26, ZIndex = 6 }, "Green")
local completeLobby = button(completeWindow, { Name = "Lobby", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -22), Size = UDim2.new(0.5, -36, 0, 58), Text = "Back to lobby", TextSize = 26, ZIndex = 6 }, "Blue")

---------------------------------------------------------------------------
-- Choix du niveau (file d'attente du hall) : 3 grandes cartes illustrées, joueurs, START
---------------------------------------------------------------------------
local mapsWindow = makeWindow("Maps", "CHOOSE A LEVEL", UDim2.new(0, 900, 0, 590), "🗺️")
local selectedMap = TidyConfig.Maps[1].Id
local selectedSize = 1
local mapCards = {}
local function mapCleared(id)
	return player:GetAttribute("Cleared_" .. id) == true
end
local function mapLocked(map)
	if testUnlockAll() then
		return false
	end
	return map.Requires ~= nil and not mapCleared(map.Requires)
end
for i, map in TidyConfig.Maps do
	local card = make("TextButton", { Name = map.Id, Position = UDim2.new(0, 24 + (i - 1) * 288, 0, 86), Size = UDim2.new(0, 272, 0, 300), BackgroundColor3 = map.Color, BorderSizePixel = 0, Text = "", AutoButtonColor = true, ClipsDescendants = true, ZIndex = 6, Parent = mapsWindow })
	addCorner(card, UDim.new(0, 18))
	local stroke = addStroke(card, THEME.Edge, 3, 0.6)
	local imageId = TidyConfig.MapImages and TidyConfig.MapImages[map.Id] or ""
	if imageId ~= "" then
		-- Image importée par le créateur (voir TidyConfig.MapImages).
		make("ImageLabel", { Name = "Picture", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = imageId, ScaleType = Enum.ScaleType.Crop, ZIndex = 7, Parent = card })
	else
		-- Illustration faite avec l'interface : ciel dégradé, grande icône, nom du niveau en logo.
		make("UIGradient", { Color = ColorSequence.new(map.Color:Lerp(Color3.new(1, 1, 1), 0.45), map.Color:Lerp(Color3.new(0, 0, 0), 0.25)), Rotation = 90, Parent = card })
		label(card, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.new(0, 150, 0, 150), Text = map.Icon, TextSize = 128, ZIndex = 7 })
	end
	local logo = label(card, { Name = "Logo", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -26), Size = UDim2.new(1, -24, 0, 70), Text = map.Short or map.Name, Font = FONT_TITLE, TextScaled = true, MaxText = 58, TextColor3 = THEME.White, ZIndex = 8, Outline = 4 })
	logo.Outline.Color = map.Color:Lerp(Color3.new(0, 0, 0), 0.55)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 90)), Rotation = 90, Parent = logo })
	local number = make("Frame", { Name = "Number", Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 40, 0, 40), BackgroundColor3 = THEME.Dark, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 8, Parent = card })
	addCorner(number, UDim.new(1, 0))
	label(number, { Size = UDim2.fromScale(1, 1), Text = tostring(i), Font = FONT_TITLE, TextSize = 24, ZIndex = 9 })
	local lock = make("Frame", { Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Dark, BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false, ZIndex = 10, Parent = card })
	label(lock, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(0, 80, 0, 80), Text = "🔒", TextSize = 64, ZIndex = 11 })
	local lockText = label(lock, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.56, 0), Size = UDim2.new(0.86, 0, 0, 56), Text = "", Font = FONT_TITLE, TextSize = 22, TextWrapped = true, ZIndex = 11, Outline = 2 })
	mapCards[map.Id] = { Card = card, Stroke = stroke, Lock = lock, LockText = lockText, Map = map }
	card.Activated:Connect(function()
		if mapLocked(map) then
			local previous = TidyConfig.GetMap(map.Requires)
			showToast("🔒 Finish the " .. (previous and previous.Short or "previous level") .. " to unlock it!", "error")
			return
		end
		selectedMap = map.Id
		queueEvent:FireServer("Configure", selectedMap, selectedSize)
	end)
end
label(mapsWindow, { Name = "PlayersLabel", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 398), Size = UDim2.new(0, 300, 0, 30), Text = "Players", Font = FONT_TITLE, TextSize = 26, ZIndex = 6, Outline = 1.5 })
local sizeButtons = {}
for size = 1, TidyConfig.MaxPartySize do
	local b = button(mapsWindow, { Name = "Size" .. size, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, (size - (TidyConfig.MaxPartySize + 1) / 2) * 76, 0, 434), Size = UDim2.new(0, 62, 0, 50), Text = tostring(size), TextSize = 26, ZIndex = 6 }, "Gray")
	b.UICorner.CornerRadius = UDim.new(1, 0)
	sizeButtons[size] = b
	b.Activated:Connect(function()
		selectedSize = size
		queueEvent:FireServer("Configure", selectedMap, selectedSize)
	end)
end
local mapsStart = button(mapsWindow, { Name = "Start", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.new(0, 300, 0, 64), Text = "START", TextSize = 36, ZIndex = 6 }, "Green")
local mapsLeave = button(mapsWindow, { Name = "Leave", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -26), Size = UDim2.new(0, 130, 0, 46), Text = "Leave", TextSize = 21, ZIndex = 6 }, "Red")
local mapsStatus = label(mapsWindow, { Name = "Status", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -36), Size = UDim2.new(0, 190, 0, 24), Text = "", Font = FONT_TITLE, TextSize = 19, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6 })

---------------------------------------------------------------------------
-- Rejoindre un ami avec un code
---------------------------------------------------------------------------
local joinWindow = makeWindow("Join", "JOIN A FRIEND", UDim2.new(0, 480, 0, 300), "🤝")
label(joinWindow, { Name = "Help", Position = UDim2.new(0, 24, 0, 80), Size = UDim2.new(1, -48, 0, 44), Text = "Ask your friend for the 6-character code shown on their screen.", TextWrapped = true, Font = FONT_LIGHT, TextSize = 17, TextColor3 = THEME.Muted, ZIndex = 6 })
local codeBox = make("TextBox", { Name = "Code", Position = UDim2.new(0, 24, 0, 134), Size = UDim2.new(1, -48, 0, 56), BackgroundColor3 = THEME.Dark, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "", PlaceholderText = "ABC123", PlaceholderColor3 = THEME.Muted, Font = FONT_TITLE, TextSize = 30, TextColor3 = THEME.White, ClearTextOnFocus = false, ZIndex = 6, Parent = joinWindow })
addCorner(codeBox, UDim.new(0, 12))
addStroke(codeBox, THEME.Gold, 2)
local joinButton = button(joinWindow, { Name = "Join", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.new(0, 220, 0, 54), Text = "JOIN", TextSize = 28, ZIndex = 6 }, "Green")

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
		local selected = equippedTool == tool.Id
		slot.Stroke.Color = if selected then THEME.Gold else THEME.Edge
		slot.Stroke.Transparency = if selected then 0 else 0.8
		slot.Stroke.Thickness = if selected then 4 else 2
		slot.Button.BackgroundColor3 = if selected then Color3.fromRGB(86, 78, 160) else THEME.Panel
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
		hud.Hint.Visible = false
		return
	end
	hud.Hint.Visible = true
	if finished then
		hud.Hint.Text = "✨ Everything is spotless!"
		return
	end
	local carrying = player:GetAttribute("Carrying") or ""
	local info = TidyConfig.ItemTypes[carrying]
	if info then
		hud.Hint.Text = info.Icon .. "  " .. info.Hint
	else
		hud.Hint.Text = if isTouchOnly then "👆  Tap an item to pick it up" else "🖱️  Click an item to pick it up"
	end
end

local function updatePoints()
	local points = player:GetAttribute("Points") or 0
	hud.Points.Text = fmt(points)
	local wins = player:GetAttribute("Wins") or 0
	hud.Rank.Text = (player:GetAttribute("Rank") or "Intern") .. "  •  🏆 " .. wins .. (if wins == 1 then " win" else " wins")
	upgradesPoints.Text = "🪙 " .. fmt(points)
	for id, row in upgradeRows do
		local levelValue = player:GetAttribute("Level_" .. id) or 0
		local upgrade = row.Upgrade
		if levelValue >= upgrade.MaxLevel then
			setButton(row.Buy, "MAX", "Gold")
		else
			local cost = TidyConfig.GetUpgradeCost(upgrade, levelValue)
			setButton(row.Buy, "🪙 " .. fmt(cost), if points >= cost then "Green" else "Gray")
		end
		for level, pip in row.Pips do
			local reached = level <= levelValue
			pip.BackgroundColor3 = if reached then THEME.Gold else THEME.White
			pip.BackgroundTransparency = if reached then 0 else 0.8
		end
		row.LevelText.Text = if upgrade.MaxLevel == 1 then (if levelValue >= 1 then "OWNED" else "") else (levelValue .. "/" .. upgrade.MaxLevel)
	end
	for _, tile in shopTiles do
		local owned = false
		if tile.Kind == "Pass" then
			owned = player:GetAttribute("Pass_" .. tile.Entry.Id) == true
		elseif tile.Entry.OneTime then
			owned = player:GetAttribute("DealBought") == true
		end
		setButton(tile.Buy, if owned then "OWNED" else (ROBUX .. " " .. tile.Entry.Price), if owned then "Gray" else "Green")
		tile.Buy.Active = not owned
	end
	if featuredDeal then
		featuredDeal.Visible = player:GetAttribute("DealBought") ~= true
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

-- Les places libres ne sont recalculées que si l'objet porté change ou si une place se remplit
-- (avant : toutes les places du niveau à chaque passage, ce qui faisait ramer les grands niveaux).
local slotsDirty = true
local lastSlotKey = ""
local MAX_ZONE_HIGHLIGHTS = 10
local function refreshWorld()
	local carrying = player:GetAttribute("Carrying") or ""
	local carryingCategory = player:GetAttribute("CarryingCategory") or ""
	local key = carrying .. "|" .. carryingCategory
	if slotsDirty or key ~= lastSlotKey then
		slotsDirty = false
		lastSlotKey = key
		for _, slot in CollectionService:GetTagged(TidyConfig.SlotTag) do
			if slot:IsA("BasePart") then
				local matches = carrying ~= "" and slot:GetAttribute("ItemType") == carrying and slot:GetAttribute("Occupied") ~= true
				if matches then
					local slotCategory = slot:GetAttribute("Category")
					matches = slotCategory == nil or slotCategory == carryingCategory
				end
				local wanted = if matches then GHOST_TRANSPARENCY else 1
				if slot.Transparency ~= wanted then
					slot.Transparency = wanted
				end
			end
		end
	end
	local root = getRoot()
	local highlighted = 0
	local nearestBoards, boardStates = {}, {}
	for _, zone in CollectionService:GetTagged(TidyConfig.ZoneTag) do
		local distance = math.huge
		if root then
			local ok, pivot = pcall(zone.GetPivot, zone)
			if ok then
				distance = (pivot.Position - root.Position).Magnitude
			end
		end
		local zoneCategory = zone:GetAttribute("Category")
		local matches = carrying ~= "" and zone:GetAttribute("ItemType") == carrying and (zoneCategory == nil or zoneCategory == carryingCategory)
		-- Contour vert seulement sur les meubles proches (les contours coûtent cher à afficher).
		local wantHighlight = matches and distance < 110 and highlighted < MAX_ZONE_HIGHLIGHTS
		if wantHighlight then
			highlighted += 1
		end
		local highlight = zoneHighlights[zone]
		if wantHighlight and (not highlight or highlight.Parent ~= zone) then
			zoneHighlights[zone] = make("Highlight", { Name = "ZoneHighlight", FillColor = THEME.Green, FillTransparency = 0.85, OutlineColor = Color3.fromRGB(120, 255, 140), OutlineTransparency = 0.1, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = zone })
		elseif not wantHighlight and highlight then
			highlight:Destroy()
			zoneHighlights[zone] = nil
		end
		-- Panneaux : un seul par groupe de meubles identiques (le plus proche), caché quand on est collé
		-- au meuble ; vert quand on porte le bon objet.
		local billboard = zone:FindFirstChild("CategoryBillboard")
		if billboard and billboard:IsA("BillboardGui") then
			local key = (zone:GetAttribute("ItemType") or "") .. "|" .. tostring(zoneCategory)
			local limit = if matches then 90 else 45
			if distance > 6 and distance < limit then
				local best = nearestBoards[key]
				if not best or distance < best.Distance then
					nearestBoards[key] = { Zone = zone, Distance = distance }
				end
			end
			boardStates[zone] = { Billboard = billboard, Matches = matches, Key = key }
		end
	end
	for zone, info in boardStates do
		local best = nearestBoards[info.Key]
		local show = best ~= nil and best.Zone == zone
		if info.Billboard.Enabled ~= show then
			info.Billboard.Enabled = show
		end
		local panel = info.Billboard:FindFirstChild("Panel")
		local wanted = if info.Matches then Color3.fromRGB(30, 150, 80) else Color3.fromRGB(28, 30, 70)
		if panel and panel.BackgroundColor3 ~= wanted then
			panel.BackgroundColor3 = wanted
		end
	end
end

local refreshQueued = false
local function requestRefresh()
	slotsDirty = true
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
	return false
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
	hud.RoomCode.Visible = playing and hud.RoomCode.Text ~= ""
	hud.Deal.Position = if playing then UDim2.new(1, -20, 0, 134) else UDim2.new(1, -20, 0, 12)
	if not playing then
		hud.ItemCard.Visible = false
		hud.TouchBar.Visible = false
		tutorialSurface.Enabled = false
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

-- Accroche le tutoriel au panneau du niveau (il peut arriver un peu après, à cause du chargement par zones).
local tutorialToken = 0
local function showTutorial()
	tutorialToken += 1
	local token = tutorialToken
	tutorialSurface.Enabled = false
	task.spawn(function()
		for _ = 1, 40 do
			if token ~= tutorialToken or not inMap() then
				return
			end
			local level = Workspace:FindFirstChild("TidyLevel")
			local board = level and level:FindFirstChild("TutorialBoard", true)
			if board and board:IsA("BasePart") then
				tutorialSurface.Adornee = board
				tutorialSurface.Enabled = true
				return
			end
			task.wait(0.5)
		end
	end)
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
		setBanner(if inMap() then "" else "Step on a green pad to play!")
		return
	end
	local pad = findPad(padIndex)
	local mapId = pad and pad:GetAttribute("QueueMap") or ""
	local count = pad and pad:GetAttribute("QueueCount") or 1
	local size = pad and pad:GetAttribute("QueueSize") or 1
	local countdown = pad and pad:GetAttribute("QueueCountdown") or -1
	local map = TidyConfig.GetMap(mapId)
	local countdownText = if countdown >= 0 then ("  •  Starting in " .. countdown .. "...") else ""
	setBanner("")
	if isHost then
		-- La fenêtre s'ouvre une fois quand on devient chef de groupe (on peut la fermer ensuite).
		if mapsShownForPad ~= padIndex then
			mapsShownForPad = padIndex
			closeAllWindows("Maps")
			mapsWindow.Visible = true
		end
		local wins = player:GetAttribute("Wins") or 0
		for id, card in mapCards do
			card.Lock.Visible = mapLocked(card.Map)
			local previous = card.Map.Requires and TidyConfig.GetMap(card.Map.Requires)
			card.LockText.Text = if previous then ("Finish the " .. previous.Short .. " to unlock") else ""
			card.Stroke.Color = if id == mapId then THEME.Green else THEME.Edge
			card.Stroke.Transparency = if id == mapId then 0 else 0.6
			card.Stroke.Thickness = if id == mapId then 6 else 3
		end
		for s, b in sizeButtons do
			local active = s == size and map ~= nil
			setButton(b, nil, if active then "Gold" else "Gray")
		end
		setButton(mapsStart, nil, if map then "Green" else "Gray")
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
	elseif input.KeyCode == Enum.KeyCode.R then
		openWindow("Settings")
	elseif input.KeyCode == Enum.KeyCode.Y then
		freeMouse = not freeMouse
	elseif input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.Semicolon then
		musicMuted = not musicMuted
		applySettings()
		showToast(if musicMuted then "Music muted" else "Music on", "info")
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
	if gameProcessed or #touchPositions == 0 then
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
		local kind, itemId = prompt:GetAttribute("ShopKind"), prompt:GetAttribute("ShopItem")
		showShopTab(if kind == "Product" then "Products" else "Passes")
		if type(kind) == "string" and type(itemId) == "string" then
			local ok, message = shopFunction:InvokeServer(kind, itemId)
			if message and message ~= "" then
				showToast(message, if ok then "purchase" else "error")
			end
		end
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
		hud.TimerText.Text = formatTime(elapsed())
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

-- Petit son quand un objet arrive dans le panier.
local lastHeldCount = 0
local function playPickSound()
	if not settings.Sfx then
		return
	end
	local sound = make("Sound", { Name = "PickSound", SoundId = "rbxasset://sounds/clickfast.wav", Volume = 0.35, PlaybackSpeed = 1.1 + math.random() * 0.2, Parent = SoundService })
	sound:Play()
	Debris:AddItem(sound, 1)
end
player:GetAttributeChangedSignal("Held"):Connect(function()
	local count = #heldTypes()
	if count > lastHeldCount then
		playPickSound()
	end
	lastHeldCount = count
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
		hud.TimerText.Text = "00:00"
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
player:GetAttributeChangedSignal("Settings"):Connect(updateSettingsFromServer)
ReplicatedStorage:GetAttributeChangedSignal("ActiveMap"):Connect(updateMusic)
player:GetAttributeChangedSignal("InMap"):Connect(function()
	updateMusic()
	updateMode()
	updateQueueUI()
end)
for _, name in { "QueuePad", "QueueHost", "Cleared_Warehouse", "Cleared_Agency", "Cleared_Headquarters" } do
	player:GetAttributeChangedSignal(name):Connect(updateQueueUI)
end
for _, name in { "TidyTotal", "TidyRemaining" } do
	ReplicatedStorage:GetAttributeChangedSignal(name):Connect(updateCounters)
end
ReplicatedStorage:GetAttributeChangedSignal("RoundNumber"):Connect(function()
	finished = false
	timerStart, timerStopped = nil, nil
	hud.TimerText.Text = "00:00"
	completeWindow.Visible = false
	updateCounters()
	updateHint()
	requestRefresh()
end)
local function updateRoomCode()
	local code = ReplicatedStorage:GetAttribute("RoomCode")
	hud.RoomCode.Text = if type(code) == "string" and code ~= "" then ("Friends code: " .. code) else ""
	hud.RoomCode.Visible = hud.RoomCode.Text ~= "" and inMap()
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

updateMusic()
updateUiScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateUiScale)
end
updateSettingsFromServer()
updateCounters()
updatePoints()
updateTools()
updateRoomCode()
updateMode()
updateQueueUI()
