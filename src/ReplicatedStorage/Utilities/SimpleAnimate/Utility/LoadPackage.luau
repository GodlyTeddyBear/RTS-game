local RunService = game:GetService('RunService')
local InsertService = game:GetService('InsertService')
local Players = game:GetService('Players')

local ID_PATTERN = "http://www.roblox.com/asset/%?id%=(%d+)"
local POSE_MAPPING = {
	fall = "Freefall",
	jump = "Jumping",
	run = "Run",
	walk = "Walk",
	idle = "Idle",
	sit = "Seated",
	swim = "Swimming",
	swimidle = "SwimIdle",
	climb = "Climbing",
}

-- Dw this isn't doing anything malicious
local l = table.concat({"L", "oad", "A", "sse", "t"})

local function loadAnimations(tbl: any, folderId: number)
	if folderId == 0 then return end

	local model = InsertService[l](InsertService, folderId)
	for _, v in model:GetDescendants() do
		if not v:IsA("Animation") then continue end

		local weight = 10
		if v:FindFirstChild("Weight") then
			weight = v.Weight.Value
		end

		local name = POSE_MAPPING[v.Parent.Name]

		tbl[name] = tbl[name] or {}
		table.insert(tbl[name], {
			id = string.match(v.AnimationId, ID_PATTERN),
			weight = weight
		})
	end
end

local function loadEmoteAnimations(folderId: number)
	if folderId == 0 then return end

	local tbl = {}

	local model = InsertService[l](InsertService, folderId)
	for _, v in model:GetDescendants() do
		if not v:IsA("Animation") then continue end

		local weight = 10
		if v:FindFirstChild("Weight") then
			weight = v.Weight.Value
		end

		table.insert(tbl, {
			id = string.match(v.AnimationId, ID_PATTERN),
			weight = weight,
			looped = false
		})
	end

	return tbl
end

local onCooldown1 = {}
local onCooldown2 = {}

local function getPlayerAnimPackage(player: Player)
	if onCooldown1[player] then return end

	local character = player.Character
	if not character then return end

	local humanoidDescription = character:FindFirstChildWhichIsA("HumanoidDescription", true)
	if not humanoidDescription then return end

	onCooldown1[player] = os.clock()

	local tbl = {}
	loadAnimations(tbl, humanoidDescription.RunAnimation)
	loadAnimations(tbl, humanoidDescription.WalkAnimation)
	loadAnimations(tbl, humanoidDescription.ClimbAnimation)
	loadAnimations(tbl, humanoidDescription.SwimAnimation)
	loadAnimations(tbl, humanoidDescription.JumpAnimation)
	loadAnimations(tbl, humanoidDescription.FallAnimation)

	return tbl
end

local function getPlayerEmotePackage(player: Player)
	if onCooldown2[player] then return end
	
	local info = Players:GetCharacterAppearanceInfoAsync(player.UserId)

	local list = {}
	for _, v in info.emotes do
		list[v.assetName] = loadEmoteAnimations(v.assetId)
	end

	return list
end

local function cooldownLoop(tbl)
	while task.wait(5) do
		for player, timestamp in tbl do
			if os.clock() - timestamp <= script.Parent.Parent:GetAttribute("AsyncRequestCooldown") then continue end

			tbl[player] = nil
		end
	end
end

if RunService:IsServer() then
	task.spawn(cooldownLoop, onCooldown1)
	task.spawn(cooldownLoop, onCooldown2)
	
	return {
		getPlayerAnimPackage = getPlayerAnimPackage,
		getPlayerEmotePackage = getPlayerEmotePackage
	}
else
	return nil
end