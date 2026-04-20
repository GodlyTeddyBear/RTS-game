--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok = Result.Ok

export type TZonePolicyCheckContext = {
	Entity: any,
	Assignment: any,
	TargetConfig: any,
	ZoneFolder: any,
	TargetInstance: Instance?,
	WorkersAtTarget: number,
	IsUnlocked: boolean,
}

export type TZonePolicyConfig = {
	RoleName: string,
	ConfigTable: { [string]: any },
	Spec: any,
	ResultInstanceKey: string,
	GetZoneFolder: (lotContext: any, userId: number) -> any?,
	FindTargetInZone: (zoneFolder: any, targetId: string) -> Instance?,
	BuildCandidate: (ctx: TZonePolicyCheckContext) -> any,
	SlotServiceName: string?,
}

local BaseAssignZoneTargetPolicy = {}
BaseAssignZoneTargetPolicy.__index = BaseAssignZoneTargetPolicy

function BaseAssignZoneTargetPolicy.new(config: TZonePolicyConfig)
	local self = setmetatable({}, BaseAssignZoneTargetPolicy)
	self._config = config
	self._registry = nil :: any
	self._entityFactory = nil :: any
	self._lotContext = nil :: any
	self._unlockContext = nil :: any
	self._slotService = nil :: any
	return self
end

function BaseAssignZoneTargetPolicy:Init(registry: any, _name: string)
	self._registry = registry
	self._entityFactory = registry:Get("WorkerEntityFactory")

	if self._config.SlotServiceName then
		local ok, service = pcall(function()
			return registry:Get(self._config.SlotServiceName :: string)
		end)
		if ok then
			self._slotService = service
		end
	end
end

function BaseAssignZoneTargetPolicy:Start()
	self._lotContext = self._registry:Get("LotContext")
	self._unlockContext = self._registry:Get("UnlockContext")
end

function BaseAssignZoneTargetPolicy:Check(userId: number, workerId: string, targetId: string)
	local entity = self._entityFactory:FindWorkerById(workerId)
	local assignment = entity and self._entityFactory:GetAssignment(entity)
	local zoneFolder = self._config.GetZoneFolder(self._lotContext, userId)

	local targetConfig = self._config.ConfigTable[targetId]
	local targetInstance = zoneFolder and self._config.FindTargetInZone(zoneFolder, targetId) or nil

	local workersAtTarget = 0
	if self._slotService then
		if self._slotService.GetOccupiedSlotCountExcludingWorker then
			workersAtTarget = self._slotService:GetOccupiedSlotCountExcludingWorker(userId, targetId, workerId)
		else
			workersAtTarget = self._slotService:GetOccupiedSlotCount(userId, targetId)
		end
	else
		workersAtTarget = self:_CountAssignedWorkersAtTarget(userId, workerId, targetId)
	end

	local candidate = self._config.BuildCandidate({
		Entity = entity,
		Assignment = assignment,
		TargetConfig = targetConfig,
		ZoneFolder = zoneFolder,
		TargetInstance = targetInstance,
		WorkersAtTarget = workersAtTarget,
		IsUnlocked = self._unlockContext:IsUnlocked(userId, targetId),
	})

	local specResult = self._config.Spec:IsSatisfiedBy(candidate)
	if not specResult.success then
		return specResult
	end

	local result = {
		Entity = entity,
	}
	result[self._config.ResultInstanceKey] = targetInstance
	return Ok(result)
end

function BaseAssignZoneTargetPolicy:_CountAssignedWorkersAtTarget(userId: number, workerId: string, targetId: string): number
	local count = 0
	local workers = self._entityFactory:QueryUserWorkers(userId)

	for _, workerData in workers do
		local assignment = self._entityFactory:GetAssignment(workerData.Entity)
		if assignment and assignment.Role == self._config.RoleName and assignment.TaskTarget == targetId then
			local currentWorkerId = workerData.Worker and workerData.Worker.Id
			if currentWorkerId ~= workerId then
				count += 1
			end
		end
	end

	return count
end

return BaseAssignZoneTargetPolicy
