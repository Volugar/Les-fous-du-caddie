-- TidyUI (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts
-- Player interface: counter of objects left, instructions, welcome and
-- completion messages. Also shows only the useful prompts and makes the
-- right places glow when the player carries an object.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TidyConfig = require(ReplicatedStorage:WaitForChild("TidyConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------------
-- Interface building helpers
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

-- Centered message window (welcome and completion).
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
-- Build the interface
---------------------------------------------------------------------------

local screenGui = make("ScreenGui", {
	Name = "TidyGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

-- Counter (top of the screen).
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
	Text = "Items left to put away: ...",
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

-- Instruction line (just below the counter).
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

-- Welcome and completion windows.
local introPanel, _, _, introButton = makeMessagePanel(
	"Welcome",
	"Welcome to the agency",
	"The "
		.. TidyConfig.AgencyName
		.. " opens soon, but the office is a mess. Folders, papers, chairs and boxes have been left everywhere.\n\nPut every item back where it belongs.",
	"Start"
)
introPanel.Parent = screenGui
introPanel.Visible = true

local completePanel, _, completeBody, completeButton = makeMessagePanel(
	"Complete",
	"The agency is in order.",
	"",
	"Close"
)
completePanel.Parent = screenGui

introButton.Activated:Connect(function()
	introPanel.Visible = false
end)
completeButton.Activated:Connect(function()
	completePanel.Visible = false
end)

---------------------------------------------------------------------------
-- Counter, instructions and completion
---------------------------------------------------------------------------

local finished = false
local lastRemaining = nil

local function updateHint()
	if finished then
		hintLabel.Text = "Everything is in its place."
		return
	end
	local carrying = player:GetAttribute("Carrying") or ""
	local typeInfo = TidyConfig.ItemTypes[carrying]
	if typeInfo then
		hintLabel.Text = "Carrying: " .. typeInfo.DisplayName .. ". " .. typeInfo.Hint
	else
		hintLabel.Text = "Find the items that are out of place and pick them up."
	end
end

local function showCompletion(total)
	if finished then
		return
	end
	finished = true
	introPanel.Visible = false
	completeBody.Text = "All "
		.. total
		.. " items have been put away.\n\nThe office is ready to welcome job seekers. Thank you for your work."
	completePanel.Visible = true
	updateHint()
end

local function updateCounter()
	local total = ReplicatedStorage:GetAttribute("TidyTotal")
	local remaining = ReplicatedStorage:GetAttribute("TidyRemaining")
	if typeof(total) ~= "number" or typeof(remaining) ~= "number" then
		return
	end

	countLabel.Text = "Items left to put away: " .. remaining

	local progress = 0
	if total > 0 then
		progress = (total - remaining) / total
	end
	TweenService:Create(progressFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(progress, 1),
	}):Play()

	-- Short green flash when an object has just been put away.
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
-- Prompts and glowing places
---------------------------------------------------------------------------

local GHOST_TRANSPARENCY = 0.6

local function refreshWorld()
	local carrying = player:GetAttribute("Carrying") or ""
	local handsFree = carrying == ""

	-- Objects: can be picked up only when the hands are free.
	for _, item in CollectionService:GetTagged(TidyConfig.ItemTag) do
		local prompt = item:FindFirstChild("PickupPrompt", true)
		if prompt then
			prompt.Enabled = handsFree and item:GetAttribute("State") == "Loose"
		end
	end

	-- Places: visible and usable only for the type of object being carried.
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

-- Groups many refresh requests into a single refresh.
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

-- Safety net: refresh regularly in case something arrived late.
task.spawn(function()
	while true do
		task.wait(1)
		refreshWorld()
	end
end)

updateCounter()
updateHint()
refreshWorld()
