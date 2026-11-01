-- TidyUI (LocalScript)
-- Emplacement : StarterPlayer > StarterPlayerScripts
-- Interface du joueur : compteur d'objets restants, consignes, messages d'accueil
-- et de fin. Affiche aussi seulement les boutons utiles et fait briller les
-- bons emplacements quand le joueur porte un objet.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TidyConfig = require(ReplicatedStorage:WaitForChild("TidyConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------------
-- Fonctions pour construire l'interface
---------------------------------------------------------------------------

local TEXT_COLOR = Color3.fromRGB(240, 240, 240)
local MUTED_COLOR = Color3.fromRGB(165, 172, 184)
local PANEL_COLOR = Color3.fromRGB(24, 27, 32)
local ACCENT_COLOR = Color3.fromRGB(90, 190, 120)

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
	make("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.85, Thickness = 1, Parent = parent })
end

local function makeLabel(parent, properties)
	properties.Parent = parent
	properties.BackgroundTransparency = 1
	properties.TextScaled = true
	properties.TextWrapped = true
	properties.TextColor3 = properties.TextColor3 or TEXT_COLOR
	properties.Font = properties.Font or Enum.Font.Gotham
	local maxSize = properties.MaxTextSize
	properties.MaxTextSize = nil
	local label = make("TextLabel", properties)
	if maxSize then
		make("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = label })
	end
	return label
end

local function makeButton(parent, text)
	local button = make("TextButton", {
		Name = "Button",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, 160, 0, 40),
		BackgroundColor3 = ACCENT_COLOR,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = Color3.fromRGB(20, 30, 24),
		TextSize = 18,
		Parent = parent,
	})
	addCorner(button, 6)
	return button
end

-- Fenêtre de message centrée (accueil et fin).
local function makeMessagePanel(name, titleText, bodyText, buttonText)
	local panel = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 230),
		BackgroundColor3 = PANEL_COLOR,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = nil,
	})
	make("UISizeConstraint", { MaxSize = Vector2.new(480, 230), Parent = panel })
	addCorner(panel, 10)
	addStroke(panel)

	local title = makeLabel(panel, {
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
		Text = bodyText,
		TextColor3 = MUTED_COLOR,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 18,
	})
	local button = makeButton(panel, buttonText)
	return panel, title, body, button
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

-- Compteur (en haut de l'écran).
local counterFrame = make("Frame", {
	Name = "Counter",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0.9, 0, 0, 66),
	BackgroundColor3 = PANEL_COLOR,
	BackgroundTransparency = 0.1,
	Parent = screenGui,
})
make("UISizeConstraint", { MaxSize = Vector2.new(420, 66), Parent = counterFrame })
addCorner(counterFrame, 8)
addStroke(counterFrame)

makeLabel(counterFrame, {
	Name = "AgencyName",
	Position = UDim2.new(0, 14, 0, 7),
	Size = UDim2.new(1, -28, 0, 15),
	Font = Enum.Font.GothamMedium,
	Text = string.upper(TidyConfig.AgencyName),
	TextColor3 = MUTED_COLOR,
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxTextSize = 13,
})

local countLabel = makeLabel(counterFrame, {
	Name = "Count",
	Position = UDim2.new(0, 14, 0, 24),
	Size = UDim2.new(1, -28, 0, 26),
	Font = Enum.Font.GothamBold,
	Text = "Objets restants à ranger : ...",
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxTextSize = 22,
})

local progressBack = make("Frame", {
	Name = "ProgressBack",
	Position = UDim2.new(0, 14, 1, -11),
	Size = UDim2.new(1, -28, 0, 4),
	BackgroundColor3 = Color3.fromRGB(60, 64, 72),
	BorderSizePixel = 0,
	Parent = counterFrame,
})
addCorner(progressBack, 2)
local progressFill = make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = ACCENT_COLOR,
	BorderSizePixel = 0,
	Parent = progressBack,
})
addCorner(progressFill, 2)

-- Ligne de consigne (juste sous le compteur).
local hintFrame = make("Frame", {
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 82),
	Size = UDim2.new(0.9, 0, 0, 34),
	BackgroundColor3 = PANEL_COLOR,
	BackgroundTransparency = 0.3,
	Parent = screenGui,
})
make("UISizeConstraint", { MaxSize = Vector2.new(520, 34), Parent = hintFrame })
addCorner(hintFrame, 6)

local hintLabel = makeLabel(hintFrame, {
	Name = "Text",
	Position = UDim2.new(0, 12, 0, 4),
	Size = UDim2.new(1, -24, 1, -8),
	Text = "",
	MaxTextSize = 16,
})

