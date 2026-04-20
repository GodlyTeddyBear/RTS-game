--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local RoleConfig = require(ReplicatedStorage.Contexts.Worker.Config.RoleConfig)

local Events = GameEvents.Events
local Result = require(ReplicatedStorage.Utilities.Result)

type Result<T> = Result.Result<T>
local Ok = Result.Ok
local Try = Result.Try
local MentionSuccess = Result.MentionSuccess

--[[
	Assign Worker Role Application Service

	Orchestrates: policy check → entity update → persistence → sync

	Flow:
	1. Policy check — worker exists and role is valid (Domain)
	2. Update AssignmentComponent.Role (Infrastructure)
	3. Persist to ProfileStore (Infrastructure)
	4. Sync to client (Infrastructure)
]]

--[=[
	@class AssignWorkerRole
	Application command that assigns a worker to a role: validates eligibility, updates
	the ECS assignment, equips or clears role-specific tools, persists, and syncs.
	@server
]=]
local AssignWorkerRole = {}
AssignWorkerRole.__index = AssignWorkerRole

export type TAssignWorkerRole = typeof(setmetatable({} :: {
	AssignRolePolicy: any,
	EntityFactory: any,
	PersistenceService: any,
	SyncService: any,
	MiningSlotService: any,
	ForgeStationSlotService: any,
}, AssignWorkerRole))

function AssignWorkerRole.new(): TAssignWorkerRole
	return setmetatable({}, AssignWorkerRole)
end

function AssignWorkerRole:Init(registry: any, _name: string)
	self.AssignRolePolicy = registry:Get("AssignRolePolicy")
	self.EntityFactory = registry:Get("WorkerEntityFactory")
	self.PersistenceService = registry:Get("WorkerPersistenceService")
	self.SyncService = registry:Get("WorkerSyncService")
	self.MiningSlotService = registry:Get("MiningSlotService")
	self.ForgeStationSlotService = registry:Get("ForgeStationSlotService")
end

--[=[
	Assigns the worker to the given role, updating equipment and clearing any prior slot.
	@within AssignWorkerRole
	@param userId number
	@param workerId string
	@param roleId string
	@return Result<string>
]=]
function AssignWorkerRole:Execute(userId: number, workerId: string, roleId: string): Result<string>
	-- 1. Policy: check worker exists and role is valid (Domain layer)
	local ctx = Try(self.AssignRolePolicy:Check(userId, workerId, roleId))
	local entity = ctx.Entity

	-- 2. Release mining slot if switching away from Miner role (Infrastructure layer)
	local currentAssignment = self.EntityFactory:GetAssignment(entity)
	self:_ReleaseMiningSlotIfNeeded(userId, workerId, currentAssignment)
	self:_ReleaseForgeSlotIfNeeded(userId, workerId, currentAssignment)

	-- 3. Update AssignmentComponent.Role (Infrastructure layer)
	self.EntityFactory:AssignRole(entity, roleId)

	-- 4. Equip or unequip tool based on the new role's EquipToolId
	local roleStats = RoleConfig[roleId]
	local equipToolId = roleStats and roleStats.EquipToolId or nil
	if equipToolId then
		self.EntityFactory:SetEquipment(entity, equipToolId, "MainHand")
	else
		self.EntityFactory:ClearEquipment(entity)
	end

	-- 5. Persist to ProfileStore (Infrastructure layer)

	local player = Players:GetPlayerByUserId(userId)
	if player then
		Try(self.PersistenceService:SaveWorkerEntity(player, entity))
	end

	-- 6. Sync to client (Infrastructure layer)
	self.SyncService:AssignRole(userId, workerId, roleId)

	-- 7. Fire guide milestone events for miner and lumberjack role assignments
	if roleId == "Miner" then
		GameEvents.Bus:Emit(Events.Guide.MinerHired, userId)
	elseif roleId == "Lumberjack" then
		GameEvents.Bus:Emit(Events.Guide.LumberjackHired, userId)
	end

	MentionSuccess("Worker:AssignWorkerRole:Execute", "Assigned worker role and updated persisted assignment", {
		userId = userId,
		workerId = workerId,
		roleId = roleId,
	})

	return Ok("Worker assigned to " .. roleId)
end

--- @within AssignWorkerRole
--- @private
function AssignWorkerRole:_ReleaseMiningSlotIfNeeded(userId: number, workerId: string, assignment: any)
	if not assignment or assignment.Role ~= "Miner" or not assignment.TaskTarget then return end
	if not self.MiningSlotService then return end
	self.MiningSlotService:ReleaseSlot(userId, workerId, assignment.TaskTarget)
end

--- @within AssignWorkerRole
--- @private
function AssignWorkerRole:_ReleaseForgeSlotIfNeeded(userId: number, workerId: string, assignment: any)
	if not assignment or assignment.Role ~= "Forge" then
		return
	end
	if not self.ForgeStationSlotService then
		return
	end
	self.ForgeStationSlotService:ReleaseSlot(userId, workerId, "ForgeStation_Anvil")
	self.ForgeStationSlotService:ReleaseSlot(userId, workerId, "ForgeStation_WorkBench")
end

return AssignWorkerRole
