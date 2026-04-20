--!strict

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local PLAYER_GROUP = "Players"
local NPC_GROUPS = { "Workers", "CombatNPC", "Villagers" }

local PlayerCollisionService = {}

local function _applyCollisionGroup(character: Model)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = PLAYER_GROUP
		end
	end
end

local function _onCharacterAdded(character: Model)
	_applyCollisionGroup(character)
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = PLAYER_GROUP
		end
	end)
end

local function _onPlayerAdded(player: Player)
	if player.Character then
		_onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(_onCharacterAdded)
end

function PlayerCollisionService:Initialize()
	-- Register Players group
	pcall(function()
		PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	end)

	-- Pre-register NPC groups idempotently so cross-group rules don't error on ordering
	for _, group in ipairs(NPC_GROUPS) do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(group)
		end)
	end

	-- Players don't collide with each other
	PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, false)

	-- Players don't collide with any NPC group
	for _, group in ipairs(NPC_GROUPS) do
		PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, group, false)
	end

	-- Wire up existing and future players
	for _, player in ipairs(Players:GetPlayers()) do
		_onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(_onPlayerAdded)
end

return PlayerCollisionService
