--!strict

local StructureGameObjectSyncService = {}
StructureGameObjectSyncService.__index = StructureGameObjectSyncService

local function _SetAttributeIfChanged(model: Model, attributeName: string, value: any)
	if model:GetAttribute(attributeName) == value then
		return
	end

	model:SetAttribute(attributeName, value)
end

local function _ComputeAnimationState(combatAction: any): string
	if
		combatAction ~= nil
		and combatAction.CurrentActionId == "StructureAttack"
		and (combatAction.ActionState == "Running" or combatAction.ActionState == "Committed")
	then
		return "StructureAttack"
	end

	return "Idle"
end

function StructureGameObjectSyncService.new()
	return setmetatable({}, StructureGameObjectSyncService)
end

function StructureGameObjectSyncService:Init(registry: any, _name: string)
	self._factory = registry:Get("StructureEntityFactory")
end

function StructureGameObjectSyncService:RegisterEntity(entity: number, model: Model?)
	local resolvedModel = model
	if resolvedModel == nil then
		local modelRef = self._factory:GetModelRef(entity)
		if modelRef and modelRef.model then
			resolvedModel = modelRef.model
		end
	end

	if resolvedModel == nil then
		return
	end

	self:_SyncEntity(entity, resolvedModel)
end

function StructureGameObjectSyncService:SyncAll()
	for _, entity in ipairs(self._factory:QueryActiveEntities()) do
		self:_SyncEntity(entity)
	end
end

function StructureGameObjectSyncService:_SyncEntity(entity: number, explicitModel: Model?)
	local resolvedModel = explicitModel
	if resolvedModel == nil then
		local modelRef = self._factory:GetModelRef(entity)
		if modelRef == nil or modelRef.model == nil or modelRef.model.Parent == nil then
			return
		end
		resolvedModel = modelRef.model
	end

	local model = resolvedModel
	local identity = self._factory:GetIdentity(entity)
	local health = self._factory:GetHealth(entity)
	local combatAction = self._factory:GetCombatAction(entity)

	if identity ~= nil then
		_SetAttributeIfChanged(model, "StructureId", identity.StructureId)
		_SetAttributeIfChanged(model, "StructureType", identity.StructureType)
	end

	if health ~= nil then
		_SetAttributeIfChanged(model, "Health", health.Current)
		_SetAttributeIfChanged(model, "MaxHealth", health.Max)
	end

	local nextAnimationState = _ComputeAnimationState(combatAction)
	_SetAttributeIfChanged(model, "AnimationState", nextAnimationState)
	_SetAttributeIfChanged(model, "AnimationLooping", nextAnimationState ~= "StructureAttack")
end

return StructureGameObjectSyncService
