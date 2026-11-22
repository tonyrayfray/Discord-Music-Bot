--[[
	Tycoon claiming (server)

	Players pick a free tycoon from the menu shown when they join
	(see src/client/TycoonMenu.client.luau). This script:
	  - finds every tycoon in Workspace
	  - tells clients which tycoons are free or taken
	  - checks and handles claim requests

	A tycoon is any folder/model in Workspace that has a "...Values" folder
	(e.g. "OneValues") containing Claimed, Owner and Number values,
	like the "A" tycoon.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Settings
local TELEPORT_ON_CLAIM = true -- move the player to the tycoon's SpawnPoint after claiming
local PLAYER_DATA_TIMEOUT = 10 -- seconds to wait for a player's TycoonInfo to load

-- Remotes (created here so the client can find them in ReplicatedStorage)
local remotes = Instance.new("Folder")
remotes.Name = "TycoonRemotes"

local getTycoons = Instance.new("RemoteFunction")
getTycoons.Name = "GetTycoons"
getTycoons.Parent = remotes

local claimTycoon = Instance.new("RemoteFunction")
claimTycoon.Name = "ClaimTycoon"
claimTycoon.Parent = remotes

local tycoonsChanged = Instance.new("RemoteEvent")
tycoonsChanged.Name = "TycoonsChanged"
tycoonsChanged.Parent = remotes

remotes.Parent = ReplicatedStorage

-- [tycoon] = its Values folder
local tycoons = {}

local function isValuesFolder(instance)
	return instance.Name:sub(-6) == "Values"
		and instance:FindFirstChild("Claimed") ~= nil
		and instance:FindFirstChild("Owner") ~= nil
		and instance:FindFirstChild("Number") ~= nil
end

local function findClaimPart(tycoon)
	for _, child in tycoon:GetChildren() do
		if child:IsA("BasePart") and child.Name:sub(-5) == "Claim" then
			return child
		end
	end
	return nil
end

local function getTycoonList()
	local list = {}
	for tycoon, values in tycoons do
		local claimed = values.Claimed.Value
		table.insert(list, {
			tycoon = tycoon,
			name = tycoon.Name,
			claimed = claimed,
			owner = if claimed then tostring(values.Owner.Value) else nil,
		})
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

local function getPlayerClaimedValue(player)
	local info = player:WaitForChild("TycoonInfo", PLAYER_DATA_TIMEOUT)
	return info and info:FindFirstChild("Claimed")
end

-- Same steps the old touch-to-claim script did after a claim.
local function buildTycoon(tycoon, values)
	local claimPart = findClaimPart(tycoon)
	if claimPart then
		claimPart:Destroy()
	end

	local firstFloor = ServerStorage:WaitForChild(tostring(values.Number.Value)).Floors.FirstFloor:Clone()
	firstFloor.Parent = tycoon.Floors
end

local function sendToTycoon(player, tycoon)
	local spawnPoint = tycoon:FindFirstChild("SpawnPoint")
	local character = player.Character
	if spawnPoint and spawnPoint:IsA("BasePart") and character then
		character:PivotTo(spawnPoint.CFrame + Vector3.new(0, 5, 0))
	end
end

getTycoons.OnServerInvoke = function(player)
	local playerClaimed = getPlayerClaimedValue(player)
	return {
		alreadyClaimed = playerClaimed ~= nil and playerClaimed.Value,
		tycoons = getTycoonList(),
	}
end

claimTycoon.OnServerInvoke = function(player, tycoon)
	local values = if typeof(tycoon) == "Instance" then tycoons[tycoon] else nil
	if not values then
		return false, "That tycoon doesn't exist."
	end

	local playerClaimed = getPlayerClaimedValue(player)
	if not playerClaimed then
		return false, "Your data hasn't loaded yet. Try again in a moment."
	end

	-- Nothing below yields until the claim is recorded, so two players
	-- can't grab the same tycoon at once.
	if playerClaimed.Value then
		return false, "You already have a tycoon."
	end
	if values.Claimed.Value then
		return false, "Someone already claimed that tycoon."
	end

	print(player.Name .. " has claimed their Tycoon!")
	playerClaimed.Value = true
	values.Owner.Value = player.Name
	values.Claimed.Value = true

	buildTycoon(tycoon, values)

	if TELEPORT_ON_CLAIM then
		sendToTycoon(player, tycoon)
	end

	return true
end

-- Find tycoons and keep every open menu up to date when one is claimed or reset.
for _, instance in workspace:GetDescendants() do
	if instance:IsA("Folder") and isValuesFolder(instance) then
		tycoons[instance.Parent] = instance
		instance.Claimed.Changed:Connect(function()
			tycoonsChanged:FireAllClients(getTycoonList())
		end)
	end
end

if next(tycoons) == nil then
	warn("TycoonClaim: no tycoons found in Workspace.")
end
