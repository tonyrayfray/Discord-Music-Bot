--[[
	Tycoon menu (client)

	Shows a list of tycoons when the player joins. Clicking a free one asks
	the server to claim it (see src/server/TycoonClaim.server.luau).
	The menu closes once the claim succeeds, and is skipped if the player
	already has a tycoon.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TycoonRemotes")
local getTycoons = remotes:WaitForChild("GetTycoons")
local claimTycoon = remotes:WaitForChild("ClaimTycoon")
local tycoonsChanged = remotes:WaitForChild("TycoonsChanged")

local FREE_COLOR = Color3.fromRGB(46, 160, 67)
local TAKEN_COLOR = Color3.fromRGB(80, 80, 80)
local PANEL_COLOR = Color3.fromRGB(30, 30, 35)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)

local data = getTycoons:InvokeServer()
if data.alreadyClaimed then
	return
end

-- Build the menu
local gui = Instance.new("ScreenGui")
gui.Name = "TycoonMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.4
backdrop.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.9, 0.75)
panel.BackgroundColor3 = PANEL_COLOR
panel.Parent = backdrop
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(380, 460)
sizeLimit.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 16)
padding.PaddingBottom = UDim.new(0, 16)
padding.PaddingLeft = UDim.new(0, 16)
padding.PaddingRight = UDim.new(0, 16)
padding.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextColor3 = TEXT_COLOR
title.Text = "Choose your Tycoon"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Position = UDim2.new(0, 0, 0, 40)
status.Size = UDim2.new(1, 0, 0, 22)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 16
status.TextColor3 = Color3.fromRGB(200, 200, 200)
status.TextWrapped = true
status.Text = ""
status.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.new(0, 0, 0, 70)
list.Size = UDim2.new(1, 0, 1, -70)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

-- Behaviour
local busy = false
local changedConnection

local function claim(tycoon)
	if busy then
		return
	end
	busy = true
	status.Text = "Claiming..."

	local success, ok, message = pcall(claimTycoon.InvokeServer, claimTycoon, tycoon)
	busy = false

	if success and ok then
		changedConnection:Disconnect()
		gui:Destroy()
	else
		status.Text = if success then message else "Something went wrong. Try again."
	end
end

local function render(tycoonList)
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local anyFree = false
	for index, info in tycoonList do
		local button = Instance.new("TextButton")
		button.LayoutOrder = index
		button.Size = UDim2.new(1, -8, 0, 48)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 18
		button.TextColor3 = TEXT_COLOR
		button.AutoButtonColor = not info.claimed
		button.BackgroundColor3 = if info.claimed then TAKEN_COLOR else FREE_COLOR
		button.Text = if info.claimed
			then `Tycoon {info.name}  -  {info.owner}`
			else `Tycoon {info.name}  -  Free`
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
		button.Parent = list

		if not info.claimed then
			anyFree = true
			button.Activated:Connect(function()
				claim(info.tycoon)
			end)
		end
	end

	if not busy then
		status.Text = if anyFree then "Pick a free tycoon." else "All tycoons are taken. Waiting for one to open up..."
	end
end

changedConnection = tycoonsChanged.OnClientEvent:Connect(render)
render(data.tycoons)
gui.Parent = player:WaitForChild("PlayerGui")
