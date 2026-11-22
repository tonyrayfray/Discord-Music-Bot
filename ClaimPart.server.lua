-- Tycoon claim pad: the first player to touch it (who hasn't claimed a tycoon yet)
-- becomes the owner, and the tycoon's first floor is spawned in.

-- Services
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

-- Not used yet; kept for future saving.
local tycoonDataStore = DataStoreService:GetDataStore("Beta0.0.0")

-- References
local claimPart = script.Parent
local tycoon = claimPart.Parent
local values = tycoon.OneValues
local tycoonNumber = values.Number

local function claim()
	-- values.scr.Enabled = true

	claimPart.Transparency = 1
	claimPart.ClaimText.ClaimGui.Claim.Text = ""

	local firstFloor = ServerStorage:WaitForChild(tycoonNumber.Value).Floors.FirstFloor:Clone()
	firstFloor.Parent = tycoon.Floors

	claimPart:Destroy()
end

claimPart.Touched:Connect(function(hit)
	local character = hit.Parent
	if not character:FindFirstChild("Humanoid") then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local playerClaimed = player:FindFirstChild("TycoonInfo").Claimed

	if not values.Claimed.Value and not playerClaimed.Value then
		print(player.Name .. " has claimed their Tycoon!")

		playerClaimed.Value = true
		values.Owner.Value = character.Name
		values.Claimed.Value = true

		claim()
	else
		task.wait(5)
		warn(player.Name .. " has already claimed their Tycoon.")
	end
end)