-- Fenêtres d'accueil et de fin.
local introPanel, _, _, introButton = makeMessagePanel(
	"Welcome",
	"Bienvenue à l'agence",
	"L'"
		.. TidyConfig.AgencyName
		.. " ouvre bientôt, mais les bureaux sont en désordre. Des dossiers, des papiers, des chaises et des cartons traînent partout.\n\nRemettez chaque objet à sa place.",
	"Commencer"
)
introPanel.Parent = screenGui
introPanel.Visible = true

local completePanel, _, completeBody, completeButton = makeMessagePanel(
	"Complete",
	"L'agence est en ordre.",
	"",
	"Fermer"
)
completePanel.Parent = screenGui

introButton.Activated:Connect(function()
	introPanel.Visible = false
end)
completeButton.Activated:Connect(function()
	completePanel.Visible = false
end)

---------------------------------------------------------------------------
-- Compteur, consignes et fin de partie
---------------------------------------------------------------------------

local finished = false
local lastRemaining = nil

local function updateHint()
	if finished then
		hintLabel.Text = "Tout est à sa place."
		return
	end
	local carrying = player:GetAttribute("Carrying") or ""
	local typeInfo = TidyConfig.ItemTypes[carrying]
	if typeInfo then
		hintLabel.Text = "Vous portez : " .. typeInfo.DisplayName .. ". " .. typeInfo.Hint
	else
		hintLabel.Text = "Trouvez les objets mal rangés et ramassez-les."
	end
end

local function showCompletion(total)
	if finished then
		return
	end
	finished = true
	introPanel.Visible = false
	completeBody.Text = "Les "
		.. total
		.. " objets ont été rangés.\n\nLes bureaux sont prêts à accueillir les demandeurs d'emploi. Merci pour votre travail."
	completePanel.Visible = true
	updateHint()
end

local function updateCounter()
	local total = ReplicatedStorage:GetAttribute("TidyTotal")
	local remaining = ReplicatedStorage:GetAttribute("TidyRemaining")
	if typeof(total) ~= "number" or typeof(remaining) ~= "number" then
		return
	end

	countLabel.Text = "Objets restants à ranger : " .. remaining

	local progress = 0
	if total > 0 then
		progress = (total - remaining) / total
	end
	TweenService:Create(progressFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(progress, 1),
	}):Play()

	-- Bref flash vert quand un objet vient d'être rangé.
	if lastRemaining and remaining < lastRemaining then
		countLabel.TextColor3 = ACCENT_COLOR
		TweenService:Create(countLabel, TweenInfo.new(0.8), { TextColor3 = TEXT_COLOR }):Play()
	end
	lastRemaining = remaining

	if total > 0 and remaining <= 0 then
		showCompletion(total)
	end
end

---------------------------------------------------------------------------
-- Boutons d'action et emplacements lumineux
---------------------------------------------------------------------------

local GHOST_TRANSPARENCY = 0.6

local function refreshWorld()
	local carrying = player:GetAttribute("Carrying") or ""
	local handsFree = carrying == ""

	-- Objets : on ne peut les ramasser que les mains libres.
	for _, item in CollectionService:GetTagged(TidyConfig.ItemTag) do
		local prompt = item:FindFirstChild("PickupPrompt", true)
		if prompt then
			prompt.Enabled = handsFree and item:GetAttribute("State") == "Loose"
		end
	end

	-- Emplacements : visibles et utilisables seulement pour le type d'objet porté.
	for _, slot in CollectionService:GetTagged(TidyConfig.SlotTag) do
		local matches = not handsFree
			and slot:GetAttribute("ItemType") == carrying
			and slot:GetAttribute("Occupied") ~= true
		local prompt = slot:FindFirstChild("PlacePrompt")
		if prompt then
			prompt.Enabled = matches
		end
		if slot:IsA("BasePart") then
			slot.Transparency = if matches then GHOST_TRANSPARENCY else 1
		end
	end
end

-- Regroupe plusieurs demandes de mise à jour en une seule.
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

local function watchTagged(instance)
	instance:GetAttributeChangedSignal("State"):Connect(requestRefresh)
	instance:GetAttributeChangedSignal("Occupied"):Connect(requestRefresh)
	instance.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			requestRefresh()
		end
	end)
	requestRefresh()
end

for _, tag in { TidyConfig.ItemTag, TidyConfig.SlotTag } do
	for _, instance in CollectionService:GetTagged(tag) do
		watchTagged(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(watchTagged)
end

player:GetAttributeChangedSignal("Carrying"):Connect(function()
	requestRefresh()
	updateHint()
end)
ReplicatedStorage:GetAttributeChangedSignal("TidyRemaining"):Connect(updateCounter)
ReplicatedStorage:GetAttributeChangedSignal("TidyTotal"):Connect(updateCounter)

-- Filet de sécurité : mise à jour régulière au cas où quelque chose arrive en retard.
task.spawn(function()
	while true do
		task.wait(1)
		refreshWorld()
	end
end)

updateCounter()
updateHint()
refreshWorld()
