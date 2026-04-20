--!strict

--[=[
	@class VillagerPathingService
	Manages pathfinding for villagers using SimplePath; handles path lifecycle and signals.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Promise = require(ReplicatedStorage.Packages.Promise)
local SimplePath = require(ReplicatedStorage.Utilities.SimplePath)

local DEFAULT_AGENT_PARAMS = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
}

local VillagerPathingService = {}
VillagerPathingService.__index = VillagerPathingService

export type TVillagerPathingService = typeof(setmetatable({} :: {
	EntityFactory: any,
	GameObjectSyncService: any,
	_activePaths: { [any]: any },
	_cleanup: { [any]: any },
}, VillagerPathingService))

function VillagerPathingService.new(): TVillagerPathingService
	local self = setmetatable({}, VillagerPathingService)
	self._activePaths = {}
	self._cleanup = {}
	return self
end

function VillagerPathingService:Init(registry: any)
	self.EntityFactory = registry:Get("VillagerEntityFactory")
	self.GameObjectSyncService = registry:Get("VillagerGameObjectSyncService")
end

--[=[
	Pathfinds the villager model to the target position.
	@within VillagerPathingService
	@param entity any -- ECS entity to move
	@param targetPosition Vector3 -- Destination position
	@return boolean -- Whether pathfinding started successfully
]=]
function VillagerPathingService:MoveTo(entity: any, targetPosition: Vector3): boolean
	local model = self.GameObjectSyncService:GetInstanceForEntity(entity)
	-- Guard: model must exist and have a primary part to path
	if not model or not model.PrimaryPart then
		return false
	end

	-- Stop any previous path for this entity
	self:Stop(entity)

	-- Create SimplePath instance; on failure, mark path as failed
	local success, path = pcall(function()
		return SimplePath.new(model, DEFAULT_AGENT_PARAMS)
	end)
	if not success then
		self.EntityFactory:SetPathStatus(entity, "Failed")
		return false
	end

	-- Set up cleanup and signal handlers
	local janitor = Janitor.new()
	self._activePaths[entity] = path
	self._cleanup[entity] = janitor
	self.EntityFactory:SetPathMoving(entity, targetPosition)

	-- Connect path completion signals
	janitor:Add(path.Reached:Connect(function()
		self:_CompletePath(entity, "Reached")
	end))

	janitor:Add(path.Error:Connect(function()
		self:_CompletePath(entity, "Failed")
	end))

	janitor:Add(path.Blocked:Connect(function()
		self:_CompletePath(entity, "Failed")
	end))

	-- Start path asynchronously; catch any errors
	Promise.try(function()
		local ran = path:Run(targetPosition)
		if not ran then
			self:_CompletePath(entity, "Failed")
		end
	end):catch(function()
		self:_CompletePath(entity, "Failed")
	end)

	return true
end

--[=[
	Stops any active pathfinding for the entity.
	@within VillagerPathingService
	@param entity any -- ECS entity
]=]
function VillagerPathingService:Stop(entity: any)
	local path = self._activePaths[entity]
	if path then
		-- Stop only if path is currently active
		pcall(function()
			if path.Status == SimplePath.StatusType.Active then
				path:Stop()
			end
		end)
	end

	self:_DestroyPath(entity)
end

-- Marks path complete and cleans up resources.
function VillagerPathingService:_CompletePath(entity: any, status: "Reached" | "Failed")
	self.EntityFactory:SetPathStatus(entity, status)
	self:_DestroyPath(entity)
end

-- Cleans up path object and signal connections.
function VillagerPathingService:_DestroyPath(entity: any)
	local janitor = self._cleanup[entity]
	if janitor then
		janitor:Destroy()
		self._cleanup[entity] = nil
	end

	local path = self._activePaths[entity]
	if path then
		pcall(function()
			path:Destroy()
		end)
		self._activePaths[entity] = nil
	end
end

return VillagerPathingService
