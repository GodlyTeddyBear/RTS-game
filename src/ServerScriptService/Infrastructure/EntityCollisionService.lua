--!strict

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local ENTITY_GROUP = "Entities"
local NPC_GROUPS = { "Workers", "CombatNPC", "Villagers" }

local EntityCollisionService = {}

local function _registerCollisionGroup(groupName: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(groupName)
	end)
end

local function _applyPartCollisionGroup(descendant: Instance)
	if descendant:IsA("BasePart") then
		descendant.CollisionGroup = ENTITY_GROUP
	end
end

local function _onCharacterAdded(character: Model)
	EntityCollisionService:ApplyModel(character)
	character.DescendantAdded:Connect(_applyPartCollisionGroup)
end

local function _onPlayerAdded(player: Player)
	if player.Character then
		_onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(_onCharacterAdded)
end

function EntityCollisionService:ApplyModel(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		_applyPartCollisionGroup(descendant)
	end
end

function EntityCollisionService:Initialize()
	_registerCollisionGroup(ENTITY_GROUP)

	for _, group in ipairs(NPC_GROUPS) do
		_registerCollisionGroup(group)
	end

	PhysicsService:CollisionGroupSetCollidable(ENTITY_GROUP, ENTITY_GROUP, false)

	for _, group in ipairs(NPC_GROUPS) do
		PhysicsService:CollisionGroupSetCollidable(ENTITY_GROUP, group, false)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		_onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(_onPlayerAdded)
end

return EntityCollisionService
