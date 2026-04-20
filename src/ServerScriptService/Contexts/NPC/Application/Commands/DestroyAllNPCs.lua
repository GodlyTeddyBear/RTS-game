--!strict

--[=[
	@class DestroyAllNPCs
	Application service for bulk cleanup of all NPC entities and models for a player.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Ensure = Result.Ensure
local MentionSuccess = Result.MentionSuccess

--[[
    DestroyAllNPCs - Application Service

    Destroys all NPC entities and models for a given user.
    Called on expedition end, player disconnect, or manual cleanup.
]]

local DestroyAllNPCs = {}
DestroyAllNPCs.__index = DestroyAllNPCs

export type TDestroyAllNPCs = typeof(setmetatable({}, DestroyAllNPCs))

function DestroyAllNPCs.new(): TDestroyAllNPCs
	local self = setmetatable({}, DestroyAllNPCs)
	return self
end

--[=[
	Initialize service with entity and model cleanup factories.
	@within DestroyAllNPCs
	@param registry any -- Registry with `:Get()` for factories
]=]
function DestroyAllNPCs:Init(registry: any)
	self.NPCEntityFactory = registry:Get("NPCEntityFactory")
	self.NPCModelFactory = registry:Get("NPCModelFactory")
	self.NPCGameObjectSyncService = registry:Get("NPCGameObjectSyncService")
end

--[=[
	Destroy all NPC entities and models for a player (cleanup on disconnect or expedition end).
	@within DestroyAllNPCs
	@param userId number -- Player ID to clean up
	@return Result.Result<boolean> -- Always Ok(true) if valid userId
	@error string -- Throws if userId is invalid
]=]
function DestroyAllNPCs:Execute(userId: number): Result.Result<boolean>
	-- Validate user ID
	Ensure(userId ~= nil and userId > 0, "InvalidUserId", Errors.INVALID_USER_ID)

	-- Query all NPC entities for this user (alive and dead)
	local allEntities = self.NPCEntityFactory:QueryAllEntities(userId)

	-- Teardown: clean sync mappings, then delete from JECS world
	self:_TeardownEntities(allEntities)

	-- Destroy all R6 models in Workspace/Dungeons/<userId>
	self.NPCModelFactory:DestroyAllModelsForUser(userId)

	-- Clear entity-model mappings from sync service
	self.NPCGameObjectSyncService:CleanupUser(userId)

	-- Log success
	MentionSuccess("NPC:DestroyAllNPCs:Execute", "Destroyed all NPC entities and models for user", {
		userId = userId,
	})
	return Ok(true)
end

-- Delete all entities: clean up sync mappings, then delete from JECS world.
function DestroyAllNPCs:_TeardownEntities(entities: { any })
	-- Iterate all entities and clean up in order: sync service (remove model), JECS world
	for _, entity in ipairs(entities) do
		-- Remove model from EntityToInstance/InstanceToEntity mappings
		self.NPCGameObjectSyncService:DeleteEntity(entity)
		-- Remove entity from JECS world
		self.NPCEntityFactory:DeleteEntity(entity)
	end
end

return DestroyAllNPCs
