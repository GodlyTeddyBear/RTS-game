--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try
local MentionSuccess = Result.MentionSuccess

export type TAssignWorkerTaskCommandConfig = {
	PolicyName: string,
	PolicyUsesUserId: boolean,
	SuccessEvent: string,
	SuccessMessage: string,
	LogTargetField: string,
	ReturnRawTargetId: boolean,
	ReturnMessagePrefix: string?,
	DurationConfigTable: { [string]: any }?,
	DurationFieldName: string?,
	ResultInstanceKey: string?,
	SlotServiceName: string?,
	SlotTargetIdFieldName: string?,
	RequireModelForSlot: boolean?,
	AnimationState: string?,
}

local BaseAssignWorkerTaskCommand = {}
BaseAssignWorkerTaskCommand.__index = BaseAssignWorkerTaskCommand

function BaseAssignWorkerTaskCommand.new(config: TAssignWorkerTaskCommandConfig)
	local self = setmetatable({}, BaseAssignWorkerTaskCommand)
	self._config = config
	self._policy = nil :: any
	self.EntityFactory = nil :: any
	self.PersistenceService = nil :: any
	self.SyncService = nil :: any
	self._slotService = nil :: any
	return self
end

function BaseAssignWorkerTaskCommand:Init(registry: any, _name: string)
	self._policy = registry:Get(self._config.PolicyName)
	self.EntityFactory = registry:Get("WorkerEntityFactory")
	self.PersistenceService = registry:Get("WorkerPersistenceService")
	self.SyncService = registry:Get("WorkerSyncService")

	if self._config.SlotServiceName then
		self._slotService = registry:Get(self._config.SlotServiceName :: string)
	end
end

function BaseAssignWorkerTaskCommand:Execute(userId: number, workerId: string, targetId: string)
	local ctx
	if self._config.PolicyUsesUserId then
		ctx = Try(self._policy:Check(userId, workerId, targetId))
	else
		ctx = Try(self._policy:Check(workerId, targetId))
	end

	self.EntityFactory:AssignTaskTarget(ctx.Entity, targetId)

	if self._slotService and self._config.ResultInstanceKey then
		local targetInstance = ctx[self._config.ResultInstanceKey]
		local slotTargetId = targetId
		if self._config.SlotTargetIdFieldName and ctx[self._config.SlotTargetIdFieldName] then
			slotTargetId = ctx[self._config.SlotTargetIdFieldName]
		end
		self:_ApplySlotPosition(userId, workerId, slotTargetId, ctx.Entity, targetInstance)
	end

	if self._config.DurationConfigTable and self._config.DurationFieldName then
		local targetConfig = self._config.DurationConfigTable[targetId]
		local duration = targetConfig and targetConfig[self._config.DurationFieldName]
		if duration then
			local animState = self._config.AnimationState or "Mining"
			self.EntityFactory:StartMining(ctx.Entity, targetId, duration, animState)
		end
	end

	local player = Players:GetPlayerByUserId(userId)
	if player then
		Try(self.PersistenceService:SaveWorkerEntity(player, ctx.Entity))
	end

	self.SyncService:AssignTaskTarget(userId, workerId, targetId)
	MentionSuccess(self._config.SuccessEvent, self._config.SuccessMessage, {
		userId = userId,
		workerId = workerId,
		[self._config.LogTargetField] = targetId,
	})

	if self._config.ReturnRawTargetId then
		return Ok(targetId)
	end

	return Ok((self._config.ReturnMessagePrefix or "Worker assigned to ") .. targetId)
end

function BaseAssignWorkerTaskCommand:_ApplySlotPosition(
	userId: number,
	workerId: string,
	targetId: string,
	entity: any,
	targetInstance: any
)
	if not targetInstance then
		return
	end

	local requireModel = self._config.RequireModelForSlot == true
	if requireModel and not targetInstance:IsA("Model") then
		return
	end

	local targetCFrame = targetInstance:GetPivot()
	local slotIndex, standPos, lookAtPos =
		self._slotService:ClaimSlot(userId, workerId, targetId, targetCFrame, targetInstance)

	self.EntityFactory:AssignSlotIndex(entity, slotIndex)
	self.EntityFactory:UpdatePosition(entity, standPos.X, standPos.Y, standPos.Z, lookAtPos.X, lookAtPos.Y, lookAtPos.Z)
end

return BaseAssignWorkerTaskCommand
