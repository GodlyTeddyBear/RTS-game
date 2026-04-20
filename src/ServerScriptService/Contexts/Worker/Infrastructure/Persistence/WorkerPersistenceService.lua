--!strict

--[[
    Worker Persistence Service - Bridge between ECS and ProfileStore via ProfileManager.

    Responsibilities:
    - Convert ECS components to data tables
    - Save/load worker data directly on profile.Data.Production.Workers
    - Maintain separation: ECS ↔ ProfileManager ↔ ProfileStore

    Pattern: Infrastructure layer service with dependency injection
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

type Result<T> = Result.Result<T>
local Ok = Result.Ok
local Err = Result.Err

--[=[
	@class WorkerPersistenceService
	Bridge between ECS components and ProfileStore. Converts worker entities to/from
	plain data tables stored under `profile.Data.Production.Workers`.
	@server
]=]
local WorkerPersistenceService = {}
WorkerPersistenceService.__index = WorkerPersistenceService

export type TWorkerPersistenceService = typeof(setmetatable({} :: { ProfileManager: any, World: any, Components: any }, WorkerPersistenceService))

function WorkerPersistenceService.new(): TWorkerPersistenceService
	return setmetatable({}, WorkerPersistenceService)
end

function WorkerPersistenceService:Init(registry: any, _name: string)
	self.ProfileManager = registry:Get("ProfileManager")
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
end

--- Deep copy utility to prevent external mutation
local function deepCopy(original: any): any
	if type(original) ~= "table" then
		return original
	end
	local copy = {}
	for k, v in original do
		copy[k] = deepCopy(v)
	end
	return copy
end

--- Ensure Production.Workers path exists on profile data
local function _EnsureWorkersTable(data: any)
	if not data.Production then
		data.Production = {}
	end
	if not data.Production.Workers then
		data.Production.Workers = {}
	end
end

--[=[
	Saves a single worker entity's components to the player's ProfileStore data.
	@within WorkerPersistenceService
	@param player Player
	@param entity any
	@return Result<boolean>
]=]
function WorkerPersistenceService:SaveWorkerEntity(player: Player, entity: any): Result<boolean>
	local worker = self.World:get(entity, self.Components.WorkerComponent)
	local assignment = self.World:get(entity, self.Components.AssignmentComponent)
	local equipment = self.World:get(entity, self.Components.EquipmentComponent)

	if not worker then
		return Err("MissingComponent", "[Worker:Persistence] Entity missing WorkerComponent")
	end

	local data = self.ProfileManager:GetData(player)
	if not data then
		return Err("PersistenceFailed", "No profile data")
	end

	_EnsureWorkersTable(data)

	data.Production.Workers[worker.Id] = {
		Id = worker.Id,
		Rank = worker.Rank,
		Level = worker.Level,
		Experience = worker.Experience,
		AssignedTo = assignment and assignment.Role or nil,
		TaskTarget = assignment and assignment.TaskTarget or nil,
		LastProductionTick = assignment and assignment.LastProductionTick or 0,
		SlotIndex = assignment and assignment.SlotIndex,
		Equipment = equipment and { ToolId = equipment.ToolId, Slot = equipment.Slot } or nil,
	}

	return Ok(true)
end

--[=[
	Saves all provided worker entities for the player. Aborts on the first failure.
	@within WorkerPersistenceService
	@param player Player
	@param entities { any }
	@return Result<boolean>
]=]
function WorkerPersistenceService:SaveAllWorkerEntities(player: Player, entities: { any }): Result<boolean>
	for _, entity in entities do
		local result = self:SaveWorkerEntity(player, entity)
		if not result.success then
			return result
		end
	end
	return Ok(true)
end

--[=[
	Loads worker data from the player's profile as a deep clone. Returns `Ok(nil)` when
	no workers have been persisted yet.
	@within WorkerPersistenceService
	@param player Player
	@return Result<{ [string]: any }?>
]=]
function WorkerPersistenceService:LoadWorkerData(player: Player): Result<{ [string]: any }>
	local data = self.ProfileManager:GetData(player)
	if not data then
		return Ok(nil :: any)
	end
	if not data.Production or not data.Production.Workers then
		return Ok(nil :: any)
	end
	return Ok(deepCopy(data.Production.Workers))
end

--[=[
	Removes a worker entry from the player's profile by ID.
	@within WorkerPersistenceService
	@param player Player
	@param workerId string
	@return Result<boolean>
]=]
function WorkerPersistenceService:DeleteWorkerEntity(player: Player, workerId: string): Result<boolean>
	local data = self.ProfileManager:GetData(player)
	if not data then
		return Ok(true)
	end
	if data.Production and data.Production.Workers then
		data.Production.Workers[workerId] = nil
	end
	return Ok(true)
end

return WorkerPersistenceService
