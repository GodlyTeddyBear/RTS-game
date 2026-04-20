--!strict

--[=[
	@class NPCModelFactory
	Creates and manages Roblox R6 NPC models in Workspace/Dungeons. Handles spawning, position updates, animation attributes.
	@server
]=]

--[[
    NPCModelFactory - Creates and manages Roblox R6 models for combat NPCs.

    Responsibilities:
    - Create adventurer models from EntityRegistry (GetPlayerModel)
    - Create enemy models from EntityRegistry (GetEnemyModel)
    - Update model position and facing direction
    - Set animation state attributes
    - Destroy models

    Pattern: Infrastructure layer service
]]

local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")
local NPCConfig = require(script.Parent.Parent.Parent.Config.NPCConfig)

local NPCModelFactory = {}
NPCModelFactory.__index = NPCModelFactory

export type TNPCModelFactory = typeof(setmetatable({} :: {
	EntityRegistry: any,
	AnimationsFolder: Folder?,
	NPCEquipmentService: any?,
}, NPCModelFactory))

function NPCModelFactory.new(animationsFolder: Folder?): TNPCModelFactory
	local self = setmetatable({}, NPCModelFactory)
	self.AnimationsFolder = animationsFolder
	return self
end

--[=[
	Initialize factory with EntityRegistry (for model cloning).
	@within NPCModelFactory
	@param registry any -- Registry with `:Get("EntityRegistry")`
]=]
function NPCModelFactory:Init(registry: any)
	local entityRegistry = registry:Get("EntityRegistry")
	assert(entityRegistry, "NPCModelFactory requires an EntityRegistry")
	self.EntityRegistry = entityRegistry
	self.NPCEquipmentService = registry:Get("NPCEquipmentService")
	self:_EnsureCollisionGroupConfig()
end

-- Find or create a folder in a parent instance.
-- Helper for organizing NPC models in Workspace hierarchy.
local function findOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then return existing :: Folder end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Ensure a per-user NPC folder exists in Workspace/Dungeons; create if necessary.
-- Path: Workspace/Dungeons/<userId>/NPCs (isolation per player dungeon)
function NPCModelFactory:_GetNPCFolder(userId: number): Folder
	local dungeons = findOrCreateFolder(Workspace, "Dungeons")
	local userFolder = findOrCreateFolder(dungeons, tostring(userId))
	return findOrCreateFolder(userFolder, "NPCs")
end

-- Configure a model with its animations reference and parent folder.
function NPCModelFactory:_BuildNPCModel(
	model: Model,
	npcId: string,
	_npcType: string,
	team: string,
	userId: number,
	_displayName: string,
	_maxHP: number
): Model
	-- Set instance name and attributes for identification and client animation syncing
	model.Name = team .. "_" .. npcId

	-- Attach animations folder reference (client uses this to load animation tracks)
	if self.AnimationsFolder then
		local folderRef = Instance.new("ObjectValue")
		folderRef.Name = "AnimationsFolder"
		folderRef.Value = self.AnimationsFolder
		folderRef.Parent = model
	end

	model.Parent = self:_GetNPCFolder(userId)
	return model
end

-- Ensure NPC collision group exists and its self-collision rule is configured.
-- Safe to call on repeated play sessions (group registration is idempotent).
function NPCModelFactory:_EnsureCollisionGroupConfig()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(NPCConfig.NPC_COLLISION_GROUP)
	end)

	PhysicsService:CollisionGroupSetCollidable(
		NPCConfig.NPC_COLLISION_GROUP,
		NPCConfig.NPC_COLLISION_GROUP,
		NPCConfig.NPC_COLLIDES_WITH_NPC
	)
end

-- Apply NPC collision group to all BaseParts in a model hierarchy.
function NPCModelFactory:_ApplyCollisionGroup(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = NPCConfig.NPC_COLLISION_GROUP
		end
	end
end

--[=[
	Create an adventurer R6 model from EntityRegistry and set up for spawn.
	@within NPCModelFactory
	@param adventurerType string -- Adventurer model type
	@param adventurerId string -- Unique ID for this adventurer instance
	@param userId number -- Player ID who owns this adventurer
	@return Model -- Configured model, parented to Workspace
]=]
function NPCModelFactory:CreateAdventurerModel(
	adventurerType: string,
	adventurerId: string,
	userId: number,
	displayName: string,
	maxHP: number,
	equipment: any?
): Model
	local model = self:_BuildNPCModel(
		self.EntityRegistry:GetPlayerModel(adventurerType),
		adventurerId, adventurerType, "Adventurer", userId, displayName, maxHP
	)
	if self.NPCEquipmentService and equipment then
		self.NPCEquipmentService:EquipAdventurer(model, equipment)
	end
	self:_ApplyCollisionGroup(model)
	return model
end

--[=[
	Create an enemy R6 model from EntityRegistry and set up for spawn.
	@within NPCModelFactory
	@param enemyType string -- Enemy model type from config
	@param enemyId string -- Unique ID for this enemy instance
	@param userId number -- Player ID who owns this enemy (dungeon isolation)
	@return Model -- Configured model, parented to Workspace
]=]
function NPCModelFactory:CreateEnemyModel(enemyType: string, enemyId: string, userId: number, displayName: string, maxHP: number): Model
	local model = self:_BuildNPCModel(
		self.EntityRegistry:GetEnemyModel(enemyType),
		enemyId, enemyType, "Enemy", userId, displayName, maxHP
	)
	self:_ApplyCollisionGroup(model)
	return model
end

--[=[
	Move a model to a new position and orientation.
	@within NPCModelFactory
	@param model Model -- NPC model instance
	@param cframe CFrame -- Target position and orientation
	@error string -- Throws if model has no PrimaryPart
]=]
function NPCModelFactory:UpdatePosition(model: Model, cframe: CFrame)
	if model.PrimaryPart then
		model:PivotTo(cframe)
	else
		warn("[NPCModelFactory] NPC model has no PrimaryPart:", model.Name)
	end
end

--[=[
	Get the current world position of a model.
	@within NPCModelFactory
	@param model Model -- NPC model instance
	@return Vector3? -- Position, or nil if no PrimaryPart
]=]
function NPCModelFactory:GetModelPosition(model: Model): Vector3?
	if model.PrimaryPart then
		return model:GetPivot().Position
	end
	return nil
end

--[=[
	Destroy an NPC model and clean up from Workspace.
	@within NPCModelFactory
	@param model Model -- NPC model instance
]=]
function NPCModelFactory:DestroyModel(model: Model)
	model:Destroy()
end

--[=[
	Destroy all NPC models for a user by clearing their folder (on disconnect).
	@within NPCModelFactory
	@param userId number -- Player ID
]=]
function NPCModelFactory:DestroyAllModelsForUser(userId: number)
	local dungeonsFolder = Workspace:FindFirstChild("Dungeons")
	if not dungeonsFolder then
		return
	end

	local userFolder = dungeonsFolder:FindFirstChild(tostring(userId))
	if not userFolder then
		return
	end

	local npcFolder = userFolder:FindFirstChild("NPCs")
	if npcFolder then
		npcFolder:ClearAllChildren()
	end
end

return NPCModelFactory
